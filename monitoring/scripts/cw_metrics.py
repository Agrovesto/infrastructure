"""Collect the basic CloudWatch metrics every AWS resource publishes for free.

Container Insights, enhanced monitoring and Performance Insights stay off: this
reads only the standard no-cost metrics of the namespaces the platform runs on
(AWS/ECS, AWS/ApplicationELB, AWS/RDS, AWS/NATGateway, AWS/EFS) and republishes
them as Prometheus series through Pushgateway, so every dashboard, alert and
retention decision still lives in Grafana/Prometheus instead of CloudWatch.

Windows are contiguous and never overlap: the previous run's end is this run's
start (checkpointed on EFS), shifted back by METRIC_DELAY_SECONDS because basic
CloudWatch metrics land a few minutes late. Counter-style series (request,
connection and byte counts) are therefore true totals for their own window, and
sum_over_time() across a day is a true daily total.

Dimension sets are discovered with ListMetrics, so no describe permission is
needed for any service: the only IAM actions are cloudwatch:ListMetrics and
cloudwatch:GetMetricData. Units are left exactly as CloudWatch publishes them
(percent, bytes, bytes/second, seconds, counts), which is what the dashboards
expect.

Writes: Pushgateway job="cloudwatch".
"""

import json
import os
import sys
import time
import urllib.request

import boto3

REGION = os.environ.get("AWS_REGION", "eu-west-1")
PUSH = os.environ["PUSHGATEWAY_URL"].rstrip("/")
# Own variable name: the collector task already sets STATE_FILE for the ECS
# log shipper, and all three scripts share one container.
STATE = os.environ.get("CW_STATE_FILE", "/collector/state/cw_metrics.json")

# Optional pins. Empty means "everything ListMetrics finds in this namespace",
# so an account with a second cluster, load balancer or database is covered by
# clearing the value instead of by changing the script.
CLUSTER = os.environ.get("ECS_CLUSTER", "")
ALB_ARN_SUFFIX = os.environ.get("ALB_ARN_SUFFIX", "")
SERVICE_PREFIX = os.environ.get("SERVICE_PREFIX", "")

DELAY = int(os.environ.get("METRIC_DELAY_SECONDS", "300"))
MAX_WINDOW = int(os.environ.get("MAX_WINDOW_MINUTES", "30")) * 60
MIN_WINDOW = int(os.environ.get("MIN_WINDOW_SECONDS", "60"))
MAX_SERIES = int(os.environ.get("MAX_SERIES", "200"))
QUERIES_PER_CALL = 100  # GetMetricData accepts at most 100 queries per call.

