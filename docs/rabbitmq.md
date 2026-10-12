# Dev RabbitMQ

Optional, single-node RabbitMQ on the dev EC2 host. Enable `rabbitmq.enabled`
in `dev/terraform.auto.tfvars` **after** the prerequisites below. It is disabled
in the checked-in configuration to avoid breaking host bootstrap before the
secret exists. This is not a production HA broker.

## Prerequisites and rollout

1. Provision `/<project>-<environment>/rabbitmq_password` in SSM Parameter Store
   as a **SecureString**, encrypted with the stack's `host_passwords` KMS key.
   Use a cryptographically random 32–128-character hexadecimal password (for
   example generated with `openssl rand -hex 32`). Use the AWS console or your
   secret provisioning workflow, not Git or chat. The host IAM policy grants
   retrieval; bootstrap refuses a missing or malformed password. Terraform
   does not read this value into state, S3 config, or instance user data.
2. Set `rabbitmq.allowed_cidrs` to trusted operator public IP CIDRs. An empty
   list denies external UI access. Do not allow the whole internet. RabbitMQ
   username/password authentication remains required in addition to the IP gate.
3. Point `dev-rabbitmq.nomaos.com` at the dev EC2 Elastic IP in the authoritative
   DNS zone (owned by prod; dev has `manage_dns=false`). A wildcard is sufficient
   only if it actually resolves to this host. Caddy obtains the TLS certificate;
   inbound 80/443 must reach the edge. No AMQP or management port SG rules needed.
4. Enable the broker, review the Terraform plan carefully, and apply using the
   normal deployment workflow. User-data changes can replace the dev instance.
   Do not apply an instance replacement without reviewing all local data risks.
5. On an existing host, merely syncing S3 does **not** rerun bootstrap. Install
   the updated sync unit, create external network `nomaos_data`, and securely
   append `RABBITMQ_PASSWORD=<SSM value>` to the existing mode-0600
   `/opt/agrovesto/compose/.env` (do not overwrite other secrets). Sync the updated
   Compose/nginx/Caddy files. Run `docker compose config --quiet` from the compose
   directory (never print the rendered config, which contains the password),
   validate nginx, then recreate the affected services via the usual rollout.

## Endpoints and application integration

- Management: `https://dev-rabbitmq.nomaos.com`, initial user `nomaos-admin`.
- Private AMQP: `rabbitmq:5672`, virtual host `nomaos`.
- Broker attaches to Compose `default` and external `nomaos_data`. Blue/green
  app containers must join `nomaos_data`. nginx is not attached to that network;
  it reaches the management UI through `default`.
- Neither 5672 nor 15672 is published on the host. AMQP is plaintext on the
  private Docker network, not exposed over the internet.

Create separate application users restricted to the `nomaos` vhost; do not use
`nomaos-admin` in application deployments. Store app credentials in the existing
app secret store and pass them through that app's deployment pipeline. Configure
host, port, virtual host, username and password using the application's actual
RabbitMQ client configuration keys. Infrastructure does not add producers,
consumers, exchanges or queues to the application code.

## Persistence, rotation and operations

`/data/rabbitmq` stores broker state; the stable hostname/node name prevents
recreation from selecting a new data directory. Data survives container restarts
and recreation, **not EC2/root-volume replacement**. Back up broker data and
export definitions under an operator-controlled process before replacement.
This integration does not provide backups, replication or disaster recovery.
Durable queues and persistent messages must also be configured by applications;
use publisher confirms, consumer acknowledgements and bounded retry/dead-letter
policies as appropriate. Budget disk capacity for retained messages.

CPU/memory limits and RabbitMQ memory/disk alarms bound resource use. Health
checks verify the node is running without local alarms. Existing container
logging and expected-container monitoring include RabbitMQ when enabled; no
RabbitMQ-specific Prometheus plugin/scrape is configured yet.

The default user/password/vhost environment variables initialize an **empty**
data directory only. Changing SSM or recreating the container does not rotate an
existing user's password. Rotate it using RabbitMQ's authenticated management
API/CLI, update SSM and the protected host environment together, and never delete
broker data to force credential reinitialization. The admin password is visible
to host root/Docker administrators through container inspection.

## Verification

```bash
docker exec agrovesto-rabbitmq rabbitmq-diagnostics -q check_running
docker exec agrovesto-rabbitmq rabbitmq-diagnostics -q check_local_alarms
docker exec agrovesto-rabbitmq rabbitmqctl list_vhosts
curl -I https://dev-rabbitmq.nomaos.com
```

Test UI access from an allowed IP and verify 403 from a disallowed IP. Verify a
publish/consume round-trip with a least-privileged app user from an API container,
then test a broker restart. A working UI alone does not establish message flow.
