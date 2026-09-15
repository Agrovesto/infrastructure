"""Ship prod ECS task logs into Loki.

The services already write to CloudWatch Logs through the awslogs driver; this
reads those groups with FilterLogEvents and pushes the lines to Loki, so nothing
is queried through CloudWatch dashboards, alarms, metric filters or Insights.
Progress is checkpointed on EFS so each run only ships new lines.

Writes: Loki POST /loki/api/v1/push and Pushgateway job="ecs-logs".
"""

import json
import os
import sys
import time
import urllib.request

import boto3

REGION = os.environ.get("AWS_REGION", "eu-west-1")
PREFIX = os.environ["LOG_GROUP_PREFIX"]
LOKI = os.environ["LOKI_URL"].rstrip("/")
PUSH = os.environ["PUSHGATEWAY_URL"].rstrip("/")
STATE = os.environ.get("STATE_FILE", "/collector/state/ecs_logs.json")
LOOKBACK_MS = int(os.environ.get("LOOKBACK_MINUTES", "15")) * 60_000
LIMIT = int(os.environ.get("MAX_EVENTS_PER_GROUP", "2000"))
BATCH = int(os.environ.get("LOKI_BATCH_SIZE", "500"))
SEEN_IDS = 200


def gauge(name, value, **labels):
    label = ",".join(f'{key}="{val}"' for key, val in labels.items())
    return f"{name}{{{label}}} {value}" if label else f"{name} {value}"


def load_state():
    try:
        with open(STATE) as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def save_state(state):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp = f"{STATE}.tmp"
    with open(tmp, "w") as handle:
        json.dump(state, handle)
    os.replace(tmp, STATE)


def service_of(group):
    tail = group[len(PREFIX):].strip("/-")
    return tail or group.rsplit("/", 1)[-1]


def push_loki(entries):
    body = json.dumps({"streams": entries}).encode()
    request = urllib.request.Request(f"{LOKI}/loki/api/v1/push", data=body, method="POST")
    request.add_header("Content-Type", "application/json")
    urllib.request.urlopen(request, timeout=30).read()


def push_metrics(lines):
    body = ("\n".join(lines) + "\n").encode()
    request = urllib.request.Request(f"{PUSH}/metrics/job/ecs-logs", data=body, method="PUT")
    request.add_header("Content-Type", "text/plain")
    urllib.request.urlopen(request, timeout=15).read()


def start_time(state, group):
    now = int(time.time() * 1000)
    previous = state.get(group, {}).get("ts", now - LOOKBACK_MS)
    return max(previous, now - LOOKBACK_MS)


def ship(logs, group, state):
    cursor = state.get(group, {})
    last_ts = cursor.get("ts")
    seen = set(cursor.get("ids", []))
    response = logs.filter_log_events(
        logGroupName=group, startTime=start_time(state, group), limit=LIMIT, interleaved=True
    )
    events = sorted(response.get("events", []), key=lambda event: event["timestamp"])

    values, newest, ids = [], last_ts, list(seen)
    for event in events:
        timestamp, event_id = event["timestamp"], event["eventId"]
        if last_ts is not None and (
            timestamp < last_ts or (timestamp == last_ts and event_id in seen)
        ):
            continue
        values.append([str(timestamp * 1_000_000), event["message"].rstrip("\n")])
        if newest is None or timestamp > newest:
            newest, ids = timestamp, []
        if timestamp == newest:
            ids.append(event_id)

    if values:
        for start in range(0, len(values), BATCH):
            push_loki([{
                "stream": {"source": "app", "service": service_of(group), "log_group": group},
                "values": values[start:start + BATCH],
            }])

    previous_total = cursor.get("total", 0)
    if newest is None and last_ts is None:
        newest = int(time.time() * 1000)
    state[group] = {
        "ts": newest if newest is not None else last_ts,
        "ids": ids[-SEEN_IDS:],
        "total": previous_total + len(values),
        "last_event": values[-1][0] if values else cursor.get("last_event"),
    }
    return len(values), newest if newest is not None else cursor.get("last_event")


def main():
    state = load_state()
    lines = []
    try:
        logs = boto3.client("logs", region_name=REGION)
        groups = []
        for page in logs.get_paginator("describe_log_groups").paginate(logGroupNamePrefix=PREFIX):
            groups.extend(page["logGroups"])
        shipped = 0
        for group in groups:
            name = group["logGroupName"]
            count, last_event = ship(logs, name, state)
            shipped += count
            labels = {"log_group": name, "service": service_of(name)}
            lines.append(gauge("ecs_logs_shipped_total", state[name]["total"], **labels))
            if last_event:
                lines.append(gauge("ecs_logs_last_event_timestamp_seconds", int(last_event / 1000), **labels))
        save_state(state)
        lines += [gauge("ecs_logs_shipper_up", 1), gauge("ecs_logs_scrape_timestamp_seconds", int(time.time())), gauge("ecs_logs_shipped_run_total", shipped)]
    except Exception as exc:  # noqa: BLE001 - reported through the metric
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        lines = [gauge("ecs_logs_shipper_up", 0), gauge("ecs_logs_scrape_timestamp_seconds", int(time.time()))]
    push_metrics(lines)


main()
