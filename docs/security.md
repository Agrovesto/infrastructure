# Security decisions and review checklist

> **Workflow activation pending:** `infrastructure.yml` is intentionally stored at the repository root for a maintainer to move locally into `.github/workflows/infrastructure.yml`. CI enforcement described below is not active until that change is committed/pushed and the GitHub/Sonar controls are configured. The OIDC trust retains the exact final workflow path. Local scans analyze the inactive template without executing it.

## Account and state isolation

Dev and prod use different AWS accounts. Each provider and remote backend has `allowed_account_ids`; variables reject equal account IDs, and CI checks branch/environment/config/role/bucket/key/account agreement before assuming a role. No shared Terraform workspace/state, cross-account provider alias, peering or database-secret sharing is configured.

Bootstrap states and workload states use distinct keys in each account's state bucket:

```text
DEV account:  dev/bootstrap.tfstate     dev/terraform.tfstate
PROD account: prod/bootstrap.tfstate    prod/terraform.tfstate
```

S3 native locking uses separate `.tflock` objects. State is encrypted with a dedicated rotating KMS key, versioned and blocked from public access; its log bucket is separate. State buckets intentionally do not use Object Lock, which would stop Terraform deleting a lock object. Preserve noncurrent versions for recovery. Local state, tfvars, plans, keys, database backups and generated tooling are ignored by Git.

Terraform state is still sensitive even without generated SQL passwords. It reveals architecture, role policies, identifiers and configuration; anyone introducing another secret-bearing Terraform resource can reintroduce plaintext secrets into state. Never treat the `sensitive` flag as encryption and never upload plans/state as CI artifacts.

## IAM model and remaining power

### Bootstrap operator

A human administrator/SSO role creates remote state, OIDC trust, the runtime permissions boundary, a CI role and optionally a new DNS zone. CI cannot create or modify its own authority; bootstrap changes require independent operator review. An existing OIDC provider/detector/log group must be referenced/imported if already present rather than overwritten.

### CI provisioner

The role is **service-wide within explicitly listed infrastructure services**, necessary here for a broad account-level stack. It is not `AdministratorAccess`, but it is still highly privileged and can affect other resources in those services in the account. Important limits:

- Exact custom OIDC subject restricts repository + GitHub environment + branch + `push` event + workflow file/ref.
- IAM writes/PassRole are restricted to `${project}-${environment}-*` workload roles/profiles, approved AWS managed runtime policies and required service-linked roles.
- Creating a workload role requires the bootstrap-owned permissions boundary. CI has no permission to remove/change that boundary or create arbitrary managed IAM policies.
- Backend configuration/key destruction and bootstrap-state reads are explicitly denied; environment state object deletion is denied (lock deletion is allowed). Runtime roles cannot access the state bucket/key at all.
- Optional bootstrap DNS zones cannot be deleted by the CI role.

A service-wide provisioner can still change network/data-plane policies, delete non-protected resources, or use allowed service capabilities destructively. Dedicated accounts, SCPs, two-person review, restricted bypass access, account audit and tested restore capabilities are essential. Refine this role from CloudTrail/IAM Access Analyzer as the real resource set stabilizes. Do not advertise it as mathematically complete prevention of privilege escalation.

### Workload roles

- EC2: SSM managed instance core; read deployment artifacts/its own native backups; write its own native-backup prefix; scoped dev SQL secrets/KMS; CloudWatch logs/metrics and ECR pull.
- ECS: separate execution and task roles **per service**. Execution roles read only that API's DB secret and explicitly listed extra secrets. Frontends without a DB key do not receive DB credentials or SQL network access. Extra-secret inputs reject this stack's managed SQL-secret namespace and RDS-managed master-secret namespace, preventing that map from bypassing the automatic DB mapping. Default application task roles have no AWS API policy.
- SQL admin ECS task: privileged only for its explicit purpose—read the RDS master secret, initialize/reconcile configured API secrets and SQL databases/logins. No public IP/ingress. It is not scheduled by infrastructure CI.
- RDS native backup role: its backup bucket and KMS key only. Enhanced monitoring has the approved AWS monitoring policy, constrained by the runtime boundary.
- AWS Backup: approved backup policy plus DB-volume key grants; backup selection is only the SQL data volume.
- EventBridge: a dedicated assume-role policy restricted to its operational rule; SNS publish/KMS access scoped to the alert topic/key. No unscoped public topic access.

