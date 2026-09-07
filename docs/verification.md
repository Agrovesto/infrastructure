# Verification and acceptance

## What this repository can test without AWS

- Python SQL-administration functions: identifiers/literals, no password command-line/log exposure, TLS mode, secret metadata/value handling, private raw env files, disk mount guard, provisioning idempotency, backup upload/manifest/checksum and failure heartbeat.
- CI input/account/branch/backend agreement and saved-plan data-deletion/security guards.
- HCL/YAML parsing, module interface wiring, account restrictions, protected resources, network separation, SQL Server settings, workflow pinning/permissions/dependencies and documentation presence.
- Terraform **provider-schema mocked plan tests** for all four roots. Mock results are synthetic and no backend/apply/cloud resource is used. They test module expressions/validation, not the AWS service APIs.
- Checkov static policies and Trivy source/dependency/image scans.

## Development-environment verification status

Verified locally on **2026-09-07**:

| Check | Result |
|---|---|
| Python/runtime/repository/workflow tests | **62 passed** |
| Python statement coverage (`database.py` and CI Python helpers) | **100%**, 358 statements; not a claim of integration/branch coverage |
| ShellCheck and Bash syntax checks | Passed for all shell scripts |
| HCL syntax and local module-interface tests | Passed, including examples and mock-test configuration |
| HCL formatter idempotence | Passed using `hclwrite.Format` (not the Terraform executable) |
| Checkov Terraform | **563 passed, 0 failed, 38 scoped skips** |
| Checkov Dockerfile | **47 passed, 0 failed, 0 skipped** |
| Checkov GitHub Actions | **144 passed, 0 failed, 0 skipped** |
| Local documentation links / Git whitespace check | Passed |

Checkov: **754 passed total**; all exceptions are explained in the source and security runbook. Its wrapper rejects missing/empty framework results. Local transient reports/tooling are ignored rather than committed.

Terraform and Trivy executable/provider downloads from their release endpoints are blocked in this sandbox. Consequently **real Terraform `init`/`validate`/`test`, Trivy scanning, Docker image build/runtime tests, SonarQube analysis and AWS deployment/restore tests cannot be claimed as locally executed**. HCL formatting is performed with HashiCorp's `hclwrite.Format` through `@cdktf/hcl-tools`; this does not replace provider validation. Lock checksums are taken from the official HashiCorp release.

The supplied workflow includes the missing executable-level checks and fails closed if they fail or Sonar is not configured **after activation**. It is currently an inactive root-level `infrastructure.yml`; move it locally into `.github/workflows/infrastructure.yml` and commit/push before relying on any GitHub checks or deployment gates. Local workflow checks still run against the template, with Checkov analyzing a disposable copy under its required discovery path rather than activating the file. Passing local static tests is not permission to bypass that gate. No AWS credentials/accounts were supplied and no AWS resources were applied by this implementation.

## Required acceptance in your accounts

1. Activate the root workflow at the exact documented path, then run the complete GitHub checks on a trusted PR with real Sonar configuration. Require a successful format/validate/mocked-plan result for **both environment and both bootstrap roots**, and a successful Trivy Docker image scan. Resolve any provider/scanner/runtime issues before deployment, without broad skip switches.
2. Verify protected `dev`/`prod` environment policies and custom OIDC subjects. A dev push must not assume the prod role; a PR/manual/tag workflow must not assume either deployment role. Do not log JWTs to test this.
3. Use `aws sts get-caller-identity` in each authorized operator profile. Bootstrap each account and confirm encrypted/versioned state, locking and restored-version procedures.
4. Validate DNS authority, NS delegation, existing-record preservation, ACM issuance, Amplify custom domains and HTTPS redirects externally. Do not test solely against cached DNS from one machine.
5. Confirm all EC2/ECS/RDS resources have the expected private placement, no public SQL/SSH ingress, allowed SG paths and working NAT/SSM/ECR/Secrets Manager connectivity. Confirm ECR pull works both ways, while cross-account pushes and DB-secret reads are denied.
6. On dev, verify `/srv/mssql` is the distinct encrypted EBS volume. Start with an empty disk, then reboot and run convergence again; it must not format an existing disk. Test a controlled missing-disk scenario on a disposable host: application startup must fail, with SSM still available.
7. Check SQL Server readiness, database/login creation for multiple APIs, UID/filesystem contracts and real application connection-string adaptation. Confirm an API cannot access another database; a frontend should have neither credentials nor TCP 1433 access. Verify **encrypted, certificate-verified** production SQL connections and apply pending TLS parameter reboots.
8. Build/publish/scan genuine application/admin images. Run the private prod SQL admin task, migrations, then enable services. Confirm task health, two-AZ distribution, CPU/memory scaling, read-only filesystem compatibility and a deliberate failing deployment rollback.
9. Exercise native dev backup success and a controlled failed-upload condition. Verify S3 encryption/versioning/retention/checksum and the missing/failure alarm. Confirm AWS Backup completes a DB-volume job and surfaces failures.
10. Restore a dev `.bak` to a new database, restore an EBS recovery volume and perform RDS PITR into an isolated new instance. Run `DBCC CHECKDB` plus application tests; record recovery time/data loss and credential/SID reconciliation. A successful `VERIFYONLY` is not enough.
11. Confirm SNS emails, dashboards/log retention, RDS events, GuardDuty routing, unauthorized-call alarm and budget recipients. Test the EventBridge/SNS/KMS delivery path; configuring a topic is not proof the notification arrives.
12. Review a pricing estimate, quotas, security exceptions, restore ownership, credential rotation, dependencies and the unresolved hardening/DR extensions with the production owner.

Record acceptance evidence without passwords, signed URLs, state/plan payloads, production data or token-bearing logs. If deployment stops halfway, inspect remote state and the actual AWS operation before retrying; never delete state to "start fresh."
