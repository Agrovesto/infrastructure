# GitHub Actions, OIDC and SonarQube

## Manual activation required

The supplied workflow is **`infrastructure.yml` at the repository root**, not an active GitHub workflow. It is deliberately shipped this way so a repository maintainer can move it locally with workflow-authorized access. No checks or deployment jobs from this template run while it remains at the root.

From the repository root in your local checkout:

```bash
mkdir -p .github/workflows
git mv infrastructure.yml .github/workflows/infrastructure.yml
git commit -m "ci: activate infrastructure workflow"
```

Push that commit using your authorized GitHub account. Keep the filename exactly `infrastructure.yml`: the bootstrap OIDC policies intentionally trust the **installed** `.github/workflows/infrastructure.yml` path. Do not weaken/change the trust to the inactive root path. Complete branch/environment protections and Sonar configuration before enabling deployments, and run the full PR gate after activation.

Local tests read the installed workflow if present, otherwise the root template. `make checkov` scans Terraform/Dockerfile sources and a disposable copy of the selected workflow under a temporary `.github/workflows/` directory; it does not register, enable or execute Actions. Missing workflows, differing duplicate copies, missing framework results and scan failures all fail the local check. Once the workflow is installed, the same checks continue to work. GitHub Actions dependency updates also require activation in the standard workflow directory.

## Pipeline contract

Once installed, `.github/workflows/infrastructure.yml` handles `pull_request` and pushes to the literal `dev` and `prod` branches. It has no manual dispatch, schedule, `pull_request_target`, `workflow_run` or PR apply route.

| Job | Credentials/network | What it gates |
|---|---|---|
| Unit | No AWS credentials | Python unit/structural tests, >=80% coverage, ShellCheck |
| Terraform × four roots | No AWS credentials; public provider download only | Recursive format, init without backend, validate, schema-aware mocked plans |
| Checkov | No AWS credentials | Terraform, Dockerfile and workflow policies, documented local exceptions |
| Trivy | No AWS credentials; public packages/registries for build/scan | IaC, dependency vulnerabilities, secret scan; Docker build + SQL admin image scan |
| Sonar | Sonar token only; HTTPS to your server | Same-repo PR/branch analysis, coverage and **wait for quality gate** |
| All required checks | No AWS credentials | Every dependency must return `success`; skipped is not success |
| Deploy | OIDC, protected environment; only matching `push` | Verify input/account, remote plan, protected-data guard, apply saved plan |

The Checkov wrapper also requires a non-empty passing result for **each** configured framework, so a YAML-schema/discovery failure cannot masquerade as a zero-finding success. Push checks are rerun independently; a prior green PR does not bypass them. Applies are serialized and are **never cancelled** by a newer push. Terraform's S3 lock is a second concurrency layer. The same runner applies the same saved plan, without uploading state or plans as artifacts. The only uploaded artifact is coverage, retained for three days.

The infrastructure workflow does not publish application images or run SQL/schema migrations. Use separate, least-privilege image/application release roles in those repositories. Do not extend this infrastructure role's OIDC trust to every application repository.

## 1. Protect branches and environments

Create the `dev` and `prod` branches from the reviewed infrastructure implementation. Existing `devops` or similarly named branches do **not** deploy automatically.

For **both** branches configure a repository ruleset/branch protection:

- Require PRs, up-to-date checks and the exact status **`All required checks`**.
- Require code-owner review. Rename `.github/CODEOWNERS.example` to `CODEOWNERS` and use an actual existing team with repository write access. Protect the entire repository, not only Terraform files.
- Dismiss stale approvals and require approval after the last push. Prefer two reviewers for prod, especially IAM/workflow/scanner changes.
- Block force pushes/deletion and restrict bypass/direct push permissions, including for administrators where practical.

Create GitHub environments named exactly `dev` and `prod`:

