# DNS ownership, delegation and imports

## Choose exactly one owner per hosted zone/resource

The recommended new-domain model is:

- `bootstrap/prod` creates/owns the root public zone, e.g. `example.com`.
- `bootstrap/dev` creates/owns `dev.example.com`.
- Each environment sets its `existing_zone_id` to its bootstrap zone ID.
- Environment Terraform owns only the explicitly declared application, ACM and extra records. Bootstrap does not own those records.

Bootstrap's optional `bootstrap_zone_name` solves the certificate/delegation chicken-and-egg problem without starting a partially configured ALB. It does **not** buy/register a domain or change registrar nameservers.

Other supported models:

| Intent | Configuration |
|---|---|
| Create a new zone in environment state | `existing_zone_id = null` (default). Do not also create it in bootstrap. |
| Read a zone owned elsewhere | Set `existing_zone_id`; a data source validates the name/public-zone match. |
| Adopt an existing unmanaged zone into environment state | Leave `existing_zone_id = null`, declare matching `zone_name`, import the zone into `module.dns.aws_route53_zone.this[0]`. |
| Adopt selected existing records | Add exact entries to `dns_records` / `dns_aliases`, then import each record. Zone ownership need not move. |

**A reference is not an import.** Terraform does not automatically discover/adopt every record. Never manage the same hosted zone, record, ACM validation CNAME or Amplify domain association from two states.

## New-domain delegation

1. Register the actual domain through a registrar. Do not use the documentation-only `example.com` values.
2. Bootstrap/create the two zones and retrieve their four nameservers.
3. At the registrar, replace the root domain's delegation with the **prod** zone's four nameservers. Verify the registered DS records before any change; stale DS records can make the whole domain return `SERVFAIL`.
4. In the root prod zone, add an NS record for `dev.<domain>` pointing to the **dev** zone's four nameservers. This is DNS delegation, not VPC peering, and needs no cross-account Terraform credentials.

Example prod input (use the actual returned nameservers):

```hcl
dns_records = {
  dev_delegation = {
    name = "dev.example.com"
    type = "NS"
    ttl  = 300
    records = [
      "ns-123.awsdns-45.com.",
      "ns-678.awsdns-90.net.",
      "ns-135.awsdns-24.org.",
      "ns-246.awsdns-35.co.uk.",
    ]
  }
}
```

These nameservers are examples, **not valid values to copy**. If prod Terraform will create this record, make the prod scaffold push first. If a DNS administrator creates it earlier, import it before applying the declaration; the module intentionally sets `allow_overwrite = false`.

Verify authoritative answers from outside AWS:

```bash
dig NS example.com +short
dig NS dev.example.com +short
dig +trace api.dev.example.com
```

ACM creates one DNS validation CNAME for the apex/wildcard pair (AWS uses the same validation record for both). Keep it for automatic certificate renewal. Existing validation records must be imported deliberately if they already exist; do not set blanket `allow_overwrite = true`.

If an environment creates a zone itself on its first CI apply, it will need delegation before the ACM validation waiter completes (45 minutes). Inspect nameservers in Route 53 during that first run, or use the recommended optional zone bootstrap. An interrupted/failed wait is not a reason to destroy/recreate the zone; fix delegation and retry the push.

## Importing an existing zone and records

Before doing anything:

- Export the existing record sets, current registrar NS/DS values and the zone ID.
- Identify any other state/control plane owning the zone/records.
- Keep MX, TXT/SPF/DKIM/DMARC, CAA, verification records and existing aliases intact. Do not switch nameservers simply because a new empty zone has been created.
- Use the correct account's authorized SSO profile and remote backend. Import changes Terraform state; it does not transfer a registrar registration or move a zone between AWS accounts.

```bash
aws --profile agrovesto-prod-admin route53 list-resource-record-sets \
  --hosted-zone-id Z_REAL_PROD_ZONE > /tmp/prod-dns-inventory.json

AWS_PROFILE=agrovesto-prod-admin terraform -chdir=environments/prod init -backend-config=backend.hcl
```

For **reference-only**, set `existing_zone_id` and do not import the zone.

For **adoption into environment state**, the zone must not already belong to bootstrap/another state. Set `existing_zone_id = null`, set the matching `zone_name`, then:

```bash
AWS_PROFILE=agrovesto-prod-admin terraform -chdir=environments/prod import \
  -var-file=terraform.tfvars 'module.dns.aws_route53_zone.this[0]' Z_REAL_PROD_ZONE
```

To adopt an existing mail record, first add its exact current values:

