"""ECS cluster and service state for Pushgateway.

Reads the ECS API (DescribeServices / ListTasks) instead of Container Insights or
CloudWatch metrics, and is pushed under job="ecs" where Prometheus scrapes it.
A failure only reports ecs_up 0; the task itself exits 0.
"""

import json
import os
import sys
import time
import urllib.request

import boto3

REGION = os.environ.get("AWS_REGION", "eu-west-1")
CLUSTER = os.environ["ECS_CLUSTER"]
PUSH = os.environ["PUSHGATEWAY_URL"].rstrip("/")
STOPPED_LIMIT = int(os.environ.get("STOPPED_TASK_LIMIT", "50"))


def gauge(name, value, **labels):
    label = ",".join(f'{key}="{val}"' for key, val in labels.items())
    return f"{name}{{{label}}} {value}" if label else f"{name} {value}"


def push(lines):
    body = ("\n".join(lines) + "\n").encode()
    request = urllib.request.Request(f"{PUSH}/metrics/job/ecs", data=body, method="PUT")
    request.add_header("Content-Type", "text/plain")
    urllib.request.urlopen(request, timeout=15).read()


def services(ecs):
    arns = []
    for page in ecs.get_paginator("list_services").paginate(cluster=CLUSTER):
        arns.extend(page["serviceArns"])
    described = []
    for start in range(0, len(arns), 10):
        described.extend(
            ecs.describe_services(cluster=CLUSTER, services=arns[start:start + 10])["services"]
        )
    return described


def tasks(ecs, status):
    count = 0
    for page in ecs.get_paginator("list_tasks").paginate(cluster=CLUSTER, desiredStatus=status):
        count += len(page["taskArns"])
    return count


def stopped_reasons(ecs):
    arns = ecs.list_tasks(cluster=CLUSTER, desiredStatus="STOPPED")["taskArns"][:STOPPED_LIMIT]
    reasons = {}
    if arns:
        for task in ecs.describe_tasks(cluster=CLUSTER, tasks=arns)["tasks"]:
            code = task.get("stopCode", "Unknown")
            for container in task.get("containers", []):
                if container.get("exitCode"):
                    code = f"{code}_{container['exitCode']}"
            reasons[code] = reasons.get(code, 0) + 1
    return reasons


def collect(ecs):
    lines = [gauge("ecs_up", 1)]
    described = services(ecs)

    lines.append(gauge("ecs_cluster_services", len(described), cluster=CLUSTER))
    lines.append(gauge("ecs_cluster_running_tasks", tasks(ecs, "RUNNING"), cluster=CLUSTER))
    lines.append(gauge("ecs_cluster_pending_tasks", tasks(ecs, "PENDING"), cluster=CLUSTER))

    for service in described:
        name = service["serviceName"]
        lines.append(gauge("ecs_service_desired_count", service["desiredCount"], cluster=CLUSTER, service=name))
        lines.append(gauge("ecs_service_running_count", service["runningCount"], cluster=CLUSTER, service=name))
        lines.append(gauge("ecs_service_pending_count", service["pendingCount"], cluster=CLUSTER, service=name))

        failed = 0
        for deployment in service.get("deployments", []):
            state = deployment.get("rolloutState", "UNKNOWN")
            lines.append(gauge("ecs_service_rollout_state", 1, cluster=CLUSTER, service=name, state=state))
            if state == "FAILED":
                failed = 1
        lines.append(gauge("ecs_service_deployment_failed", failed, cluster=CLUSTER, service=name))
        lines.append(gauge("ecs_service_desired_status", 1 if service["status"] == "ACTIVE" else 0, cluster=CLUSTER, service=name))

    for code, count in stopped_reasons(ecs).items():
        lines.append(gauge("ecs_stopped_tasks", count, cluster=CLUSTER, stop_code=code))

    lines.append(gauge("ecs_scrape_timestamp_seconds", int(time.time())))
    return lines


def main():
    try:
        push(collect(boto3.client("ecs", region_name=REGION)))
    except Exception as exc:  # noqa: BLE001 - any failure is reported through the metric
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        push([gauge("ecs_up", 0), gauge("ecs_scrape_timestamp_seconds", int(time.time()))])


main()
