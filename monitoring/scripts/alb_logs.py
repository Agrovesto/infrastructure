"""Ship prod ALB access logs from S3 into Loki.

The load balancer already writes one access log line per request into the prod
access-log bucket (prod/alb.tf); nothing ever read them, so request volume,
status mix, latency and client IPs were invisible to Grafana. This parses the
new objects and pushes them to Loki as JSON lines under source="alb", which
gives the traffic dashboard and the LogQL alerts the same shape the dev nginx
access logs have.

Exactly-once by key: ALB keys are
<prefix>/AWSLogs/<account>/elasticloadbalancing/<region>/<yyyy>/<mm>/<dd>/<time>.<ip>.<rand>.log,
so they sort chronologically and the last processed key is the cursor. Only
today's and yesterday's day prefixes are listed (delivery lag is minutes),
which keeps a run to a couple of ListObjects calls no matter how long the
bucket's lifecycle keeps objects.

Labels stay low-cardinality (source, service, status, method, kind); the client
IP, URI, host and user agent live in the line, where LogQL can still filter and
aggregate on them after `| json`. Health-check requests are shipped too, but
tagged kind="health" so dashboards and alerts can exclude them.

Writes: Loki POST /loki/api/v1/push and Pushgateway job="alb-logs".
"""

import gzip
import json
import os
import shlex
import sys
import time
import urllib.request
from datetime import datetime, timedelta, timezone
from urllib.parse import urlsplit

import boto3

REGION = os.environ.get("AWS_REGION", "eu-west-1")
BUCKET = os.environ["ALB_LOGS_BUCKET"]
PREFIX = os.environ.get("ALB_LOGS_PREFIX", "alb").strip("/")
ACCOUNT_ID = os.environ.get("ACCOUNT_ID", "")
LOKI = os.environ["LOKI_URL"].rstrip("/")
PUSH = os.environ["PUSHGATEWAY_URL"].rstrip("/")
# Own variable name: the collector task already sets STATE_FILE for the ECS
# log shipper, and all three scripts share one container.
STATE = os.environ.get("ALB_STATE_FILE", "/collector/state/alb_logs.json")
SERVICE_PREFIX = os.environ.get("SERVICE_PREFIX", "")
MAX_OBJECTS = int(os.environ.get("MAX_OBJECTS_PER_RUN", "100"))
BATCH = int(os.environ.get("LOKI_BATCH_SIZE", "500"))
MIN_FIELDS = 25  # everything up to and including error_reason

# Field order of the ALB access log format (AWS documents it positionally).
FIELDS = (
    "type", "time", "elb", "client", "target", "request_processing_time",
    "target_processing_time", "response_processing_time", "elb_status_code",
    "target_status_code", "received_bytes", "sent_bytes", "request",
    "user_agent", "ssl_cipher", "ssl_protocol", "target_group_arn", "trace_id",
    "domain_name", "chosen_cert_arn", "matched_rule_priority",
    "request_creation_time", "actions_executed", "redirect_url", "error_reason",
    "targets", "target_status_codes", "classification", "classification_reason",
)


def gauge(name, value, **labels):
    label = ",".join(f'{key}="{val}"' for key, val in sorted(labels.items()))
    return f"{name}{{{label}}} {value}" if label else f"{name} {value}"


def load_state():
    try:
        with open(STATE) as handle:
            state = json.load(handle)
    except (OSError, ValueError):
        state = {}
    state.setdefault("last_key", "")
    state.setdefault("services", {})
    return state


def save_state(state):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp = f"{STATE}.tmp"
    with open(tmp, "w") as handle:
        json.dump(state, handle)
    os.replace(tmp, STATE)


def push_loki(streams):
    for start in range(0, len(streams), 20):
        body = json.dumps({"streams": streams[start:start + 20]}).encode()
        request = urllib.request.Request(f"{LOKI}/loki/api/v1/push", data=body, method="POST")
        request.add_header("Content-Type", "application/json")
        urllib.request.urlopen(request, timeout=30).read()


