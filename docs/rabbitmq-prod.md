# Production RabbitMQ — Amazon MQ

`prod/rabbitmq.tf` provisions a **private SINGLE_INSTANCE Amazon MQ RabbitMQ
broker**, reachable only by authorized application services in the production
ECS cluster. There is no public hostname, ALB listener, management proxy, or
external-source ingress.
Production configuration enables the broker; nothing is deployed until Terraform
is applied. This adds recurring Amazon MQ, Secrets Manager and logging costs. This is not a multi-AZ cluster:
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
- Both AMQPS (5671) and management HTTPS (443) accept only the dedicated
  `rabbitmq_clients` security group, attached to `aws_ecs_service.services`.
  Existing general ECS/Vault tasks do not automatically receive this access.
- Security groups identify network interfaces, not ECS cluster identity. IAM
  permissions must prevent attaching this group to EC2 instances, other clusters,
  or externally accessible proxies. This Terraform stack only attaches it to
  the application services in `aws_ecs_cluster.main`.
- Review `terraform -chdir=prod plan` before apply. `prevent_destroy` protects
  the broker against replacement/deletion: any intentional replacement requires
  an explicit code review and a data migration plan, not merely toggling enabled.

## Management and authentication

Use the broker-provided private HTTPS endpoint from an authorized ECS application
service. No browser-accessible `rabbitmq.nomaos.com`, VPN exceptions, port-forward
proxy, or public CIDR allowlist is provisioned. Management/API requests require
RabbitMQ credentials as well as network access. If an operator needs to provision
vhosts/users, run the operation in an authorized ECS workload; do not temporarily
open the broker to the internet. Keep TLS certificate/hostname verification on.

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
that fails certificate verification. Only application tasks carrying the dedicated client security group can connect;
external clients must remain blocked.

Create a `nomaos` virtual host and separate least-privileged users/permissions
through the management API/UI. Amazon MQ creates only the bootstrap admin here;
vhosts, queues, exchanges, policies and app credentials are not provisioned by
this module. Use the application's secret store (Vault or Secrets Manager) and
actual client configuration keys. Infrastructure does not implement producers
or consumers. Enable connection recovery, publisher confirms, consumer
acknowledgements, durable queues, persistent messages, and sensible retry/DLQ
policies in the applications.

## Operations and verification

- Verify TLS publish/consume and authenticated management API access from an
  authorized ECS application service. Verify connection failure from a separate
  VPC workload without the client SG and from outside the VPC.
- General broker logs go to CloudWatch. Add workload-specific
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

## Migrating from the earlier public-proxy proposal

The public proxy, target group, listener rules and DNS record were removed from
this branch. If that earlier version was deployed separately, review the plan
for their destruction and the removal of the proxy SG from broker ingress.
Updating application security-group membership triggers ECS task replacement;
review availability and connection recovery before applying. The broker itself
should not be replaced solely for this network restriction.