- Deployment branch policies must allow **only `dev` for dev**, **only `prod` for prod**. Do not permit arbitrary protected branches or tags.
- Require production reviewers, prevent self-approval and restrict environment-admin access. An optional dev approval is a cost-control choice.
- Deployment approval happens before the job obtains AWS credentials and makes its real plan. There is **no second approval after the plan** in this workflow; if your governance requires plan-before-approval, add a separately scoped read-only planning role/job rather than sharing a privileged plan artifact with PRs.

These GitHub controls are prerequisites, not Terraform-managed GitHub resources. Review them after organization/ruleset changes.

## 2. Set the custom OIDC subject template (required)

The default GitHub environment OIDC subject does **not** include the branch. Bootstrap deliberately trusts a stricter custom subject, so a default subject will fail to assume the role.

Once both AWS trust policies exist, configure the repository with an authorized GitHub admin session:

```bash
cat > /tmp/oidc-subject.json <<'JSON'
{
  "use_default": false,
  "include_claim_keys": ["repo", "context", "ref", "event_name", "workflow_ref"]
}
JSON

gh api --method PUT repos/Agrovesto/infrastructure/actions/oidc/customization/sub \
  --input /tmp/oidc-subject.json
rm /tmp/oidc-subject.json
```

With the standard repository-name subject format, the exact dev subject is:

```text
repo:Agrovesto/infrastructure:environment:dev:ref:refs/heads/dev:event_name:push:workflow_ref:Agrovesto/infrastructure/.github/workflows/infrastructure.yml@refs/heads/dev
```

Prod substitutes `prod` in **all** relevant positions. The audience must equal `sts.amazonaws.com`. Renaming the repository/workflow, changing the case of its owner/name, moving the workflow or changing OIDC subject policies requires an intentional bootstrap trust update.

If your organization/repository uses GitHub's immutable repository/owner-ID subject format, inspect the actual subject **without logging the JWT** and set bootstrap `github_oidc_subject` to that exact value. Its validation requires retaining the environment/ref/push/workflow suffix. Do not solve a mismatch by changing the trust to `repo:ORG/*` or an environment-only wildcard.

OIDC customization affects other workflows in this repository too. Jobs that request OIDC must supply the required claims. This workflow requests an ID token only in the protected deploy job.

If an AWS GitHub OIDC provider already exists in the account, provide `existing_oidc_provider_arn` to bootstrap or import the existing provider instead of attempting a duplicate. GitHub credentials are already handled by your GitHub connection; no PAT is needed for this infrastructure workflow.

## 3. Environment configuration

Set these separately on the **GitHub environment**, not as shared fallback repository variables:

| Variable | Dev example | Prod example |
|---|---|---|
| `AWS_ACCOUNT_ID` | Real dev 12-digit ID | Different real prod ID |
| `AWS_REGION` | `eu-west-1` | `eu-west-1` |
| `AWS_ROLE_ARN` | Dev bootstrap `deployment_role_arn` output | Prod bootstrap output |
| `TF_STATE_BUCKET` | Dev bootstrap `state_bucket` output | Prod bootstrap output |
| `TF_STATE_KMS_KEY_ARN` | Dev bootstrap key ARN (**key**, not alias) | Prod bootstrap key ARN |
| `TF_VARS_JSON` | Literal JSON corresponding to dev inputs | Literal JSON corresponding to prod inputs |

Example non-secret variable command (replace values):

```bash
gh variable set AWS_ACCOUNT_ID --env dev --body 'YOUR_DEV_ACCOUNT_ID'
# Set remaining variables using the GitHub UI or gh variable set.
```

`write_deploy_config.py` rejects environment/ref/event mismatches, same-account dev/prod, wrong roles, wrong boundaries, wrong state buckets/keys and region inconsistencies **before** requesting AWS credentials. It creates a mode-0600 temporary backend file and ignored `ci.auto.tfvars.json` and never prints their contents. The backend key is constructed in code, not supplied by the user: `dev/terraform.tfstate` or `prod/terraform.tfstate`.