`GetAuthorizationToken`, `GetRandomPassword`, `PutMetricData`, some describe APIs and log stream patterns necessarily use service-level/wildcard resources. The runtime boundary is a maximum capability envelope; a narrow identity policy is still required for every role.

## Network and transport

- Public ALB only: TLS 443 and an HTTP 80 redirect. Unknown hosts get 404. Invalid HTTP headers are dropped; a modern TLS policy and strict desync mitigation are enabled.
- EC2/ECS live in private app subnets with outbound **TCP 443** through NAT. RDS is in isolated subnets with no default route and no public IP. Default VPC security-group rules are removed.
- ALB-to-workload traffic is security-group referenced and port-limited. RDS inbound is 1433 only from DB-backed API groups and the private admin group.
- Dev SQL is on the Docker bridge, with no host port publication. Its data mount is required before startup. Non-root APIs get dropped capabilities/read-only roots; dev supplies a writable memory-backed `/tmp`.
- EC2 requires IMDSv2 with hop limit one, and a Docker firewall rule blocks the metadata IP. Never mount `/var/run/docker.sock`, `/run/agrovesto`, the database disk or host AWS credentials into an API container.
- SQL encryption is requested by both environments; RDS `rds.force_ssl=1` enforces TLS after any required reboot. Prod must verify the RDS certificate using its actual endpoint and trusted CA; no `TrustServerCertificate=true` shortcut.
- **Residual plaintext hop:** ALB-to-application HTTP inside the VPC. If your compliance/threat model needs end-to-end TLS, add per-service HTTPS listeners/certificates and health checks deliberately. Do not claim private HTTP is TLS.
- Public endpoints still need application authentication/authorization, CORS/session controls, abuse protection and secure frontend build configuration. WAF does not replace these.

WAF is mandatory in prod with AWS Common, Known Bad Inputs (including Log4j protection), IP reputation and rate-based rules. Sensitive headers/query strings are redacted in WAF logs; sampled requests are disabled. Validate legitimate uploads/API paths and tune specific rules from evidence. Dev WAF is optional for cost; enabling it is recommended for internet-exposed tests involving sensitive workflows.

## Data, encryption and secrets

Workload storage, EBS, ECR, RDS, Secrets Manager, logs, SNS and backup vaults use environment encryption keys. KMS rotation is enabled and deletion is protected. The separate S3/ALB access-log delivery bucket uses SSE-S3 because ALB access-log delivery requires it; no recursive self-logging is configured.

Dev/native S3 backups and audit archives have versioning and governance retention. Account administrators with bypass permissions can bypass governance retention—use separately administered immutable copies where ransomware/insider requirements demand them. AWS Backup's lock configuration is governance-style (no irreversible compliance lock window).

Only secret metadata/ARNs are represented in Terraform. Generated dev/API password values are created by the in-VPC program; RDS manages its master secret. Root-only tmpfs env files and ECS startup-time secret injection are runtime delivery mechanisms, not encryption inside a running process. Root/admin/application code can read its delivered credentials. Protect logs and process access accordingly.

Per-API credentials and dev `sa` use the documented coordinated rotation procedure; there is no pretend Lambda that rotates only the JSON. Before production, decide between a maintenance-window rotation policy and a tested dual-login/custom rotation implementation. RDS master automatic rotation does not rotate API logins.

## Scan policy and scoped exceptions

CI has no global `soft-fail`, `continue-on-error`, scanner check allowlist, vulnerability allowlist or secret allowlist. Checkov runs all selected-framework checks; Terraform exceptions are next to the actual resource with an explanation. Trivy fails on HIGH/CRITICAL findings including unfixed image vulnerabilities. Its architectural exceptions are path-scoped and expire **2027-03-01**; review them before expiry rather than disabling the gate.