# What to collect, one entry per dimension shape. `anchor` is the metric used
# to discover the dimension sets; `pin` names the dimension whose value must
# match the environment pin (when one is set); `metrics` lists
# (CloudWatch metric, statistic, Prometheus metric).
SPECS = [
    {
        "namespace": "AWS/ECS",
        "anchor": "CPUUtilization",
        "dimensions": ("ClusterName", "ServiceName"),
        "pin": ("ClusterName", CLUSTER),
        "metrics": [
            ("CPUUtilization", "Average", "ecs_service_cpu_utilization_percent"),
            ("CPUUtilization", "Maximum", "ecs_service_cpu_utilization_percent_max"),
            ("MemoryUtilization", "Average", "ecs_service_memory_utilization_percent"),
            ("MemoryUtilization", "Maximum", "ecs_service_memory_utilization_percent_max"),
        ],
    },
    {
        "namespace": "AWS/ApplicationELB",
        "anchor": "RequestCount",
        "dimensions": ("LoadBalancer",),
        "pin": ("LoadBalancer", ALB_ARN_SUFFIX),
        "metrics": [
            ("RequestCount", "Sum", "alb_request_count"),
            ("HTTPCode_ELB_5XX_Count", "Sum", "alb_elb_5xx_count"),
            ("HTTPCode_Target_5XX_Count", "Sum", "alb_target_5xx_count"),
            ("HTTPCode_Target_4XX_Count", "Sum", "alb_target_4xx_count"),
            ("TargetResponseTime", "Average", "alb_target_response_time_seconds"),
            ("TargetResponseTime", "Maximum", "alb_target_response_time_seconds_max"),
            ("ActiveConnectionCount", "Average", "alb_active_connections"),
            ("NewConnectionCount", "Sum", "alb_new_connections"),
            ("RejectedConnectionCount", "Sum", "alb_rejected_connections"),
        ],
    },
    {
        "namespace": "AWS/ApplicationELB",
        "anchor": "HealthyHostCount",
        "dimensions": ("LoadBalancer", "TargetGroup"),
        "pin": ("LoadBalancer", ALB_ARN_SUFFIX),
        "metrics": [
            ("HealthyHostCount", "Average", "alb_healthy_hosts"),
            ("UnHealthyHostCount", "Average", "alb_unhealthy_hosts"),
        ],
    },
    {
        "namespace": "AWS/RDS",
        "anchor": "CPUUtilization",
        "dimensions": ("DBInstanceIdentifier",),
        "metrics": [
            ("CPUUtilization", "Average", "rds_cpu_utilization_percent"),
            ("CPUUtilization", "Maximum", "rds_cpu_utilization_percent_max"),
            ("FreeableMemory", "Average", "rds_freeable_memory_bytes"),
            ("FreeStorageSpace", "Average", "rds_free_storage_space_bytes"),
            ("DatabaseConnections", "Average", "rds_database_connections"),
            ("DatabaseConnections", "Maximum", "rds_database_connections_max"),
            ("ReadIOPS", "Average", "rds_read_iops"),
            ("WriteIOPS", "Average", "rds_write_iops"),
            ("DiskQueueDepth", "Average", "rds_disk_queue_depth"),
            ("NetworkReceiveThroughput", "Average", "rds_network_receive_bytes_per_second"),
            ("NetworkTransmitThroughput", "Average", "rds_network_transmit_bytes_per_second"),
            ("ReadLatency", "Average", "rds_read_latency_seconds"),
            ("WriteLatency", "Average", "rds_write_latency_seconds"),
            ("BurstBalance", "Average", "rds_burst_balance_percent"),
        ],
    },
    {
        "namespace": "AWS/NATGateway",
        "anchor": "BytesOutToDestination",
        "dimensions": ("NatGatewayId",),
        "metrics": [
            ("BytesInFromDestination", "Sum", "nat_gateway_bytes_in_from_destination"),
            ("BytesOutToDestination", "Sum", "nat_gateway_bytes_out_to_destination"),
            ("PacketsInFromDestination", "Sum", "nat_gateway_packets_in_from_destination"),
            ("PacketsOutToDestination", "Sum", "nat_gateway_packets_out_to_destination"),
            ("ErrorPortAllocation", "Sum", "nat_gateway_error_port_allocation"),
            ("ActiveConnectionCount", "Average", "nat_gateway_active_connections"),
        ],
    },
    {
        "namespace": "AWS/EFS",
        "anchor": "StorageBytes",
        "dimensions": ("FileSystemId",),
        "metrics": [
            ("StorageBytes", "Average", "efs_storage_bytes"),
            ("TotalIOBytes", "Sum", "efs_total_io_bytes"),
            ("MeteredIOBytes", "Sum", "efs_metered_io_bytes"),
            ("BurstCreditBalance", "Average", "efs_burst_credit_balance_bytes"),
            ("PercentIOLimit", "Average", "efs_percent_io_limit"),
        ],
    },
]


def gauge(name, value, **labels):
    label = ",".join(f'{key}="{val}"' for key, val in sorted(labels.items()))
    return f"{name}{{{label}}} {value}" if label else f"{name} {value}"


def number(value):
    """Counts stay integers, rates keep enough precision to be useful."""
    rounded = round(value, 4)
    return int(rounded) if rounded == int(rounded) else rounded


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


def push(lines):
    body = ("\n".join(lines) + "\n").encode()
    request = urllib.request.Request(f"{PUSH}/metrics/job/cloudwatch", data=body, method="PUT")
    request.add_header("Content-Type", "text/plain")
    urllib.request.urlopen(request, timeout=30).read()


def window(state):
    """[start, end) for this run: contiguous with the previous one, delayed."""
    end = int(time.time()) - DELAY
    previous = int(state.get("last_end", 0))
    start = max(previous, end - MAX_WINDOW) if previous else end - MAX_WINDOW
    return start, max(end, start + MIN_WINDOW)


def period_for(seconds):
    if seconds <= 3600:
        return 60
    return 300 if seconds <= 10800 else 3600


def service_of(name):
    """agrovesto-prod-wallet -> wallet, so ALB and ECS series share `service`."""
    if SERVICE_PREFIX and name.startswith(SERVICE_PREFIX):
        return name[len(SERVICE_PREFIX):] or name
    return name


