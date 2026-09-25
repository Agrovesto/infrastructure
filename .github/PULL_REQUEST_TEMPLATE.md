<!--
================================================================================
 PULL REQUEST TEMPLATE — Agrovesto/infrastructure

 This template is deliberately infrastructure-shaped rather than generic. The
 two questions that cause the most damage in a Terraform repository are not
 "what does this do" but:

   1. does it REPLACE something (ForceNew), and
   2. does it cost money every month from now on.

 Both are answered by the plan, which CI posts to this PR automatically. Please
 read that plan before requesting review — a reviewer who has to find a
 replacement in the diff is a reviewer who will miss it.

 Delete these comments and any section that does not apply. Leave the headings
 that do.
================================================================================
-->

## What changes

<!-- One or two sentences: what is different after this merges, in terms of the
     running system rather than the files edited. -->

## Which stacks does this touch

<!-- Tick every box that applies. This decides what CI runs and what gets
     applied, and it is the fastest way for a reviewer to know how careful to be.
     - dev/         -> applies on merge to `dev`        (disposable, scheduled EC2)
     - prod/        -> applies on merge to `main`       (live traffic path)
     - monitoring/  -> applies on merge to `main`       (prod account, non-critical)
     - bootstrap/   -> NEVER auto-applies               (one-time account setup)
-->

- [ ] `dev/`
- [ ] `prod/`
- [ ] `monitoring/`
- [ ] `bootstrap/` (manual — say so in the rollout notes below)
- [ ] docs, scripts or CI only (no infrastructure changes)

## Does this replace or destroy anything?

<!-- The single most important question in this repository. Several resources
     here were ADOPTED from a pre-existing account (see docs/import-runbook.md),
     so a ForceNew attribute change does not give you a tidy plan to skim — it
     gives you the replacement of a live VPC subnet, RDS instance, EBS volume or
     security group.

     Known ForceNew traps in this repo: vpc_cidr, subnet CIDRs, RDS identifier /
     engine / storage type, EBS volume size and AZ, ECR name, ACM domain, KMS key
     policy, and EC2 user_data (which replaces the instance and its root volume).

     If CI's plan shows `must be replaced` or `-/+` anywhere, name it here and
     say what happens to the data.
-->

- [ ] No — the plan shows in-place updates or additions only
- [ ] Yes — replacement/destroy is expected. Details and data impact:

> <!-- e.g. "aws_instance.app is replaced because user_data changed. The MSSQL,
>      logging and SonarQube volumes are not delete_on_termination, so the data
>      survives; expect ~5 minutes of downtime on the dev host while it reboots
>      and re-syncs its config from S3." -->

## Cost impact

<!-- From the Infracost comment CI posts below. Monthly delta, and whether it is
     a one-off or recurring. If it is more than about $5/month, say what the
     money buys. -->

- Monthly delta: **$<!-- +0.00 -->**
- [ ] No cost change
- [ ] Recurring change — justification:

## Rollout

<!-- Anything a human has to do that Terraform will not do for them. Examples
     from this repository: adding a DNS record in the prod zone for a dev
     hostname, confirming an SNS email subscription, setting a repository secret
     (SONAR_TOKEN, INFRACOST_API_KEY), running `vault operator init`, pushing an
     image to ECR, or waiting for an ACM certificate to validate.

     If there is an ordering dependency between stacks (monitoring before prod,
     bootstrap before anything), state it.
-->

- [ ] Nothing beyond merging
- [ ] Manual steps required:

> 1.
> 2.

## Verification

<!-- How do we know it worked after apply? Be specific: an output to read, a URL
     to open, a command to run, a dashboard to look at, a log to tail.

     For dev, remember the host is stopped 20:00-08:00 Mon-Fri (Africa/Lagos) by
     the scheduler, so "check the URL" may need the instance started first.
-->

- [ ] `terraform plan` in CI is clean and matches what I described above
- [ ] I have read the plan and checked for replacements
- [ ] How to verify after apply:

> <!-- e.g. "`terraform -chdir=dev output sonarqube_access`, then tunnel and load
>      http://localhost:9000. First boot takes 2-5 minutes and the container
>      restarts a few times until init-dbs.sql has created the sonar database." -->

## Checkov / Trivy / SonarQube suppressions

<!-- If this PR adds or changes a suppression in checkov.yml, .trivyignore.yaml,
     or adds a `#checkov:skip=` / `#trivy:ignore:` / NOSONAR comment, justify it
     here. A suppression is a decision to accept a finding, and it should be as
     visible as the finding would have been. -->

- [ ] No suppressions added or changed
- [ ] Suppression added — justification:

## Tests

<!-- `terraform test` runs with a mock provider and there is a resource-coverage
     gate per stack (dev 60%, prod 70%, monitoring 95%). New resources need
     references in tests/ or the coverage number drops. -->

- [ ] New or changed resources are covered in `<stack>/tests/`
- [ ] Coverage is unchanged or better (`python3 scripts/tf_coverage.py <stack>`)
- [ ] No test changes needed

---

<!--
 The following are added by CI and do not need to be filled in by hand:
   * Checkov & Trivy findings
   * terraform test + resource coverage
   * SonarQube quality gate
   * Infracost monthly estimate and delta
   * terraform fmt / validate / plan output (and the diff against the base branch)
-->