| Checkov ID | Scope / reason / compensating control |
|---|---|
| `CKV_AWS_260` | Only ALB port 80: HTTPS redirect, never a plaintext application listener. |
| `CKV_AWS_378` | ALB target groups: intentional private HTTP hop; end-to-end TLS is a documented extension. |
| `CKV_AWS_109`, `111`, `356` | KMS **key** policy: `Resource="*"` means that key; account IAM delegation and constrained service principals, not an unbounded identity policy. |
| `CKV_AWS_252` | CloudTrail records S3/CloudWatch; alarms/events use SNS rather than emailing every delivered trail file. |
| `CKV2_AWS_3` | Standalone regional GuardDuty per account; organization-wide delegated administration is external account governance. |
| `CKV2_AWS_38`, `39` | Coordinated DNSSEC/registrar DS and `us-east-1` public query logging explicitly deferred; see DNS runbook. |
| `CKV_AWS_144` | Single-region S3 baseline; cross-region replication/DR is not falsely claimed. Versioning, native backup, snapshot/PITR and restore drills are the current controls. |
| `CKV2_AWS_62` | No S3 event-consumer requirement; backup heartbeat and Backup/EventBridge events provide operational monitoring. |
| `CKV2_AWS_57` | API/dev SQL passwords require coordinated SQL+secret rotation; RDS master is separately AWS-managed. |
| `CKV2_AWS_23` | Amplify frontend A aliases target its service-managed CloudFront distribution; no separately owned CloudFront resource exists in the graph. Verify domain activation before traffic. |
| `CKV2_AWS_5` | Admin SG is used in the exported one-off `RunTask` network configuration, not an always-running ECS service. |
| `CKV2_AWS_31`, `76` | Shared conditional WAF resources/indexed association are not resolved by this Checkov graph check. Prod always enables the managed rule groups, association and logging; mock/source tests assert those controls. |

Trivy's time-bounded architecture entries address `AVD-AWS-0057` (documented IAM wildcard/service actions), `AVD-AWS-0104` (NAT HTTPS egress only) and `AVD-AWS-0107` (public ALB ingress only). They are not permission to add broad unrelated rules to those files. Code-owner review and saved-plan guards remain necessary.

A scanner pass with explicit exceptions is **not** an external audit or a compliance certification. Resource-local exceptions and tests must change together when the architecture changes. If a new scanner release reports something else, investigate it; do not expand the ignore file until the finding is understood and approved.

## Version/provenance notes

- Terraform CI version: `1.11.4`, provider: `hashicorp/aws = 6.11.0` in every root/module.
- Provider lock files contain official HashiCorp release ZIP `zh:` checksums for supported platforms. See [AWS provider 6.11.0 checksums](https://releases.hashicorp.com/terraform-provider-aws/6.11.0/terraform-provider-aws_6.11.0_SHA256SUMS). Regenerate/review with `terraform providers lock` when changing versions; keep all four roots synchronized.
- GitHub Actions are full-commit SHA pinned; Dependabot should propose reviewed updates.
- Trivy Linux x86-64 `0.74.0` is downloaded only after verifying the recorded SHA-256 from its official immutable release: `2ae6fe3ee734b7fdf11335663e18c75ea12dccc76062f09f164a3b0f8be4371a`.
- Dev Compose is pinned to `v2.39.4`, with release checksum verification before installation. SQL Server uses an explicit tested-CU **example** tag, not `latest`; adopt a current supported CU/digest only after application/restore/image-scan testing.
- The SQL admin Python minor base tag and signed Microsoft package repository are refreshed at image build. This is not a fully hermetic source build. Pin/attest base image and package versions in the real release process, then publish the resulting **scanned immutable digest**. A floating build input must never become a floating production deployment reference.

## Before live production

- Verify account MFA/SSO, SCPs, security contacts, audit ownership and GuardDuty regional coverage.
- Establish application tests/scans/image attestation, database migration review and incident ownership.
- Test SNS/budget alarms, backup failure/missing heartbeat, ECS rollback, DNS/ACM renewal and SQL CA verification.
- Restore native dev backups, an EBS volume and RDS PITR into isolated targets; record real RPO/RTO.
- Decide rotation, DNSSEC/query logging, end-to-end TLS, cross-region/independent backups and data residency/retention from actual requirements.
- Enforce code-owner/production approvals and prevent credential-bearing jobs from running untrusted code on privileged persistent runners.