def push_metrics(lines):
    body = ("\n".join(lines) + "\n").encode()
    request = urllib.request.Request(f"{PUSH}/metrics/job/alb-logs", data=body, method="PUT")
    request.add_header("Content-Type", "text/plain")
    urllib.request.urlopen(request, timeout=15).read()


def service_of(name):
    """agrovesto-prod-wallet -> wallet, matching the ECS service names."""
    if SERVICE_PREFIX and name.startswith(SERVICE_PREFIX):
        return name[len(SERVICE_PREFIX):] or name
    return name


def target_group_service(arn):
    """arn:...:targetgroup/agrovesto-prod-wallet/9c8f5b1a2d3e4f50 -> wallet."""
    parts = arn.split("/")
    if len(parts) >= 3 and parts[0].endswith("targetgroup"):
        return service_of(parts[1])
    return service_of(arn.rsplit("/", 1)[-1] or arn)


def split_client(client):
    """ip:port, with IPv6 either bracketed or written bare by the ALB."""
    if client.startswith("[") and "]:" in client:
        address, _, port = client.rpartition("]:")
        return address.lstrip("["), port
    address, _, port = client.rpartition(":")
    return (address, port) if address else (client, "-")


def day_prefixes(account):
    now = datetime.now(timezone.utc)
    return [
        f"{PREFIX}/AWSLogs/{account}/elasticloadbalancing/{REGION}/"
        f"{day:%Y}/{day:%m}/{day:%d}/"
        for day in (now - timedelta(days=1), now)
    ]


def pending_keys(s3, account, last_key):
    """Keys newer than the cursor, oldest first, capped per run."""
    keys = []
    paginator = s3.get_paginator("list_objects_v2")
    for prefix in day_prefixes(account):
        for page in paginator.paginate(Bucket=BUCKET, Prefix=prefix):
            keys.extend(item["Key"] for item in page.get("Contents", []))
    return sorted(key for key in keys if key > last_key and not key.endswith("/"))[:MAX_OBJECTS]


def read_object(s3, key):
    body = s3.get_object(Bucket=BUCKET, Key=key)["Body"].read()
    return gzip.decompress(body) if key.endswith(".gz") else body


def nanoseconds(stamp):
    try:
        parsed = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
        return int(parsed.timestamp() * 1_000_000_000)
    except ValueError:
        return int(time.time() * 1_000_000_000)


def level_of(status):
    if status.startswith("5"):
        return "error"
    return "warn" if status.startswith("4") else "info"


def path_of(url):
    """ALB logs the absolute URL for https requests; panels want the path."""
    return urlsplit(url).path or "/"


def parse(line):
    """One ALB access log line -> (labels, JSON line, timestamp) or None."""
    try:
        fields = shlex.split(line)
    except ValueError:
        return None
    if len(fields) < MIN_FIELDS:
        return None

    row = dict(zip(FIELDS, fields))
    request = row["request"].split(" ", 2)
    method = request[0] if request else "-"
    url = request[1] if len(request) > 1 else "-"
    protocol = request[2] if len(request) > 2 else "-"
    status = row["elb_status_code"]
    service = target_group_service(row["target_group_arn"])
    agent = row["user_agent"]
    client_ip, client_port = split_client(row["client"])

    labels = {
        "source": "alb",
        "service": service,
        "status": status,
        "method": method,
        "kind": "health" if agent.startswith("ELB-HealthChecker") else "request",
    }
    entry = {
        "ts": row["time"],
        "component": "alb",
        "level": level_of(status),
        "type": row["type"],
        "service": service,
        "host": row["domain_name"],
        "method": method,
        "uri": path_of(url),
        "url": url,
        "protocol": protocol,
        "status": status,
        "target_status": row["target_status_code"],
        "client_ip": client_ip,
        "client_port": client_port,
        "target": row["target"],
        "target_group": row["target_group_arn"].split("/")[-2] if row["target_group_arn"].count("/") >= 2 else row["target_group_arn"],
        "user_agent": agent,
        "request_time": row["request_processing_time"],
        "target_response_time": row["target_processing_time"],
        "response_time": row["response_processing_time"],
        "received_bytes": row["received_bytes"],
        "sent_bytes": row["sent_bytes"],
        "ssl_protocol": row["ssl_protocol"],
        "trace_id": row["trace_id"],
        "actions": row["actions_executed"],
        "error_reason": row["error_reason"],
        "classification": row["classification"],
        "elb": row["elb"],
    }
    return labels, json.dumps(entry, separators=(",", ":")), nanoseconds(row["time"])


