# Team, ownership and review

**Status: placeholder.** The team structure below is real (these are the GitHub
teams that exist in the `Agrovesto` organisation today); the *people*, the rota
and the escalation path are not filled in yet. Anything marked `TODO` needs a
human decision before this document is worth trusting in an incident.

This file exists so that `.github/CODEOWNERS` and `.github/PULL_REQUEST_TEMPLATE.md`
have something to point at: CODEOWNERS says *who is asked to review*, this says
*what they are expected to look for and what happens when nobody answers*.

---

## GitHub teams

These are the teams referenced by `.github/CODEOWNERS`. All are `closed` privacy
in the org, so membership is visible to members only.

| Team | Scope of this repository | Members |
| :--- | :--- | :--- |
| `@Agrovesto/infrastructure` | Default owner of everything here; sole owner of `dev/`, `monitoring/`, `docs/`, `scripts/` | TODO: confirm |
| `@Agrovesto/team-leads` | Co-owner of `prod/`, `bootstrap/`, all IAM, CI/CD, and the scan-suppression / cost-gate configuration | TODO: confirm |
| `@Agrovesto/backend` | Not an owner yet. Candidate owner of the application contract in `prod/ecs.tf` and `dev/docker-compose.yml.tftpl` (ports, env vars, `OTEL_*`, image tags) — see the commented block at the bottom of CODEOWNERS | TODO: decide |
| `@Agrovesto/frontend` | Not an owner yet. Candidate owner of `dev/amplify.tf` | TODO: decide |
| `@Agrovesto/mobile` | No surface in this repository | — |

> ### ⚠️ None of these teams can currently review this repository
>
> **Verified 2026-09-24:** every team above returns `404 Not Found` for
> `GET /orgs/Agrovesto/teams/<team>/repos/Agrovesto/infrastructure`, meaning none
> of them is associated with this repository at all. For a team to be an
> effective code owner it needs **write** access here. Until that is granted:
>
> - GitHub renders these owners as unable to approve (greyed out in the review
>   request), so `.github/CODEOWNERS` requests reviews from people who cannot
>   give them.
> - Access is currently held by **individual collaborators only**, which is the
>   thing teams are meant to replace — it does not survive someone leaving.
> - **Do not enable "Require review from Code Owners" in branch protection yet.**
>   With the permissions missing, that combination makes the repository
>   unmergeable: the required reviewer would be a team that cannot approve.
>
> To fix (needs org-owner rights):
>
> ```bash
> for t in infrastructure team-leads; do
>   gh api -X PUT "/orgs/Agrovesto/teams/$t/repos/Agrovesto/infrastructure" \
>     -f permission=push
> done
> ```
>
> Add `backend` and `frontend` at the same time if their rules at the bottom of
> CODEOWNERS are uncommented. **TODO: decide who grants this, and when.**

---

## Who owns what

| Area | Path | Owner | Applies when |
| :--- | :--- | :--- | :--- |
| Dev environment (EC2 + compose) | `dev/` | infrastructure | merge to `dev` |
| Production (ECS, RDS, ALB, DNS) | `prod/` | infrastructure + team-leads | merge to `main` |
| Observability stack | `monitoring/` | infrastructure | merge to `main` |
| Account bootstrap | `bootstrap/` | infrastructure + team-leads | **never automatic** |
| IAM and CI credentials | `**/iam.tf`, `.github/workflows/` | infrastructure + team-leads | merge |
| Cost and scan policy | `infracost*.yml`, `**/checkov.yml`, `**/.trivyignore.yaml` | infrastructure + team-leads | merge |

Two of these deserve a word:

- **`prod/` holds adopted resources.** Several were imported from a
  pre-existing account (see [`import-runbook.md`](./import-runbook.md)). For
  those, an attribute marked *ForceNew* does not produce a diff to review — it
  produces the replacement of a live resource. This is why the PR template asks
  the question outright instead of leaving it to the plan.