```hcl
dns_records = {
  mail = {
    name    = "example.com"
    type    = "MX"
    ttl     = 300
    records = ["10 mail.example.com"]
  }
}
```

Then import:

```bash
AWS_PROFILE=agrovesto-prod-admin terraform -chdir=environments/prod import \
  -var-file=terraform.tfvars 'module.dns.aws_route53_record.records["mail"]' \
  'Z_REAL_PROD_ZONE_example.com_MX'
```

Alias records belong in `dns_aliases` with the exact target DNS name, target hosted-zone ID and evaluation setting:

```hcl
dns_aliases = {
  legacy = {
    name                   = "legacy.example.com"
    target_name            = "REAL-DISTRIBUTION.cloudfront.net"
    target_zone_id         = "Z2FDTNDATAQYW2" # CloudFront alias zone, not your hosted-zone ID
    evaluate_target_health = false
  }
}
```

```bash
AWS_PROFILE=agrovesto-prod-admin terraform -chdir=environments/prod import \
  -var-file=terraform.tfvars 'module.dns.aws_route53_record.aliases["legacy"]' \
  'Z_REAL_PROD_ZONE_legacy.example.com_A'
```

For an already existing service record that this stack should own, import into its actual address, not the generic extra-record map:

```text
Dev:  module.host.aws_route53_record.this["api"]
Prod: module.services.aws_route53_record.this["api"]
```

The usual Route 53 record import ID is `ZONEID_FQDN_TYPE`; records with a routing identifier append `_SET_IDENTIFIER`. Underscores in ACM/DKIM names make these IDs less readable—copy the exact documented format. Complex weighted/failover/geolocation routing policies are **not** modeled by the simple maps; add the proper Terraform resource configuration before importing one of those records.

Import should be followed by a **reviewed plan with no unexpected changes** before a deployment push. Do not claim a successful import guarantees no subsequent changes. Undeclared records in a referenced/adopted zone are not automatically deleted by these resource blocks, but deleting a hosted zone, moving authority or introducing conflicting names can still cause outages. Zone destruction is protected in this repository.

## Amplify domains

Each dev frontend gets its own domain association (e.g. `portal.dev.example.com`) and a branch attached to the association's apex. This avoids multiple apps claiming the same parent-domain association. Amplify provisions its own managed certificate/distribution; the API ALB certificate is separate.

The module explicitly creates the Amplify certificate-validation CNAME and an A alias to its CloudFront target in the supplied zone. `wait_for_verification=false` avoids a deadlock: the domain association must return its DNS targets before Terraform can create the dependent records. Certificate/domain activation then proceeds asynchronously; verify Amplify status `AVAILABLE` and HTTPS before sending traffic, even after the infrastructure apply completes.

If the console/another configuration already created these records, import them into `module.frontends.aws_route53_record.certificate["APP_KEY"]` and `module.frontends.aws_route53_record.frontend["APP_KEY"]` instead of allowing overwrites or double ownership. Existing CNAME routing records may need a reviewed conversion to the module's A alias; inventory and coordinate that change. Do not also declare these names in generic `dns_records`/`dns_aliases`. Restrictive CAA records or conflicting distributions require DNS-operator resolution.

Leave `domain_prefix = null` until DNS is ready if you only need the default Amplify domain initially. The `amplify_domain_verification` output exposes the returned targets; treat a completed Terraform apply as configuration completion, **not** proof of propagated certificates.

Manual Hosting ZIPs must contain `index.html` at the ZIP root, not an enclosing `dist/` directory. The default SPA rule excludes common static-asset extensions. Adjust routes/headers for your framework. Manual static Hosting does not implement Git-connected SSR builds; onboard those deliberately with the GitHub App and appropriate roles/configuration.

## Explicit DNS hardening extensions

- **DNSSEC:** create a signing key with the required `us-east-1` asymmetric KMS key, enable Route 53 signing, then publish/verify the DS at the registrar or signed parent. Coordinate existing signatures, TTLs, rollover and rollback. It is unsafe to automate an uncoordinated registrar cutover. DNSSEC is not enabled by this baseline.
- **Public query logs:** Route 53 public-zone query logs need CloudWatch resources/resource policy in `us-east-1`, regardless of the workload region. Add a dedicated provider/key/log retention design if required; the workload-region VPC flow logs are not a substitute for DNS query logs.
- **CAA:** consider scoped issuer restrictions after verifying ACM/Amplify issuers; incorrect records can break issuance/renewal.
- **Registrar security:** lock transfers, enable MFA and restrict NS/DS changes. Terraform state protection does not protect the registrar.