def labels_for(spec, dimensions):
    """Turn CloudWatch dimension values into readable Prometheus labels."""
    labels = {}
    for dimension in dimensions:
        name, value = dimension["Name"], dimension["Value"]
        if name == "LoadBalancer":
            # app/agrovesto-prod-alb/50dc6c495c0c9188
            labels["load_balancer"] = value.split("/")[1] if value.count("/") >= 2 else value
            labels["load_balancer_id"] = value
        elif name == "TargetGroup":
            # targetgroup/agrovesto-prod-wallet/9c8f5b1a2d3e4f50
            short = value.split("/")[1] if value.count("/") >= 2 else value
            labels["target_group"] = short
            labels["service"] = service_of(short)
        elif name == "ClusterName":
            labels["cluster"] = value
        elif name == "ServiceName":
            labels["service"] = value
        elif name == "DBInstanceIdentifier":
            labels["db_instance"] = value
        elif name == "NatGatewayId":
            labels["nat_gateway"] = value
        elif name == "FileSystemId":
            labels["file_system"] = value
        else:
            labels[name.lower()] = value
    return labels


def discover(cw, spec):
    """Dimension sets that publish the anchor metric, pinned and de-duplicated."""
    pinned = spec.get("pin", ("", ""))
    wanted = [{"Name": name} for name in spec["dimensions"]]
    sets, seen = [], set()
    for page in cw.get_paginator("list_metrics").paginate(
        Namespace=spec["namespace"], MetricName=spec["anchor"], Dimensions=wanted
    ):
        for metric in page.get("Metrics", []):
            dimensions = sorted(metric.get("Dimensions", []), key=lambda item: item["Name"])
            if len(dimensions) != len(spec["dimensions"]):
                continue
            if pinned[1] and not any(
                item["Name"] == pinned[0] and item["Value"] == pinned[1] for item in dimensions
            ):
                continue
            key = tuple((item["Name"], item["Value"]) for item in dimensions)
            if key not in seen:
                seen.add(key)
                sets.append(dimensions)
    if len(sets) > MAX_SERIES:
        print(json.dumps({"warn": "series capped", "namespace": spec["namespace"],
                          "found": len(sets), "kept": MAX_SERIES}), file=sys.stderr)
        sets = sets[:MAX_SERIES]
    return sets


def queries_for(spec, sets, period):
    """One MetricDataQuery per dimension set per metric, with its labels."""
    queries, index = [], {}
    for position, dimensions in enumerate(sets):
        labels = labels_for(spec, dimensions)
        for metric, statistic, prometheus in spec["metrics"]:
            query_id = f"q{len(queries)}"
            index[query_id] = (prometheus, labels, statistic)
            queries.append({
                "Id": query_id,
                "MetricStat": {
                    "Metric": {
                        "Namespace": spec["namespace"],
                        "MetricName": metric,
                        "Dimensions": dimensions,
                    },
                    "Period": period,
                    "Stat": statistic,
                },
                "ReturnData": True,
            })
    return queries, index


def aggregate(statistic, values):
    if not values:
        return None
    if statistic == "Sum":
        return sum(values)
    if statistic == "Maximum":
        return max(values)
    if statistic == "Minimum":
        return min(values)
    return sum(values) / len(values)


def collect(cw, start, end):
    period = period_for(end - start)
    lines = []
    for spec in SPECS:
        sets = discover(cw, spec)
        if not sets:
            continue
        queries, index = queries_for(spec, sets, period)
        for batch in range(0, len(queries), QUERIES_PER_CALL):
            chunk = queries[batch:batch + QUERIES_PER_CALL]
            response = cw.get_metric_data(
                MetricDataQueries=chunk, StartTime=start, EndTime=end, ScanBy="TimestampAscending"
            )
            for result in response.get("MetricDataResults", []):
                prometheus, labels, statistic = index[result["Id"]]
                values = [float(point) for point in result.get("Values", []) if point is not None]
                total = aggregate(statistic, values)
                if total is not None:
                    lines.append(gauge(prometheus, number(total), **labels))
    return lines


def main():
    state = load_state()
    start, end = window(state)
    lines = []
    try:
        cw = boto3.client("cloudwatch", region_name=REGION)
        lines = collect(cw, start, end)
        state["last_end"] = end
        save_state(state)
        lines += [
            gauge("cloudwatch_collector_up", 1),
            gauge("cloudwatch_collector_timestamp_seconds", int(time.time())),
            gauge("cloudwatch_window_start_seconds", start),
            gauge("cloudwatch_window_seconds", end - start),
            gauge("cloudwatch_series", len(lines)),
        ]
    except Exception as exc:  # noqa: BLE001 - any failure is reported through the metric
        print(json.dumps({"error": str(exc), "window": [start, end]}), file=sys.stderr)
        lines = [
            gauge("cloudwatch_collector_up", 0),
            gauge("cloudwatch_collector_timestamp_seconds", int(time.time())),
        ]
    push(lines)


main()