def ship(s3, keys, state):
    """Parse and push every key, then advance the cursor in `state`."""
    streams, per_service, errors = {}, {}, 0
    newest = state.get("last_event")

    for key in keys:
        try:
            body = read_object(s3, key)
        except Exception as exc:  # noqa: BLE001 - one unreadable object must not stop the run
            errors += 1
            print(json.dumps({"error": str(exc), "key": key}), file=sys.stderr)
            continue
        for raw in body.decode("utf-8", "replace").splitlines():
            if not raw.strip():
                continue
            parsed = parse(raw.strip())
            if parsed is None:
                errors += 1
                continue
            labels, line, timestamp = parsed
            group = streams.setdefault(
                json.dumps(labels, sort_keys=True), {"stream": labels, "values": []}
            )
            group["values"].append([str(timestamp), line])
            per_service[labels["service"]] = per_service.get(labels["service"], 0) + 1
            if newest is None or timestamp > newest:
                newest = timestamp

    entries = []
    for group in streams.values():
        values = group["values"]
        for start in range(0, len(values), BATCH):
            entries.append({"stream": group["stream"], "values": values[start:start + BATCH]})
    if entries:
        push_loki(entries)

    services = state["services"]
    for service, count in per_service.items():
        cursor = services.setdefault(service, {"total": 0})
        cursor["total"] = cursor.get("total", 0) + count
        if newest:
            cursor["last_event"] = newest // 1_000_000
    state["total"] = state.get("total", 0) + sum(per_service.values())
    state["objects"] = state.get("objects", 0) + len(keys)
    state["errors"] = state.get("errors", 0) + errors
    state["last_key"] = keys[-1]
    if newest:
        state["last_event"] = newest
    return sum(per_service.values()), len(keys), errors


def metric_lines(state, shipped, objects):
    lines = []
    for service, cursor in sorted(state["services"].items()):
        lines.append(gauge("alb_logs_shipped_total", cursor.get("total", 0), service=service))
        if cursor.get("last_event"):
            lines.append(gauge("alb_logs_last_event_timestamp_seconds", cursor["last_event"], service=service))
    lines += [
        gauge("alb_logs_shipper_up", 1),
        gauge("alb_logs_scrape_timestamp_seconds", int(time.time())),
        gauge("alb_logs_shipped_run_total", shipped),
        gauge("alb_logs_objects_run_total", objects),
        gauge("alb_logs_parse_errors_total", state.get("errors", 0)),
    ]
    if state.get("last_event"):
        lines.append(gauge("alb_logs_newest_event_timestamp_seconds", state["last_event"] // 1_000_000))
    return lines


def main():
    state = load_state()
    lines = []
    try:
        account = ACCOUNT_ID or boto3.client("sts", region_name=REGION).get_caller_identity()["Account"]
        s3 = boto3.client("s3", region_name=REGION)
        keys = pending_keys(s3, account, state["last_key"])
        shipped, objects, errors = ship(s3, keys, state) if keys else (0, 0, 0)
        save_state(state)
        lines = metric_lines(state, shipped, objects)
    except Exception as exc:  # noqa: BLE001 - any failure is reported through the metric
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        lines = [
            gauge("alb_logs_shipper_up", 0),
            gauge("alb_logs_scrape_timestamp_seconds", int(time.time())),
        ]
    push_metrics(lines)


main()