Configuration changes to GitHub variables do not themselves trigger a deployment. Review them, then make a reviewed branch push. PR tests exercise examples/contracts rather than querying those environment variables or real accounts. There are intentionally **no live AWS PR plans**.

## 4. Self-hosted SonarQube

Prepare the Sonar server separately:

1. Create a project and connect its GitHub integration if you want PR decoration.
2. Configure a meaningful quality gate (new-code bugs/vulnerabilities, reviewed security hotspots, coverage). Waiting for a permissive gate is not equivalent to a secure gate.
3. Use a version/edition supporting your Python, Terraform and branch/PR analyses; the intended self-hosted setup is Developer edition or higher. Community-only main-branch analysis cannot silently satisfy this pipeline's multi-branch/PR requirement.
4. Expose a reachable **HTTPS** URL. Do not disable certificate verification. `SONAR_ROOT_CERT` can provide your organization's trusted root certificate if needed.
5. Configure repository variables `SONAR_HOST_URL`, `SONAR_PROJECT_KEY`, and secret `SONAR_TOKEN` using the GitHub UI/secret store. Use a project-scoped analysis token. Never paste it into Terraform, README examples or chat.
6. Optional repository variable `SONAR_RUNNER_LABELS_JSON`: e.g. `["self-hosted","linux","x64","sonar"]` if the server is reachable only from a dedicated runner. Otherwise it defaults to `["ubuntu-24.04"]`.

A private-network Sonar runner must be **isolated and preferably ephemeral**: no production instance profile, Docker socket from live hosts, long-lived AWS credentials or access to application secrets. Do not run untrusted code on a privileged persistent runner. Network access to Sonar is not a reason to run CI on the production ECS/DB network with administrator privileges.

The scan waits for the gate for up to 600 seconds. Missing configuration, unreachable server, unsupported branch analysis or a failed gate blocks deployment; no `continue-on-error` or fake success fallback is present.

### Fork and Dependabot PRs

GitHub correctly withholds secrets from fork PRs and many Dependabot contexts. Fork PRs run the AWS-free unit/Terraform/Checkov/Trivy jobs; Sonar is not run with a secret or a private runner, and the aggregate gate fails explicitly. A maintainer must review the code and reproduce it in a trusted same-repository PR for the full gate. Do **not** switch to `pull_request_target`, download/execute an untrusted PR artifact with secrets, or bypass the required gate. For Dependabot, adopt reviewed updates on a trusted branch or use a separately approved token policy.

## Troubleshooting

- **No PR checks run:** confirm you moved and committed the root `infrastructure.yml` into `.github/workflows/infrastructure.yml`. The root template is intentionally inert; branch protection must not be bypassed just because checks have not run.
- **AccessDenied on AssumeRoleWithWebIdentity:** check audience and exact subject, branch, environment, repository case/workflow path, custom-template opt-in and immutable-ID settings. Do not weaken trust.
- **No deployment after a successful PR:** expected; only a push to `dev`/`prod` deploys. Verify environment approvals and branch restrictions.
- **Wrong account:** fix the environment variables/SSO profile. Do not change `allowed_account_ids` to `[]`.
- **Plan wants to delete protected data:** the guard rejects it even if Terraform lifecycle protections were removed. Escalate to a reviewed maintenance/decommission procedure, not an unreviewed skip switch.
- **First apply failed partway:** Terraform retains completed resources in remote state. Fix the root cause and rerun the original push workflow or submit a corrected push; do not delete state or repeatedly run simultaneous applies.
- **Expired AWS session during a long create:** inspect actual AWS status/state, wait for the service operation, then rerun a reviewed push. Never run a second create blindly.
- **Dependency/scan updates:** update pins together, regenerate provider locks, review scanner exceptions and use the full gate. Do not globally ignore vulnerabilities to get a green pipeline.
