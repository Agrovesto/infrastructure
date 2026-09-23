#!/usr/bin/env python3
"""
import-from-inventory.py - turn an AWS Resource Explorer inventory report into
per-stack Terraform import packages.

    ./scripts/import-from-inventory.py --report /path/to/inventory.md
    ./scripts/import-from-inventory.py --arns dev=dev-arns.txt --arns prod=prod-arns.txt

Input is either the markdown report (any table whose rows contain `arn:aws:...`,
as produced by a Resource Explorer 2 search) or a plain one-ARN-per-line file per
environment. The environment of each row comes from the account id in the ARN,
mapped through the repo's own backend blocks - so dev-account resources are
written to dev/ and prod-account resources to prod/, and nothing is hard coded
here.

Every ARN lands in exactly one bucket:

    A  import now        standalone resource, nothing in the stack claims it
    B  check first       one describe call decides the address / ownership
    C  network           VPC & friends - can force replacement of live network
    D  decision needed   exists, but whether Terraform should own it is a policy
                         call, or it collides with what the stack creates
    X  excluded          AWS-owned default, another tool owns it (CDK/CFN),
                         derived from a parent, a backup artifact, ephemeral,
                         no Terraform resource models it, or already in state

Output, per environment:

    <env>/discovery/imports/imports-<env>.tf.txt   paste-ready import blocks
    <env>/discovery/TRIAGE.md                      the classification + runbook
    <env>/discovery/inventory-<date>.csv           every row with its bucket

Only section A of the import file is uncommented. B, C and D are written as
comments carrying the exact command that settles each one, because guessing
there is how a live VPC gets replaced.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import os
import re
import sys
from collections import Counter, defaultdict

# ---------------------------------------------------------------------------
# ARN parsing
# ---------------------------------------------------------------------------

ARN_RE = re.compile(r"^arn:aws(?:-cn|-us-gov)?:([a-z0-9-]+):([^:]*):([^:]*):(.*)$")


class Res:
    """One inventoried resource."""

    def __init__(self, env: str, arn: str):
        m = ARN_RE.match(arn)
        if not m:
            raise SystemExit("not an ARN: %r" % arn)
        self.env = env
        self.arn = arn
        self.svc, self.region, self.account, self.res = m.groups()
        self.region = self.region or "global"
        self.kind, self.ident = self._split(self.svc, self.res)
        self.bucket = "X-unclassified"
        self.tf_type = ""
        self.import_id = ""
        self.address = ""
        self.reason = ""
        self.check = ""

    @staticmethod
    def _split(svc: str, res: str):
        if svc == "s3":
            return "bucket", res
        if svc == "sns":
            return "topic", res
        if svc == "codepipeline":
            if res.startswith("webhook:"):
                return "webhook", res.split(":", 1)[1]
            return "pipeline", res
        # The kind token never contains "/" or ":", so split at whichever
        # separator comes first: "log-group:/nomaos/prod/api" is kind
        # "log-group" + name "/nomaos/prod/api", not kind "log-group:".
        cuts = [i for i in (res.find("/"), res.find(":")) if i != -1]
        if not cuts:
            return res, res
        i = min(cuts)
        return res[:i], res[i + 1:]

    @property
    def is_latest_version(self) -> bool:
        return self.svc == "lambda" and self.ident.endswith(":$LATEST")

    def base_name(self) -> str:
        """Function/secret name without the version or the 6-char random suffix."""
        if self.svc == "lambda":
            return self.ident.split(":")[0]
        if self.svc == "secretsmanager":
            return re.sub(r"-[A-Za-z0-9]{6}$", "", self.ident)
        return self.ident

    def app_id(self) -> str:
        """Amplify ARNs are apps/<id>[/branches/<b>|/domains/<d>]."""
        return self.ident.split("/")[0]

    def amplify_sub(self) -> str:
        parts = self.ident.split("/")
        return parts[1] if len(parts) > 1 else ""

    def letter(self) -> str:
        return self.bucket[0]


def sh(s) -> str:
    """Shell-quote for the runbook commands."""
    return "'" + str(s).replace("'", "'\\''") + "'"


def snake(s: str) -> str:
    s = re.sub(r"[^A-Za-z0-9]+", "_", s).strip("_").lower()
    return re.sub(r"_+", "_", s) or "unnamed"


def wrap(text: str, width: int):
    words, out, cur = text.split(), [], ""
    for word in words:
        if len(cur) + len(word) + 1 > width and cur:
            out.append(cur)
            cur = word
        else:
            cur = (cur + " " + word).strip()
    if cur:
        out.append(cur)
    return out or [""]


# ---------------------------------------------------------------------------
# What owns what, learned from the names in the inventory
# ---------------------------------------------------------------------------

# CDK/CloudFormation owns a large part of both accounts. Anything matching these
# is excluded: importing it puts two IaC tools in charge of one resource, and the
# next `cdk deploy` or `terraform apply` undoes the other's work.
CDK_STACK_NAMES = re.compile(
    r"^(CDKToolkit|agrovesto-infra-deployment|agrovesto-infra-pipeline|Infra-ECS-Cluster-)", re.I)
CDK_LAMBDA = re.compile(
    r"(RotationSingleUser|CustomVpcRestrictDefault|CustomS3AutoDelete|CustomCDKBucketDeploymen|"
    r"TableManagerCustomProvid|amplify-reactvitetailwind)", re.I)
CDK_SECRET = re.compile(r"^(agxdb2?|nomaosdb)credentials", re.I)
CDK_SUBNET_GROUP = re.compile(r"^(agxdb2?subnetgroup|nomaosdbsubnetgroup)$", re.I)
CDK_BUCKET = re.compile(r"^cdk-hnb659fds-", re.I)
CDK_REPO = re.compile(r"^cdk-hnb659fds-container-assets-", re.I)
CDK_SSM_PARAM = re.compile(r"^/?cdk-bootstrap/", re.I)
CDK_PIPELINE = re.compile(r"^agrovesto-Prod(Pipeline|Webhook|CodeBuildProject)$", re.I)

# Log groups a service creates for itself.
SERVICE_LOG_GROUP = re.compile(r"^(/aws/|RDSOSMetrics$|dms-serverless-replication-)")

# AWS-owned defaults: shared, immutable, not yours to import.
AWS_DEFAULTS = {
    ("memorydb", "acl"): {"open-access"},
    ("memorydb", "user"): {"default"},
    ("elasticache", "user"): {"default"},
    ("athena", "datacatalog"): {"AwsDataCatalog"},
    ("athena", "workgroup"): {"primary"},
    ("xray", "sampling-rule"): {"Default"},
    ("events", "event-bus"): {"default"},
}
AWS_DEFAULT_PREFIXES = {
    ("memorydb", "parametergroup"): "default.",
    ("rds", "og"): "default:",
    ("rds", "pg"): "default.",
    ("apprunner", "autoscalingconfiguration"): "DefaultConfiguration",
}

# Terraform type + import-ID builder, for everything importable.
TF = {
    ("ec2", "instance"): ("aws_instance", lambda r: r.ident),
    ("ec2", "volume"): ("aws_ebs_volume", lambda r: r.ident),
    ("ec2", "elastic-ip"): ("aws_eip", lambda r: r.ident),
    ("ec2", "launch-template"): ("aws_launch_template", lambda r: r.ident),
    ("ec2", "image"): ("aws_ami", lambda r: r.ident),
    ("ec2", "key-pair"): ("aws_key_pair", None),   # imports by NAME, not by key-xxxx
    ("ec2", "security-group"): ("aws_security_group", lambda r: r.ident),
    ("ec2", "vpc"): ("aws_vpc", lambda r: r.ident),
    ("ec2", "subnet"): ("aws_subnet", lambda r: r.ident),
    ("ec2", "route-table"): ("aws_route_table", lambda r: r.ident),
    ("ec2", "internet-gateway"): ("aws_internet_gateway", lambda r: r.ident),
    ("ec2", "network-acl"): ("aws_network_acl", lambda r: r.ident),
    ("ec2", "dhcp-options"): ("aws_vpc_dhcp_options", lambda r: r.ident),
    ("s3", "bucket"): ("aws_s3_bucket", lambda r: r.ident),
    ("ecr", "repository"): ("aws_ecr_repository", lambda r: r.ident),
    ("ecs", "cluster"): ("aws_ecs_cluster", lambda r: r.ident),
    ("logs", "log-group"): ("aws_cloudwatch_log_group", lambda r: r.ident),
    ("kms", "key"): ("aws_kms_key", lambda r: r.ident),
    ("lambda", "function"): ("aws_lambda_function", lambda r: r.base_name()),
    ("rds", "db"): ("aws_db_instance", lambda r: r.ident),
    ("rds", "subgrp"): ("aws_db_subnet_group", lambda r: r.ident),
    ("secretsmanager", "secret"): ("aws_secretsmanager_secret", lambda r: r.arn),
    ("ssm", "parameter"): ("aws_ssm_parameter", None),   # leading slash is ambiguous in an ARN
    ("ssm", "association"): ("aws_ssm_association", lambda r: r.ident),
    ("acm", "certificate"): ("aws_acm_certificate", lambda r: r.arn),
    ("sns", "topic"): ("aws_sns_topic", lambda r: r.arn),
    ("ses", "identity"): ("aws_ses_domain_identity", lambda r: r.ident),
    ("ses", "configuration-set"): ("aws_ses_configuration_set", lambda r: r.ident),
    ("dms", "endpoint"): ("aws_dms_endpoint", lambda r: r.ident),
    ("dms", "subgrp"): ("aws_dms_replication_subnet_group", lambda r: r.ident),
    ("codepipeline", "pipeline"): ("aws_codepipeline", lambda r: r.ident),
    ("codepipeline", "webhook"): ("aws_codepipeline_webhook", lambda r: r.ident),
    ("codebuild", "project"): ("aws_codebuild_project", lambda r: r.ident),
    ("codeconnections", "connection"): ("aws_codeconnections_connection", lambda r: r.arn),
    ("codestar-connections", "connection"): ("aws_codestarconnections_connection", lambda r: r.arn),
    ("events", "rule"): ("aws_cloudwatch_event_rule", lambda r: r.ident),
}

# Where a resource maps 1:1 onto an address the stack already defines, use that
# address: adopting what exists is the whole point of importing.
KNOWN_ADDRESSES = {
    ("ec2", "vpc"): "aws_vpc.main",
    ("ec2", "internet-gateway"): "aws_internet_gateway.main",
}

ALL_ARNS: dict = defaultdict(list)


# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

def classify(r: Res, tfstate_buckets: set) -> None:
    svc, kind, ident = r.svc, r.kind, r.ident

    def put(bucket, reason, check="", tf_type="", import_id="", address=""):
        r.bucket, r.reason, r.check = bucket, reason, check
        r.tf_type = tf_type
        r.import_id = import_id
        r.address = address or (address_for(r, tf_type) if tf_type else "")

    def exclude(bucket, reason):
        put(bucket, reason)

    def adopt(bucket, reason, check="", tf_type=None, import_id=None, address=""):
        spec = TF.get((svc, kind))
        if spec is None and tf_type is None:
            return exclude("X-no-tf-resource",
                           "%s - and no Terraform resource models %s:%s" % (reason, svc, kind))
        tf_type = tf_type or spec[0]
        if import_id is None:
            build = spec[1] if spec else None
            import_id = build(r) if build else ""
        put(bucket, reason, check, tf_type, import_id, address)

    # --- pseudo-resources and children ------------------------------------
    if r.is_latest_version:
        return exclude("X-derived",
                       "the $LATEST pseudo-version of a function; the function itself is the resource")
    if svc == "ec2" and kind == "network-interface":
        return exclude("X-derived", "ENI - created and owned by whatever it is attached to")
    if svc == "ec2" and kind == "security-group-rule":
        return exclude("X-derived",
                       "one rule of a security group; Terraform models rules inside the group, so the "
                       "group is the thing to import")
    if svc == "ssm" and kind == "managed-instance":
        return exclude("X-derived",
                       "the SSM registration of EC2 instance %s - import the instance, not this" % ident)
    if svc == "ssm" and kind == "session":
        return exclude("X-ephemeral", "a Session Manager session - gone within minutes")
    if svc == "rds" and kind in ("snapshot", "auto-backup"):
        return exclude("X-backup", "RDS %s - a backup artifact, not infrastructure" % kind)
    if svc == "ec2" and kind == "snapshot":
        return exclude("X-backup", "EBS snapshot - a backup artifact, not infrastructure")

    # --- AWS-owned defaults ------------------------------------------------
    if ident in AWS_DEFAULTS.get((svc, kind), set()):
        return exclude("X-aws-default", "AWS-owned default %s %r - shared and immutable" % (kind, ident))
    pref = AWS_DEFAULT_PREFIXES.get((svc, kind))
    if pref and ident.startswith(pref):
        return exclude("X-aws-default", "AWS-provided default %s %r" % (kind, ident))
    if svc == "events" and ident.startswith("AWSUserNotificationsManagedRule"):
        return exclude("X-aws-managed", "AWS-managed EventBridge rule")
    if svc == "secretsmanager" and ident.startswith("rds!db-"):
        return exclude("X-aws-managed",
                       "RDS-managed master-password secret - created and rotated by RDS itself")
    if svc == "resource-explorer-2":
        return exclude("X-tooling", "Resource Explorer's own %s - the tool that produced this inventory" % kind)
    if svc == "apprunner" and kind == "connection":
        return exclude("X-no-tf-resource",
                       "App Runner source connection - the provider has no resource for it")
    if svc == "dms" and kind == "subgrp" and ident.startswith("default-vpc-"):
        return exclude("X-derived", "the replication subnet group DMS creates automatically per VPC")

    # --- already in Terraform (bootstrap/) ---------------------------------
    if svc == "s3" and ident in tfstate_buckets:
        return exclude("X-already-managed",
                       "created by bootstrap/ - the Terraform state bucket stack already owns it")

    # --- CDK / CloudFormation ---------------------------------------------
    if svc == "cloudformation":
        return exclude("X-cdk", "CloudFormation stack %r - owned by whatever deployed it (CDK here)" % ident)
    if svc == "lambda" and CDK_LAMBDA.search(r.base_name()):
        return exclude("X-cdk", "CDK construct lambda (%s) - rewritten on every cdk deploy" % r.base_name())
    if svc == "secretsmanager" and CDK_SECRET.match(r.base_name()):
        return exclude("X-cdk", "CDK DatabaseSecret belonging to the CDK-managed RDS instance")
    if svc == "rds" and kind == "subgrp" and CDK_SUBNET_GROUP.match(ident):
        return exclude("X-cdk", "subnet group of a CDK-managed RDS instance")
    if svc == "s3" and CDK_BUCKET.match(ident):
        return exclude("X-cdk", "CDK bootstrap asset bucket")
    if svc == "s3" and re.match(r"^(codepipeline-|cf-templates-|dms-serverless-|aws-cloudtrail-)", ident):
        owner = next((who for pref, who in (("codepipeline-", "CodePipeline"),
                                            ("cf-templates-", "CloudFormation"),
                                            ("dms-serverless-", "DMS Serverless"),
                                            ("aws-cloudtrail-", "CloudTrail"))
                      if ident.startswith(pref)), "the service")
        return adopt("D-decision",
                     "created by %s for its own artifacts. Import only if the thing that uses it moves into "
                     "Terraform too - otherwise Terraform owns a bucket it did not design and cannot safely "
                     "change" % owner,
                     "aws s3api get-bucket-versioning --bucket %s; aws s3api get-bucket-encryption --bucket %s"
                     % (sh(ident), sh(ident)))
    if svc == "s3" and ident == "agrovesto-pipeline-artifacts":
        return adopt("D-decision",
                     "artifact store of a hand-built CodePipeline. Import it together with the pipeline (see "
                     "the pipeline block below) or not at all: a bucket without its pipeline policy is a "
                     "half-managed resource",
                     "aws s3api get-bucket-policy --bucket %s" % sh(ident))
    if svc == "sns" and ident.startswith("amplify-"):
        return exclude("X-derived", "created by Amplify for app branch notifications")
    if svc == "ecr" and CDK_REPO.match(ident):
        return exclude("X-cdk", "CDK bootstrap container-asset repository")
    if svc == "ssm" and kind == "parameter" and CDK_SSM_PARAM.match(ident):
        return exclude("X-cdk", "CDK bootstrap version marker")
    if svc in ("codepipeline", "codebuild") and CDK_PIPELINE.match(ident):
        return exclude("X-cdk", "created by the CDK pipeline stack agrovesto-infra-pipeline")
    if svc == "ecs" and kind == "cluster" and any(
            ("Infra-ECS-Cluster-%s" % ident) in a for a in ALL_ARNS.get(r.env, [])):
        return exclude("X-cdk", "ECS cluster created by the CloudFormation stack Infra-ECS-Cluster-%s" % ident)
    if svc == "logs" and kind == "log-group" and (CDK_LAMBDA.search(ident) or "amplify-reactvitetailwind" in ident):
        return exclude("X-cdk", "log group of a CDK custom-resource lambda")

    # --- service-created log groups ---------------------------------------
    if svc == "logs" and kind == "log-group" and SERVICE_LOG_GROUP.match(ident):
        return adopt("D-log-group",
                     "created automatically by the service that writes to it; import only to pin "
                     "retention_in_days (unbounded retention is the usual surprise on the bill)",
                     "aws logs describe-log-groups --log-group-name-prefix %s "
                     "--query 'logGroups[].{name:logGroupName,retention:retentionInDays}'" % sh(ident))

    # --- rules another service made ---------------------------------------
    if svc == "events" and kind == "rule" and ident.startswith("amplify-"):
        return exclude("X-derived", "created by Amplify for branch notifications")

    # --- needs one command before it can be addressed ---------------------
    if svc == "ec2" and kind == "security-group":
        return adopt("B-security-group",
                     "security group - the report carries no names, so its owner is unknown. If GroupName "
                     "turns out to be 'default', the address is aws_default_security_group.default (both "
                     "stacks define one); otherwise it needs a new address",
                     "aws ec2 describe-security-groups --group-ids %s "
                     "--query 'SecurityGroups[].{name:GroupName,desc:Description,vpc:VpcId,tags:Tags}'"
                     % sh(ident))
    if svc == "ec2" and kind == "key-pair":
        return adopt("B-key-pair",
                     "aws_key_pair imports by key pair NAME; the report only has the key-pair id",
                     "aws ec2 describe-key-pairs --key-pair-ids %s --query 'KeyPairs[].KeyName'" % sh(ident))
    if svc == "kms" and kind == "key":
        return adopt("B-kms-key",
                     "AWS service keys and customer-managed keys look identical in an ARN, and a service key "
                     "(alias/aws/...) cannot be imported at all",
                     "aws kms describe-key --key-id %s "
                     "--query 'KeyMetadata.{manager:KeyManager,desc:Description,created:CreationDate}'; "
                     "aws kms list-aliases --key-id %s --query 'Aliases[].AliasName'"
                     % (sh(ident), sh(ident)))
    if svc == "acm" and kind == "certificate":
        return adopt("B-acm-certificate",
                     "prod/acm.tf already defines aws_acm_certificate.wildcard for *.nomaos.com - if this is "
                     "that certificate it must go into THAT address, not a new one",
                     "aws acm list-certificates "
                     "--query 'CertificateSummaryList[?contains(CertificateArn, `%s`)]"
                     ".{domain:DomainName,sans:SubjectAlternativeNameSummaries,status:Status}'" % sh(ident))
    if svc == "amplify":
        return classify_amplify(r, adopt)
    if svc == "rds" and kind == "db":
        return adopt("B-rds-instance",
                     "the real database. prod/rds.tf wants identifier 'agrovesto-prod-mssql'; this instance is "
                     "'%s', so it imports under a NEW address and the two have to be reconciled (rename the "
                     "instance, or change the stack's identifier) before they can meet" % ident,
                     "aws rds describe-db-instances --db-instance-identifier %s "
                     "--query 'DBInstances[].{id:DBInstanceIdentifier,engine:Engine,ver:EngineVersion,"
                     "class:DBInstanceClass,storage:AllocatedStorage,az:AvailabilityZone,multi:MultiAZ,"
                     "subgrp:DBSubnetGroup.DBSubnetGroupName,vpc:DBSubnetGroup.VpcId}'" % sh(ident))
    if svc == "ssm" and kind == "parameter":
        return adopt("B-ssm-parameter",
                     "an ARN drops the parameter's leading slash, so the import id is either '/%s' or '%s' - "
                     "only get-parameter says which" % (ident, ident),
                     "aws ssm get-parameter --name %s --query 'Parameter.Name' || "
                     "aws ssm get-parameter --name %s --query 'Parameter.Name'"
                     % (sh("/" + ident), sh(ident)))
    if svc == "ses" and kind == "identity" and "@" in ident:
        return adopt("A-import-now",
                     "SES email identity - import so its verification state is in code",
                     "aws ses get-identity-verification-attributes --identities %s "
                     "--query 'VerificationAttributes.%s'" % (sh(ident), sh(ident)),
                     "aws_ses_email_identity", ident)
    if svc in ("codeconnections", "codestar-connections"):
        return adopt("B-code-connection",
                     "GitHub connection - the CDK pipeline stack creates one too, so check which tool made this",
                     "aws codeconnections get-connection --connection-arn %s "
                     "--query 'Connection.{name:ConnectionName,provider:ProviderType,status:ConnectionStatus}'"
                     % sh(r.arn))

    # --- base network: highest blast radius --------------------------------
    if svc == "ec2" and kind in ("vpc", "subnet", "route-table", "internet-gateway",
                                 "network-acl", "dhcp-options"):
        known = KNOWN_ADDRESSES.get((svc, kind), "")
        if known:
            where = ("Imported into %s, the address %s/ already defines, Terraform adopts the LIVE %s"
                     % (known, r.env, kind))
        elif kind in ("subnet", "route-table"):
            where = ("Live %s. %s/ creates its own %ss from var.*_subnet_cidrs, so importing this one means "
                     "either matching that variable to reality or accepting a second %s"
                     % (kind, r.env, kind.replace("-", " "), kind))
        else:
            where = ("Live %s, which %s/ does not define at all - importing it adds a new managed resource, "
                     "but a change here affects the whole VPC" % (kind, r.env))
        return adopt("C-network",
                     "base network. %s - and if cidr_block or the route entries differ from the config, the "
                     "plan REPLACES it, which takes the environment down" % where,
                     network_check(r),
                     address=known)

    # --- compute and images the stacks also want to create -----------------
    if svc == "ec2" and kind in ("instance", "volume", "elastic-ip"):
        return adopt("D-compute", compute_reason(r), compute_check(r))
    if svc == "ec2" and kind in ("image", "launch-template"):
        return adopt("D-machine-image",
                     "%s - a build artifact. Terraform can own it, but `terraform destroy` then deregisters "
                     "the image / deletes the template"
                     % ("private AMI" if kind == "image" else "launch template"),
                     ("aws ec2 describe-images --owners self --image-ids %s "
                      "--query 'Images[].{id:ImageId,name:Name,created:CreationDate}'" % sh(ident))
                     if kind == "image" else
                     ("aws ec2 describe-launch-templates --launch-template-ids %s "
                      "--query 'LaunchTemplates[].{id:LaunchTemplateId,name:LaunchTemplateName}'" % sh(ident)))

    # --- pipelines ---------------------------------------------------------
    if svc == "codepipeline":
        return adopt("D-pipeline",
                     "hand-built pipeline. Importing it means importing its artifact bucket and IAM role too, "
                     "or the next plan wants to replace them",
                     "aws codepipeline get-pipeline --name %s --query 'pipeline.{role:roleArn,store:artifactStore}'"
                     % sh(ident))

    # --- plain candidates --------------------------------------------------
    if (svc, kind) in TF:
        reason, bucket = candidate_reason(r)
        return adopt(bucket, reason, candidate_check(r))

    return exclude("X-no-tf-resource", "no Terraform resource models %s:%s" % (svc, kind))


def classify_amplify(r: Res, adopt) -> None:
    sub = r.amplify_sub()
    app = r.app_id()
    check = ("aws amplify get-app --app-id %s --query 'app.{name:name,repo:repository,platform:platform}'"
             % sh(app))
    note = ("a CDK app (amplify-reactvitetailwind) deployed some of the Amplify apps in this account, and "
            "the report has app ids but no app names, so ownership must be confirmed first")
    if not sub:
        return adopt("B-amplify", "Amplify app %s - %s" % (app, note),
                     "aws amplify list-apps --query 'apps[].{id:appId,name:name,platform:platform}'",
                     "aws_amplify_app", app)
    if sub == "branches":
        branch = r.ident.split("/")[-1]
        return adopt("B-amplify", "Amplify branch %r of app %s - %s" % (branch, app, note), check,
                     "aws_amplify_branch", "%s/%s" % (app, branch))
    if sub == "domains":
        domain = r.ident.split("/domains/", 1)[1]
        return adopt("B-amplify",
                     "Amplify custom domain %s on app %s - %s. Note dev/terraform.auto.tfvars sets "
                     "amplify_enable_custom_domain = false, so the dev stack manages these as Route 53 "
                     "CNAMEs instead; importing a domain association changes that decision" % (domain, app, note),
                     check, "aws_amplify_domain_association", "%s/%s" % (app, domain))
    return adopt("B-amplify", "Amplify %s" % r.ident, check, "aws_amplify_app", app)


def compute_reason(r: Res) -> str:
    if r.kind == "instance":
        return ("EC2 instance. dev/ec2.tf creates its own app host (t3.large, Ubuntu AMI, cloud-init "
                "user_data); adopting this box instead means matching ami, instance_type, user_data and tags "
                "exactly, because user_data is immutable - a mismatch destroys and rebuilds it")
    if r.kind == "volume":
        return ("EBS volume attached to an existing host. The stacks create their own (-mssql-data, "
                "-logging-data), so adopting this one means matching size, type, AZ and attachment")
    return ("Elastic IP. The stacks create their own (dev: aws_eip.app for the host, prod: aws_eip.nat for "
            "the NAT gateway) - adopting this one has to go into the right address or the plan allocates a "
            "second IP")


def compute_check(r: Res) -> str:
    if r.kind == "instance":
        return ("aws ec2 describe-instances --instance-ids %s "
                "--query 'Reservations[].Instances[].{id:InstanceId,ami:ImageId,type:InstanceType,"
                "state:State.Name,key:KeyName,name:Tags[?Key==`Name`]|[0].Value,vols:BlockDeviceMappings}'"
                % sh(r.ident))
    if r.kind == "volume":
        return ("aws ec2 describe-volumes --volume-ids %s "
                "--query 'Volumes[].{id:VolumeId,size:Size,type:VolumeType,az:AvailabilityZone,"
                "attached:Attachments[].InstanceId}'" % sh(r.ident))
    return ("aws ec2 describe-addresses --allocation-ids %s "
            "--query 'Addresses[].{alloc:AllocationId,ip:PublicIp,instance:InstanceId}'" % sh(r.ident))


def network_check(r: Res) -> str:
    cidr = {"dev": "10.20.0.0/16", "prod": "10.30.0.0/16"}.get(r.env, "<var.vpc_cidr>")
    kind = r.kind
    if kind == "vpc":
        return ("aws ec2 describe-vpcs --vpc-ids %s --query 'Vpcs[].{cidr:CidrBlock,dns:EnableDnsSupport,"
                "hostnames:EnableDnsHostnames,name:Tags[?Key==`Name`]|[0].Value}'   # CidrBlock MUST equal "
                "%s, or do not import into aws_vpc.main - change var.vpc_cidr to match reality first"
                % (sh(r.ident), cidr))
    if kind == "subnet":
        return ("aws ec2 describe-subnets --subnet-ids %s --query 'Subnets[].{cidr:CidrBlock,"
                "az:AvailabilityZone,vpc:VpcId,public:MapPublicIpOnLaunch,name:Tags[?Key==`Name`]|[0].Value}'"
                % sh(r.ident))
    if kind == "route-table":
        return ("aws ec2 describe-route-tables --route-table-ids %s --query 'RouteTables[].{routes:Routes,"
                "subnets:Associations[].SubnetId,name:Tags[?Key==`Name`]|[0].Value}'" % sh(r.ident))
    if kind == "internet-gateway":
        return "aws ec2 describe-internet-gateways --internet-gateway-ids %s --query 'InternetGateways[].Attachments'" % sh(r.ident)
    if kind == "network-acl":
        return "aws ec2 describe-network-acls --network-acl-ids %s --query 'NetworkAcls[].{entries:Entries,subnets:Associations[].SubnetId}'" % sh(r.ident)
    return ("aws ec2 describe-dhcp-options --dhcp-options-ids %s --query 'DhcpOptions[].DhcpConfigurations'"
            % sh(r.ident))


def candidate_reason(r: Res):
    svc, kind, ident = r.svc, r.kind, r.ident
    table = {
        ("s3", "bucket"): ("S3 bucket holding real data - import so versioning, encryption and the "
                           "public-access block live in code instead of the console", "A-import-now"),
        ("ecr", "repository"): ("ECR repository - import so the lifecycle policy and scan-on-push are in code",
                                "A-import-now"),
        ("logs", "log-group"): ("hand-made log group (not one a service created) - import to pin retention",
                                "A-import-now"),
        ("ssm", "association"): ("SSM State Manager association - import so its document and schedule are in code",
                                 "A-import-now"),
        ("ses", "identity"): ("SES domain identity - import so the verification and DKIM records are in code",
                              "A-import-now"),
        ("ses", "configuration-set"): ("SES configuration set - import so its event destinations are in code",
                                       "A-import-now"),
        ("sns", "topic"): ("SNS topic - import so its policy and subscriptions are in code", "A-import-now"),
        ("dms", "endpoint"): ("DMS endpoint - import so the migration source/target is in code. Note the DMS "
                              "serverless replications themselves are not in this index, so this is part of a "
                              "larger picture", "A-import-now"),
        ("events", "rule"): ("EventBridge rule - import so its schedule and targets are in code", "A-import-now"),
        ("lambda", "function"): ("Lambda function %r - named like a scratch test; deleting it may be a better "
                                 "answer than adopting it" % ident, "D-decision"),
    }
    if (svc, kind) in table:
        return table[(svc, kind)]
    return "%s %s - not claimed by anything in the repo" % (svc, ident), "A-import-now"


def candidate_check(r: Res) -> str:
    svc, kind, ident = r.svc, r.kind, r.ident
    if svc == "s3":
        return ("aws s3api get-bucket-versioning --bucket %s; aws s3api get-bucket-encryption --bucket %s; "
                "aws s3api get-public-access-block --bucket %s; aws s3api list-objects-v2 --bucket %s "
                "--max-items 1" % (sh(ident), sh(ident), sh(ident), sh(ident)))
    if svc == "logs":
        return ("aws logs describe-log-groups --log-group-name-prefix %s "
                "--query 'logGroups[].{name:logGroupName,retention:retentionInDays,tags:tags}'" % sh(ident))
    if svc == "ses":
        return "aws ses get-identity-verification-attributes --identities %s" % sh(ident)
    if svc == "lambda":
        return ("aws lambda get-function --function-name %s "
                "--query 'Configuration.{runtime:Runtime,handler:Handler,role:Role,lastmod:LastModified}'"
                % sh(ident))
    if svc == "dms":
        return ("aws dms describe-endpoints --filters Name=endpoint-id,Values=%s "
                "--query 'Endpoints[].{id:EndpointIdentifier,type:EndpointType,engine:EngineDbType}'" % sh(ident))
    if svc == "sns":
        return "aws sns get-topic-attributes --topic-arn %s" % sh(r.arn)
    if svc == "ecr":
        return ("aws ecr describe-repositories --repository-names %s "
                "--query 'repositories[].{scan:scanningConfiguration,mutability:imageTagMutability}'" % sh(ident))
    if svc == "events":
        return "aws events describe-rule --name %s" % sh(ident)
    if svc == "ssm":
        return "aws ssm list-associations --association-filter-list key=AssociationId,value=%s" % sh(ident)
    return ""


def address_for(r: Res, tf_type: str) -> str:
    if not tf_type:
        return ""
    known = KNOWN_ADDRESSES.get((r.svc, r.kind))
    if known and r.bucket == "C-network" and r.kind in ("vpc", "internet-gateway"):
        return known
    if r.svc == "amplify":
        parts = [p for p in r.ident.split("/") if p not in ("branches", "domains")]
        base = "_".join(parts)
    elif r.svc in ("lambda", "secretsmanager"):
        base = r.base_name()
    else:
        base = r.ident
    return "%s.%s" % (tf_type, snake(base))


# ---------------------------------------------------------------------------
# Repo facts
# ---------------------------------------------------------------------------

def load_repo(repo: str):
    """account id -> env (from the backend blocks), and the addresses each stack already uses."""
    env_of_account, existing = {}, defaultdict(set)
    for env in ("bootstrap", "dev", "prod", "monitoring"):
        d = os.path.join(repo, env)
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if not fn.endswith(".tf"):
                continue
            text = open(os.path.join(d, fn)).read()
            for m in re.finditer(r"nomaos-tfstate-(\d{12})-([a-z0-9-]+)", text):
                env_of_account.setdefault(m.group(1), "dev" if env == "dev" else
                                          ("prod" if env in ("prod", "monitoring", "bootstrap") else env))
            for m in re.finditer(r'^\s*(?:resource|data)\s+"([^"]+)"\s+"([^"]+)"', text, re.M):
                existing[env].add("%s.%s" % m.groups())
    # monitoring runs in the prod account but is its own folder: prefer an explicit mapping.
    return env_of_account, existing


def parse_report(path: str, env_of_account: dict):
    rows, skipped = [], []
    for line in open(path, encoding="utf-8", errors="replace"):
        if "arn:aws" not in line:
            continue
        for arn in re.findall(r"arn:aws[a-z-]*:[^\s`|\"')]+", line):
            arn = arn.rstrip(".,;")
            m = ARN_RE.match(arn)
            if not m:
                skipped.append(arn)
                continue
            acct = m.group(3)
            env = env_of_account.get(acct)
            if not env:
                skipped.append("%s (account %s is not mapped to an environment)" % (arn, acct or "global"))
                continue
            rows.append(Res(env, arn))
    return rows, skipped


def parse_arn_file(env: str, path: str):
    return [Res(env, line.strip()) for line in open(path) if line.strip().startswith("arn:")]


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

SECTIONS = [
    ("A", "A - import now",
     "Standalone resources nothing in the repo claims. Safe to paste: `terraform plan "
     "-generate-config-out=generated.tf` writes the config from the real resource, so the plan ends at "
     "0 to add, 0 to change."),
    ("B", "B - one command decides the address",
     "The report has ARNs but no names, and the correct Terraform address for these depends on a name, a "
     "domain or an owner. Run the command in the comment; it prints the missing piece. Then uncomment the "
     "block and fix its `to` address."),
    ("C", "C - base network: read the warning before touching this",
     "VPC, subnets, route tables, internet gateway, NACL, DHCP options. Importing these adopts the LIVE "
     "network. If the config's cidr_block or route entries differ from reality, Terraform plans a "
     "REPLACEMENT and the environment goes down. Confirm every CIDR first - or let Terraform build a new "
     "VPC and move workloads into it deliberately."),
    ("D", "D - a decision, not a discovery",
     "These exist, but whether Terraform should own them is a policy call: scratch resources, build "
     "artifacts, service-created log groups you may want retention on, and compute the stack wants to "
     "create fresh."),
]

SUB_LABEL = {
    "X-cdk": "owned by CDK / CloudFormation",
    "X-aws-default": "AWS-owned default",
    "X-aws-managed": "AWS-managed by another service",
    "X-derived": "derived from a parent resource",
    "X-backup": "backup artifact",
    "X-ephemeral": "ephemeral",
    "X-tooling": "the inventory tool itself",
    "X-no-tf-resource": "no Terraform resource for it",
    "X-already-managed": "already in Terraform (bootstrap/)",
    "B-security-group": "security groups (need names)",
    "B-key-pair": "key pairs (import by name)",
    "B-kms-key": "KMS keys (service vs customer)",
    "B-acm-certificate": "ACM certificates (which domain?)",
    "B-amplify": "Amplify apps/branches/domains",
    "B-rds-instance": "RDS instances",
    "B-ssm-parameter": "SSM parameters (leading slash?)",
    "B-code-connection": "code connections",
    "C-network": "base network",
    "D-compute": "EC2 compute the stack also creates",
    "D-machine-image": "AMIs and launch templates",
    "D-log-group": "service-created log groups",
    "D-pipeline": "hand-built pipelines",
    "D-decision": "other decisions",
}


def sub_label(r: Res) -> str:
    if r.bucket == "A-import-now":
        return "%s resources" % r.svc
    return SUB_LABEL.get(r.bucket, r.bucket)


def emit_imports(env, rows, existing, date, out_path, source_desc):
    counts = Counter(r.bucket for r in rows)
    used = set(existing)
    L = []
    w = L.append
    bar = "# " + "=" * 76
    w(bar)
    w("# Import blocks for %s/   -   generated %s" % (env, date))
    w("# by scripts/import-from-inventory.py from %s" % source_desc)
    w("#")
    w("# %d resources in the %s account; %d are section-A imports, %d need a check," % (
        len(rows), env, sum(v for k, v in counts.items() if k.startswith("A")),
        sum(v for k, v in counts.items() if k.startswith("B"))))
    w("# %d are network, %d are decisions, %d are excluded (see ../TRIAGE.md)." % (
        sum(v for k, v in counts.items() if k.startswith("C")),
        sum(v for k, v in counts.items() if k.startswith("D")),
        sum(v for k, v in counts.items() if k.startswith("X-"))))
    w("#")
    w("# Only section A is uncommented. B, C and D are comments carrying the one")
    w("# command that settles each of them - run it, then decide.")
    w("#")
    w("# To use section A:")
    w("#   1. cp %s/discovery/imports/imports-%s.tf.txt %s/imports.tf" % (env, env, env))
    w("#      (a .tf.txt file is inert - Terraform only reads it once renamed .tf)")
    w("#   2. cd %s && terraform init" % env)
    w("#   3. terraform plan -generate-config-out=generated.tf")
    w("#        Terraform writes real config for every import block below.")
    w("#   4. move the generated resources into sensible files, terraform fmt,")
    w("#      delete the import blocks, re-plan: it must say 0 to add, 0 to change.")
    w("#")
    w("# Never apply on the strength of this file alone. Read the plan.")
    w(bar)
    w("")

    for letter, title, blurb in SECTIONS:
        group = [r for r in rows if r.letter() == letter]
        if not group:
            continue
        w("# " + "-" * 76)
        w("# %s   (%d resource%s)" % (title, len(group), "" if len(group) == 1 else "s"))
        w("# " + "-" * 76)
        for para in wrap(blurb, 76):
            w("# %s" % para)
        w("")
        subs = defaultdict(list)
        for r in group:
            subs[sub_label(r)].append(r)
        for label in sorted(subs):
            items = sorted(subs[label], key=lambda x: (x.svc, x.ident))
            w("# --- %s (%d) ---" % (label, len(items)))
            w("")
            for r in items:
                emit_one(w, r, used)
        w("")
    text = "\n".join(L).rstrip() + "\n"
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w") as fh:
        fh.write(text)
    return counts


def emit_one(w, r: Res, used: set) -> None:
    commented = r.letter() != "A"
    addr = r.address or address_for(r, r.tf_type)
    if addr in used:
        if r.letter() == "A":
            # Section A must not shadow a resource the stack already defines.
            r.reason += ("  [address suffixed _ext: %s is already defined in this stack, so this import "
                         "cannot use it]" % addr)
            addr = addr + "_ext"
        else:
            r.reason += ("  [%s is already defined in this stack: importing here makes Terraform adopt the "
                         "live resource into that existing block, which is the point - but the config must "
                         "then match reality or the plan replaces it]" % addr)
    used.add(addr)
    imp = r.import_id or "<FILL IN from the check command below>"
    for para in wrap(r.reason, 74):
        w("# %s" % para)
    if r.check:
        w("# check:")
        for para in wrap(r.check, 74):
            w("#   %s" % para)
    w("# arn: %s" % r.arn)
    body = "import {\n  to = %s\n  id = \"%s\"\n}" % (addr, imp.replace('"', '\\"'))
    for ln in body.split("\n"):
        w(("# %s" % ln) if commented else ln)
    w("")


def emit_triage(env, rows, counts, date, accounts, out_path, notes, stack_notes, source_desc):
    L = []
    w = L.append
    w("# %s/ - what the AWS inventory means for this folder" % env)
    w("")
    w("Generated %s by `scripts/import-from-inventory.py` from %s." % (date, source_desc))
    w("Account(s): %s. Region indexed: eu-west-1 only." % ", ".join(accounts) or "unknown")
    w("")
    a = sum(v for k, v in counts.items() if k.startswith("A"))
    b = sum(v for k, v in counts.items() if k.startswith("B"))
    c = sum(v for k, v in counts.items() if k.startswith("C"))
    d = sum(v for k, v in counts.items() if k.startswith("D"))
    x = sum(v for k, v in counts.items() if k.startswith("X-"))
    w("**%d resources indexed: %d ready to import, %d needing one check, %d network, %d decisions, "
      "%d excluded.**" % (len(rows), a, b, c, d, x))
    w("")
    w("Import blocks: [`discovery/imports/imports-%s.tf.txt`](imports/imports-%s.tf.txt). "
      "Every row with its reason: `discovery/inventory-%s.csv`." % (env, env, date))
    w("")
    w("## Read this first")
    w("")
    for para in notes:
        w(para)
        w("")
    w("## Does this stack exist in the account yet?")
    w("")
    for para in stack_notes:
        w(para)
        w("")
    w("## Buckets")
    w("")
    w("| Bucket | Count | Meaning |")
    w("|---|---:|---|")
    short = {
        "A": "Standalone resources nothing in the repo claims - paste and plan.",
        "B": "Correct address depends on a name/domain/owner the ARN does not carry; each block has the one "
             "command that reveals it.",
        "C": "Live VPC, subnets, route tables, gateway, NACL, DHCP options. Adopting them can force a "
             "replacement if the config's CIDRs differ - verify first.",
        "D": "Exists, but whether Terraform should own it is a policy call (scratch resources, build "
             "artifacts, service-created log groups, compute the stack creates fresh).",
    }
    for letter, title, _blurb in SECTIONS:
        n = sum(v for k, v in counts.items() if k.startswith(letter))
        if n:
            w("| **%s** | %d | %s |" % (title, n, short[letter]))
    w("| **X - excluded** | %d | Not importable, or importing it would be wrong: see the breakdown below. |" % x)
    w("")
    w("| Group | Count |")
    w("|---|---:|")
    for bucket in sorted(counts, key=lambda k: (-counts[k], k)):
        w("| %s | %d |" % (SUB_LABEL.get(bucket, bucket), counts[bucket]))
    w("")
    w("## By service")
    w("")
    w("| Service | Total | A | B | C | D | X |")
    w("|---|---:|---:|---:|---:|---:|---:|")
    per = defaultdict(Counter)
    for r in rows:
        per[r.svc][r.letter()] += 1
        per[r.svc]["total"] += 1
    for svc in sorted(per, key=lambda s: (-per[s]["total"], s)):
        cc = per[svc]
        w("| %s | %d | %d | %d | %d | %d | %d |"
          % (svc, cc["total"], cc["A"], cc["B"], cc["C"], cc["D"], cc["X"]))
    w("")
    w("## Everything, classified")
    w("")
    w("| Bucket | Service | Resource | Terraform type | Import ID | Why |")
    w("|---|---|---|---|---|---|")
    for r in sorted(rows, key=lambda z: (z.bucket, z.svc, z.ident)):
        why = r.reason if len(r.reason) <= 170 else r.reason[:167] + "..."
        w("| %s | %s | `%s` | %s | %s | %s |" % (
            r.bucket, r.svc, r.ident.replace("|", "\\|"), r.tf_type or "-",
            ("`%s`" % r.import_id.replace("|", "\\|")) if r.import_id else "-",
            why.replace("|", "\\|")))
    w("")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w") as fh:
        fh.write("\n".join(L).rstrip() + "\n")


def emit_csv(env, rows, date, out_path):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", newline="") as fh:
        wr = csv.writer(fh)
        wr.writerow(["env", "account_id", "service", "kind", "region", "identifier", "arn", "bucket",
                     "terraform_type", "import_id", "address", "reason", "check_command"])
        for r in sorted(rows, key=lambda x: (x.bucket, x.svc, x.ident)):
            wr.writerow([r.env, r.account, r.svc, r.kind, r.region, r.ident, r.arn, r.bucket,
                         r.tf_type, r.import_id, r.address or address_for(r, r.tf_type), r.reason, r.check])


# ---------------------------------------------------------------------------
# Per-environment prose
# ---------------------------------------------------------------------------

def build_notes(env, rows, counts):
    notes = []
    x = sum(v for k, v in counts.items() if k.startswith("X-"))
    notes.append("**%d of %d indexed resources are excluded.** They are AWS-owned defaults "
                 "(`default.memorydb-*`, `primary` Athena workgroup, the `Default` X-Ray rule), resources "
                 "another tool owns (CDK/CloudFormation stacks are deployed in this account), children of a "
                 "parent resource (ENIs, individual security-group rules, `$LATEST` function versions), "
                 "backup artifacts (EBS/RDS snapshots), or the Resource Explorer index itself. Importing any "
                 "of those either fails outright or starts a fight between two tools." % (x, len(rows)))
    notes.append("**This inventory has no names and no tags.** Resource Explorer returns ARNs, so nothing here "
                 "can prove whether a security group, KMS key, Amplify app or bucket is yours, a service's, or "
                 "CDK's. That is why every bucket-B row carries the single command that answers it, and why "
                 "no bucket-B block is uncommented.")
    notes.append("**Coverage is eu-west-1 only, and global services are missing.** Route 53 hosted zones and "
                 "IAM identities are indexed in us-east-1, so their absence here means nothing. "
                 "`scripts/aws-inventory-scan.sh` uses describe calls and sees them - run it before trusting "
                 "any 'this does not exist' conclusion on this page.")
    svc = Counter(r.svc for r in rows)
    if env == "prod" and "elasticloadbalancing" not in svc and "ecs" not in svc:
        notes.append("**No load balancer, no ECS cluster or service, no EFS and no NAT gateway are indexed in "
                     "this account**, yet `prod/` defines all of them (ALB, Fargate services, EFS for Vault, "
                     "NAT gateway). Either the prod stack has never been applied or those resources are gone. "
                     "Confirm with `aws elbv2 describe-load-balancers`, `aws ecs list-clusters` and "
                     "`aws efs describe-file-systems` before importing anything into an address `prod/` "
                     "already defines.")
    if env == "prod" and any(r.svc == "ses" for r in rows):
        ses = sorted(r.ident for r in rows if r.svc == "ses" and r.kind == "identity")
        notes.append("**SES identities in this account: %s.** `monitoring/` (which deploys into this same "
                     "account) verifies `var.report_ses_domain`, defaulting to `nomaos.com` - a domain that is "
                     "*not* verified here. So either import the existing `agrovesto.com` identity into "
                     "`monitoring/` and set `report_ses_domain = \"agrovesto.com\"`, or let monitoring verify "
                     "`nomaos.com`. Do not do both."
                     % ", ".join("`%s`" % i for i in ses))
    if env == "dev":
        odd = sorted(r.ident for r in rows if r.svc == "logs" and "/prod/" in r.ident)
        if odd:
            notes.append("**Prod-named log groups live in the dev account:** %s. Either an application is "
                         "writing production logs into dev, or the names are stale. Worth settling before "
                         "importing them, because the retention you choose then applies to whatever is "
                         "actually writing there." % ", ".join("`%s`" % o for o in odd))
        if "ecs" in svc:
            notes.append("**An ECS cluster (`agrovesto-dev`) exists in the dev account** but `dev/` defines no "
                         "ECS - it runs docker compose on one EC2 host. The cluster came from the "
                         "CloudFormation stack `Infra-ECS-Cluster-agrovesto-dev-*`, i.e. CDK. Decide whether "
                         "that cluster stays (CDK keeps owning it) or goes; it is not something to import.")
    return notes


def build_stack_notes(env, rows, repo):
    wanted = stack_expected_names(env)
    cdk_idents = set()
    present = set()
    for r in rows:
        if r.bucket == "X-cdk":
            cdk_idents.add(r.ident)
            cdk_idents.add(r.base_name())
        present.add(r.ident)
        present.add(r.base_name())
    usable = present - cdk_idents
    found = sorted(n for n in wanted if n in usable)
    missing = sorted(n for n in wanted if n not in usable)
    notes = []
    if missing:
        shown = ", ".join("`%s`" % m for m in missing[:10])
        notes.append("`%s/` creates resources named `agrovesto-%s-*`. Of the %d names it would use, **none "
                     "exist in this account**%s: %s%s."
                     % (env, env, len(wanted), "" if found else "",
                        shown, " (and %d more)" % (len(missing) - 10) if len(missing) > 10 else ""))
        notes.append("That is the most important fact on this page: **the `%s/` stack has not been applied to "
                     "this account.** Most of what it defines must therefore be *created*, not imported. The "
                     "resources worth importing are the ones it would otherwise duplicate - the VPC, subnets, "
                     "route tables, buckets and databases that already exist - because creating a second copy "
                     "of those is what costs money and causes outages." % env)
    if found:
        notes.append("Names from `%s/` that do exist here: %s. Check whether Terraform already has them "
                     "(`terraform -chdir=%s state list`) before importing - importing something already in "
                     "state fails." % (env, ", ".join("`%s`" % f for f in found), env))
    notes.append("Before any of this: `terraform -chdir=%s state list`. If it is empty, the stack has no "
                 "state and every import below is a first adoption; if it is not empty, reconcile the list "
                 "against section A first, because importing a resource that is already in state under a "
                 "different address fails with 'resource already managed'." % env)
    return notes


def stack_expected_names(env):
    name = "agrovesto-%s" % env
    if env == "dev":
        return ["%s-ec2-sg" % name, "%s-mssql-backups" % name, "%s-host-config" % name, "%s-vpc" % name,
                "%s-igw" % name, "%s-public-1" % name, "%s-public-rt" % name, "%s-app-host" % name,
                "%s-eip" % name, "%s-mssql-data" % name, "%s-logging-data" % name, "%s-ec2" % name,
                "%s-wallet" % name, "%s-onboarding" % name]
    if env == "prod":
        return ["%s-alb" % name, "%s-alb-sg" % name, "%s-ecs-sg" % name, "%s-rds-sg" % name,
                "%s-efs-sg" % name, "%s-mssql" % name, "%s-mssql-master" % name, "%s-vault" % name,
                "%s-alb-logs" % name, "%s-wallet" % name, "%s-vpc" % name, "%s-public-1" % name,
                "%s-private-1" % name, "%s-nat-1" % name]
    return [name]


# ---------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--report", help="markdown inventory report (any table containing arn:aws:... rows)")
    ap.add_argument("--arns", action="append", default=[], metavar="ENV=FILE",
                    help="plain ARN list for one environment; repeatable")
    ap.add_argument("--account-env", action="append", default=[], metavar="ACCOUNT=ENV",
                    help="map an account id to an environment (adds to / overrides the repo's backend blocks)")
    ap.add_argument("--repo", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--date", default=dt.date.today().isoformat())
    ap.add_argument("--out-root", default=None, help="write somewhere other than the repo (for testing)")
    ap.add_argument("--source", default="an AWS Resource Explorer 2 inventory report",
                    help="provenance string recorded in the generated files")
    args = ap.parse_args()

    env_of_account, existing = load_repo(args.repo)
    for pair in args.account_env:
        acct, env = pair.split("=", 1)
        env_of_account[acct] = env
    if not env_of_account:
        print("no account -> environment mapping; pass --account-env 123456789012=dev", file=sys.stderr)
        return 2
    print("account -> environment: %s"
          % ", ".join("%s=%s" % kv for kv in sorted(env_of_account.items())), file=sys.stderr)

    rows, skipped = [], []
    if args.report:
        rows, skipped = parse_report(args.report, env_of_account)
    for spec in args.arns:
        env, path = spec.split("=", 1)
        rows += parse_arn_file(env, path)
    if not rows:
        print("nothing to classify: pass --report and/or --arns", file=sys.stderr)
        return 2

    seen, uniq = set(), []
    for r in rows:
        if r.arn not in seen:
            seen.add(r.arn)
            uniq.append(r)
    rows = uniq
    if skipped:
        print("%d ARN(s) skipped: %s" % (len(skipped), "; ".join(skipped[:3])), file=sys.stderr)

    for env in sorted(set(r.env for r in rows)):
        ALL_ARNS[env] = [r.arn for r in rows if r.env == env]
    tfstate_buckets = set(r.ident for r in rows if r.svc == "s3" and r.ident.startswith("nomaos-tfstate"))
    for r in rows:
        classify(r, tfstate_buckets)

    root = args.out_root or args.repo
    for env in sorted(set(r.env for r in rows)):
        env_rows = [r for r in rows if r.env == env]
        accounts = sorted(set(r.account for r in env_rows if r.account)) or ["unknown"]
        disc = os.path.join(root, env, "discovery")
        imp_path = os.path.join(disc, "imports", "imports-%s.tf.txt" % env)
        counts = emit_imports(env, env_rows, existing.get(env, set()), args.date, imp_path, args.source)
        emit_csv(env, env_rows, args.date, os.path.join(disc, "inventory-%s.csv" % args.date))
        emit_triage(env, env_rows, counts, args.date, accounts, os.path.join(disc, "TRIAGE.md"),
                    build_notes(env, env_rows, counts), build_stack_notes(env, env_rows, args.repo),
                    args.source)
        print("%-10s %4d resources from account %s" % (env + "/", len(env_rows), ",".join(accounts)),
              file=sys.stderr)
        for letter, title, _ in SECTIONS:
            n = sum(v for k, v in counts.items() if k.startswith(letter))
            if n:
                print("             %s: %d" % (title.split(" - ")[0], n), file=sys.stderr)
        print("             X - excluded: %d" % sum(v for k, v in counts.items() if k.startswith("X-")),
              file=sys.stderr)
        print("             -> %s" % imp_path, file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
