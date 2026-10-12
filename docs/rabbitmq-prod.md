# Production RabbitMQ — Amazon MQ

`prod/rabbitmq.tf` provisions a **private SINGLE_INSTANCE Amazon MQ RabbitMQ
broker**, plus a restricted management proxy behind the existing HTTPS ALB.
Production configuration enables the broker; nothing is deployed until Terraform
is applied. This adds recurring Amazon MQ, Secrets Manager, logging and (when
management access is configured) Fargate costs. This is not a multi-AZ cluster:
maintenance and broker failures can interrupt messaging.

## Review before applying

- Confirm `rabbitmq.engine_version` and `rabbitmq.instance_type` are supported
  together in the target AWS region and account. Defaults are RabbitMQ `4.2`
  and `mq.m7g.large`; availability has not been verified in this sandbox. Use
  `aws mq describe-broker-instance-options --engine-type RABBITMQ --region
  eu-west-1` and `aws mq describe-broker-engine-types --engine-type RABBITMQ
  --region eu-west-1` to review current offerings, pricing separately, and adjust
  the variables before applying. Do not downgrade an existing broker in place.
- The broker uses the first private subnet, TLS-only app access on **5671**,
  AWS-owned-key storage encryption, automatic minor upgrades, and a Sunday
  03:00 UTC maintenance window. Changes are not applied immediately.
- Confirm private-subnet NAT access for the proxy image pull and CloudWatch logs.
- Set up to **three** operator public CIDRs in `rabbitmq.allowed_cidrs`.
  Empty means deny all: DNS points at the ALB, but management returns 403 and
  no proxy ECS service starts. ALB source-IP matching does not trust a caller's
  `X-Forwarded-For`. Reserved rule priorities are 209 (allow) and 210 (deny).
- The existing wildcard ACM certificate covers `rabbitmq.nomaos.com`.
  No new DNS zone or public AMQP endpoint is introduced.
- Review `terraform -chdir=prod plan` before apply. `prevent_destroy` protects
  the broker against replacement/deletion: any intentional replacement requires
  an explicit code review and a data migration plan, not merely toggling enabled.

## Management and authentication

`https://rabbitmq.nomaos.com` → existing ALB (TLS + CIDR restriction) → private
Fargate nginx proxy → Amazon MQ HTTPS console. The proxy verifies the broker's
TLS certificate and hostname, resolves DNS at runtime, and forwards the
operator's Authorization header. It has no embedded credentials or application
IAM role. The broker console/API still requires RabbitMQ authentication; this
is not OIDC/SSO. ALB-to-proxy traffic is HTTP inside the VPC, restricted by SGs.

Retrieve bootstrap credentials from the Secrets Manager ARN in
`terraform output rabbitmq_access`, using an authorized operator role. The
initial username is `nomaos-admin`. Terraform generates the password and stores
it in Secrets Manager; **the password also exists in Terraform state**. Protect
state and plans accordingly. No password is printed in outputs or injected into
all ECS services. Create individual operator accounts and application users,
then restrict bootstrap account use. Secret access IAM is intentionally not
granted to application task roles.

## Connecting applications

Use the broker's original `amqps://...:5671` endpoint from `rabbitmq_access`,
with TLS certificate/hostname verification enabled. Do not use the management
hostname for AMQP and do not replace the broker hostname with a custom alias
that fails certificate verification. App ECS security group access is granted;
other callers require reviewed security-group rules.

Create a `nomaos` virtual host and separate least-privileged users/permissions
through the management API/UI. Amazon MQ creates only the bootstrap admin here;
vhosts, queues, exchanges, policies and app credentials are not provisioned by
this module. Use the application's secret store (Vault or Secrets Manager) and
actual client configuration keys. Infrastructure does not implement producers
or consumers. Enable connection recovery, publisher confirms, consumer
acknowledgements, durable queues, persistent messages, and sensible retry/DLQ
policies in the applications.

## Operations and verification

- Verify UI login from an allowed source and 403 from a disallowed source.
- Verify TLS publish/consume from an ECS application, not only proxy health.
- `/__proxy_health` checks nginx only; it does not prove broker health.
- General broker logs and proxy logs go to CloudWatch. Add workload-specific
  RabbitMQ memory/disk/message backlog/consumer alarms and paging before relying
  on this for critical production traffic; they are not part of this initial
  integration.
- Amazon MQ manages broker storage, but this integration provides no
  cross-region DR or operator-restorable message backups. Export definitions,
  document replay/recovery procedures, and rehearse maintenance/reconnection.
- Rotate RabbitMQ credentials using the supported broker API and update the
  corresponding Secrets Manager values and application consumers together.
  Updating a secret alone does not rotate a broker user; changing the Terraform
  bootstrap password is not a tested rotation workflow.
- Terraform/Docker runtime tests and an AWS plan must pass in CI before deploy.
