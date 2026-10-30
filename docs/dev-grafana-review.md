# Dev Grafana configuration review — 2026-10-12

This is a code review, not a live AWS/EC2 health check. No Grafana access settings
were changed as part of the production RabbitMQ network restriction.

## Configured behavior

- Enabled through `logging.enabled` (defaults to true).
- URL: `https://dev-grafana.nomaos.com`, from `dev/terraform.auto.tfvars` and
  `ui_https_enabled = true`. Caddy terminates TLS and proxies through nginx.
- `agrovesto-grafana` runs in the dev EC2 Compose stack, **not ECS**.
- Container port 3000 is published on host loopback only. nginx reaches it on
  the default Compose network; it does not require `nomaos_edge` or `nomaos_data`.
- Grafana data/provisioning/dashboards are mounted from the logging directory on
  the encrypted logging EBS volume. Datasources are private Loki, Tempo and
  Prometheus Compose endpoints (Loki ↔ Tempo jump links provisioned both ways).
  A `/api/health` container check is configured.
- GitHub SSO is conditional on both client credentials being supplied. CI wires
  the dev GitHub OAuth secrets; the repository alone cannot establish whether
  the secrets are actually configured. Local administrator login stays enabled.

## Security findings

1. **Public reachability is explicitly configured:** `logging.allowed_cidrs`
   is `["0.0.0.0/0"]`. TLS and Grafana login still apply, but nginx imposes no
   source-IP restriction. For private operator access, use trusted office/VPN
   CIDRs or `[]` for loopback/tunnel-only access.
2. **The Terraform schema contains a known development admin password default.**
   Confirm a strong override was supplied, and rotate the existing Grafana admin
   credential if that default was ever used. Do not post passwords or rendered
   Compose environment/config output in chat. Initial admin environment values
   do not reliably reset a password once Grafana's database exists; use Grafana's
   supported admin reset/rotation process and update the secret source too.
3. DNS is owned by prod (`dev.manage_dns=false`). The example dev Grafana DNS
   entry is commented out. A working wildcard or existing record may already
   route correctly, but live DNS and certificate validity are unverified here.

## Safe host checks

Run on the dev EC2 host:

```bash
docker inspect agrovesto-grafana --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}'
curl -iS --max-time 15 http://127.0.0.1:3000/api/health
curl -iS --max-time 15 https://dev-grafana.nomaos.com/api/health
docker logs --since 10m --tail 50 agrovesto-grafana
```

Use the configured host port if it differs from default 3000. A local 200 with
public failure points toward DNS/TLS/nginx routing rather than Grafana itself.
A successful health response does not prove SSO, dashboards or datasource query
health: also test login and a Loki/Prometheus query. Review logs for sensitive
content before sharing them.