- **`bootstrap/` never auto-applies.** It creates the state bucket and the OIDC
  role the rest of the pipelines depend on, so a bad change there does not break
  a stack, it breaks the ability to change any stack.

---

## Review expectations

CODEOWNERS only *requests* review. Enforcement lives in branch protection
(Settings → Branches) on `main`, `dev` and `devops`:

- [ ] Require a pull request before merging — **TODO: decide**
- [ ] Require review from Code Owners — **TODO: decide**
- [ ] Require status checks to pass (`Checkov & Trivy`, `Test & coverage`,
      `SonarQube`, `Infracost`, `fmt / validate / plan`) — **TODO: decide**

With two people on the infrastructure team, a hard code-owner gate on every path
means the team blocks itself whenever one person is away. The pragmatic setting
is: gate `prod/`, `bootstrap/`, IAM and CI, and leave `dev/`, `monitoring/` and
`docs/` to review-by-convention. **TODO: confirm that is the intent.**

Regardless of what is enforced, a reviewer of an infrastructure PR is expected
to look at, in this order:

1. **Replacements.** Search the CI-posted plan for `must be replaced` and `-/+`.
   If one is there and the PR description does not explain it, that is the
   review.
2. **Data.** Anything touching an EBS volume, RDS instance, EFS filesystem or S3
   bucket: what happens to the contents? In this repo the MSSQL, logging and
   SonarQube volumes are deliberately *not* `delete_on_termination`, which is
   what makes an instance replacement survivable. A change to that is a change
   to the backup story.
3. **Network exposure.** New ingress, a new public port, a widened CIDR, an
   `allowed_cidrs` going from `[]` to `0.0.0.0/0`. Note that an empty allow list
   in this repo means *loopback only*, not *everyone* — that convention is load
   bearing for the Grafana and SonarQube vhosts.
4. **Secrets.** Nothing secret may be rendered into an S3 object, into instance
   `user_data`, or into a committed `.tfvars`. The pattern here is SSM
   SecureString → fetched at boot → written into a file with mode 600. This
   repository is public.
5. **Cost.** The Infracost delta. Recurring cost is the one that is still being
   paid in six months by someone who has forgotten this PR.

---

## On-call and escalation

**TODO — this section is entirely unwritten.** The infrastructure exists to
answer these questions and currently has no human attached to them:

- Who is paged when a `critical` alert fires? Alerts today route to
  Alertmanager → SNS → the subscribers of `agrovesto-prod-alerts`
  (`tech@agrovesto.com`), plus CloudWatch alarms to `alert_emails`. An email
  address is not a rota.
- What is the escalation path if the first responder does not answer?
- Which runbooks exist? Today: [`import-runbook.md`](./import-runbook.md) and the
  operational notes in the root [`README.md`](../README.md). There is no runbook
  for an RDS failover, a full disk on the dev host, or a broken monitoring stack.
- Is the dev host's 08:00–20:00 Mon–Fri schedule (Africa/Lagos) known to whoever
  is paged at 21:00? A stopped dev instance is expected, not an incident.

---

## Service ownership (application side)

The five services — `wallet`, `onboarding`, `input`, `moneval`,
`serviceprovider` — are defined identically in dev and prod, and in both
environments the service name is also the database name and the `OTEL_SERVICE_NAME`.
That convention is what makes a trace, a log line and a database row joinable
without a mapping table.

| Service | Application repo | Team | Notes |
| :--- | :--- | :--- | :--- |
| `wallet` | TODO | TODO | |
| `onboarding` | `Agrovesto/onboarding-frontend` (frontend only) | TODO | backend repo TODO |
| `input` | TODO | TODO | |
| `moneval` | TODO | TODO | |
| `serviceprovider` | TODO | TODO | |

> The container images in both `dev/terraform.auto.tfvars` and
> `prod/terraform.auto.tfvars` are still placeholders
> (`public.ecr.aws/nginx/nginx:alpine` and `ealen/echo-server:latest`). Until the
> real images land, anything that depends on application behaviour — including
> OpenTelemetry export, which needs an SDK inside the image — is wired but
> inert.
