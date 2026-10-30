# Blue/green deployments on the dev host

Every backend API on the dev EC2 box has the same blue/green deployment
mechanism: two slot containers managed by the app repo's `deploy.sh`, and the
API's **own nginx vhost** — `dev-wallet-api.nomaos.com`, `dev-input-api
.nomaos.com`, … — routing to whichever slot is active. There are no separate
deployment hostnames: a deploy flips the backend behind the name the API
already has, so DNS never changes. Terraform owns the vhosts and the *default*
slot files; `deploy.sh` owns the slot files from the first deploy on.

## The pieces, per API

```
S3 host-config bucket                 EC2 host                          runtime
─────────────────────                 ─────────                         ───────
nginx/nomaos_api-active.conf   ─┐
nginx/wallet_api-active.conf    │  boot seeds        /opt/nomaos/nginx/upstreams/
nginx/onboarding_api-...  ──────┼─ (copy only if ──►  nomaos_api.conf  ◄── deploy.sh
...                             │  the file is         wallet_api.conf      rewrites
                                │  absent)             ...                  to flip
nginx.conf.tftpl ── renders /opt/agrovesto/nginx/nginx.conf
                    server_name <the API's own subdomain>;<── e.g. dev-wallet-api
                    include /etc/nginx/upstreams/*.conf  ◄── bind-mounted dir
                    proxy_pass http://$<app>_api_backend;  ◄── runtime DNS
```

| API | `deploy.sh --app` | slot containers | ports (blue/green) | vhost (the API's own) |
|---|---|---|---|---|
| agx | `agx-api` | `agx-api-blue` / `-green` | 5019 / 5020 | `dev-agx-api.nomaos.com` |
| nomaos | `nomaos-api` | `nomaos-api-blue` / `-green` | 5007 / 5008 | `dev-noma-api.nomaos.com` |
| wallet | `wallet-api` | `wallet-api-blue` / `-green` | 5009 / 5010 | `dev-wallet-api.nomaos.com` |
| onboarding | `onboarding-api` | `onboarding-api-blue` / `-green` | 5011 / 5012 | `dev-onboarding-api.nomaos.com` |
| input | `input-api` | `input-api-blue` / `-green` | 5013 / 5014 | `dev-input-api.nomaos.com` |
| moneval | `moneval-api` | `moneval-api-blue` / `-green` | 5015 / 5016 | `dev-moneval-api.nomaos.com` |
| serviceprovider | `serviceprovider-api` | `serviceprovider-api-blue` / `-green` | 5017 / 5018 | `dev-service-api.nomaos.com` |

Each deployment reads the AppRole environment for its own API from
`/data/vault/services/<key>.env` on the host. The reference
[`docs/examples/deploy.sh`](examples/deploy.sh) loads that file before creating
a slot; keep the app repository's `load_app_env` / deployment wrapper aligned
with this contract. The file contains only that API's Vault address, KV path,
RoleID and SecretID—not the secret payload. Its Vault path follows
`kv/<service>/staging/appsettings`. The app repository's Compose definition must
pass `Vault__SecretPath` through from `deploy.sh` so ASP.NET configuration sees
`Vault:SecretPath`; the application must log in with AppRole and read its own KV
v2 path. See [`docs/vault-service-secrets.md`](vault-service-secrets.md).

Compose services (the placeholder images) hold 5000–5006; the slot pairs start
above them and never overlap. The slot containers are **not** compose services:
`deploy.sh` starts them (`--name <app>-<slot>`, on the compose network, with a
restart policy), so `docker compose up -d` neither starts nor fixes them.

Two consequences of serving deploys on the API's own hostname:

- Once an API opts in (`blue_green` in `dev/terraform.auto.tfvars`), its
  compose placeholder no longer answers for that hostname — the vhost routes
  to the slots, which 502 until the pipeline's first deploy. Clear
  `blue_green` to put the direct-to-compose routing back.
- `serviceprovider`'s hostname is `dev-service-api` (not
  `dev-serviceprovider-api`): the shorter name is the rename, and the prod
  `extra_a_records` entry changes with it.

## The slot-file contract (read this before touching deploy.sh)

The slot file must define the active slot as a **`map`**, not a static
`upstream` block:

```nginx
map '' $nomaos_api_backend {
    default nomaos-api-green:5008;
}
```

The vhosts proxy through that variable:

```nginx
proxy_pass http://$nomaos_api_backend;
```

With a variable in `proxy_pass`, nginx resolves the slot hostname **at request
time** via Docker's embedded DNS (`resolver 127.0.0.11 valid=10s` at the top of
`nginx.conf`) and caches it for 10 s. A dead or missing slot container then
only 502s its own vhost while the rest of the edge keeps serving.

A static `upstream { server <name>:<port>; }` block is resolved **once, while
nginx parses its config**. On 2026-10-09 the nomaos slot file named
`nomaos-api-green` while green was not resolvable, and nginx exited with
`host not found in upstream` before binding any port — the whole edge (Grafana,
SonarQube, Vault, every other API) crash-looped until the file was fixed by
hand. This is why the format is non-negotiable. `nginx -t` fails if the map
variable is missing, so a wrong-format file fails safe at reload time.

The same rule applies to every vhost Terraform renders. Since 2026-10-13 the
Grafana and SonarQube vhosts also proxy through variables
(`set $grafana_backend grafana:3000;` + `proxy_pass http://$grafana_backend;`)
after a recreating Grafana during a compose refresh again produced
`host not found in upstream "grafana"` and refused the whole edge at config
load. The remaining literal `proxy_pass` hostnames belong to direct
(non-blue/green) API vhosts, whose containers are compose services ordered
before nginx via `depends_on`; anything deployed independently of the compose
project must go through a variable.

`deploy.sh` changes required to comply:

1. **`write_upstream` writes the map format** (drop `max_fails`/`fail_timeout`
   and `keepalive` — those are `upstream`-block directives):

   ```bash
   cat > "$tmp" <<EOF
   # Generated by deploy.sh
   # generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
   # app=$APP_NAME
   # slot=$slot
   # port=$port
   # commit=$COMMIT_SHA

   map '' \$${UPSTREAM_NAME}_backend {
       default ${APP_NAME}-${slot}:${port};
   }
   EOF
   ```
   (`\$` emits the literal `$`; `${UPSTREAM_NAME}` still expands, so the file
   reads `map '' $wallet_api_backend {`.)

2. **`slot_port` becomes a per-app table** — the hardcoded 5007/5008 pair is
   only nomaos's:

   ```bash
   slot_port() {
     case "${APP_NAME}:$1" in
       nomaos-api:blue)           echo 5007 ;;
       nomaos-api:green)          echo 5008 ;;
       wallet-api:blue)           echo 5009 ;;
       wallet-api:green)          echo 5010 ;;
       onboarding-api:blue)       echo 5011 ;;
       onboarding-api:green)      echo 5012 ;;
       input-api:blue)            echo 5013 ;;
       input-api:green)           echo 5014 ;;
       moneval-api:blue)          echo 5015 ;;
       moneval-api:green)         echo 5016 ;;
       serviceprovider-api:blue)  echo 5017 ;;
       serviceprovider-api:green) echo 5018 ;;
       *) die "no blue/green port pair for ${APP_NAME} slot $1" ;;
     esac
   }
   ```

3. **Set `EDGE_HEALTH_HOST` per app** for the post-flip edge check. The nginx
   default server answers `404` to `Host: localhost`, so the check must send
   the API's own hostname, e.g. `EDGE_HEALTH_HOST=dev-wallet-api.nomaos.com`.
   For nomaos this is a change from `dev-api-test.nomaos.com`, which no longer
   exists as a vhost: `EDGE_HEALTH_HOST=dev-noma-api.nomaos.com`.

`UPSTREAM_NAME` in `deploy.sh` is `${APP_NAME//-/_}`, so `--app wallet-api`
yields upstream `wallet_api`, variable `$wallet_api_backend`, slot file
`wallet_api.conf` — matching the infra-side names above exactly. Keep the
`--app` naming convention `<key>-api`.

A complete reference implementation of all of the above lives in this repo at
[`docs/examples/deploy.sh`](examples/deploy.sh) — verified against the
rendered nginx config (its `write_upstream` output is byte-equivalent to the
shipped default slot file). It is a copy: the live, versioned `deploy.sh` and
its `lib.sh` belong to the application repository, so diff against this file
when upgrading.

## Flip and rollback

`deploy.sh` flips by rewriting the slot file's `default` line and reloading:

```bash
sed -i 's/default .*/default wallet-api-green:5010;/' /opt/nomaos/nginx/upstreams/wallet_api.conf
docker exec agrovesto-nginx nginx -t && docker exec agrovesto-nginx nginx -s reload
```

The health gates before the flip, and `nginx -t` before the reload, stay as
`deploy.sh` has them. Restoring the backup slot file + reload is a valid
rollback in either format, as long as the backup is a `map`.

Reboot semantics: boot re-seeds a slot file only when it is **absent**, so a
pipeline flip survives every reboot; a replaced EC2 instance falls back to
blue (the shipped default), which the pipeline's first deploy recreates.

## DNS

There is nothing new to create: the vhosts are the APIs' existing hostnames,
whose A records already point at the dev EIP via `extra_a_records` in
`prod/terraform.auto.tfvars`. The one rename is `dev-service-api` (was
`dev-serviceprovider-api`) — change the record key there and re-apply prod. If
a record is missing (host reachable only by IP), the vhosts still answer to a
`Host` header, which is all `deploy.sh`'s edge check needs since it runs
inside the nginx container.

## TLS

Blue/green vhosts are HTTP behind nginx like the other API vhosts. To put one
on HTTPS via the Caddy edge, extend `local.api_tls_domains` /
`github_sso_proxy.domains` for the subdomain (same mechanism
`apis.<name>.tls_via_caddy` uses for the direct vhosts).

## Edge recovery and rollout (October 2026)

nginx must join both the Compose default network (Vault and platform services)
and the external `nomaos_edge` network (independently deployed API slots).
Bootstrap and `agrovesto-sync.service` create that network if absent; Compose
preserves nginx's attachment across recreation. App deployment pipelines must
also attach their slots to `nomaos_edge`. Do not attach nginx to `nomaos_data`.

Slot seeding only considers `*_api-active.conf`, ignores stale legacy names
such as `nomaos-active.conf`, and never replaces an existing active slot file.
Every host-refresh path seeds: boot (user_data), `agrovesto-sync.service`, and
— since 2026-10-13 — the SSM `host-config-refresh` association, including its
Vault-OIDC branch, which runs compose directly instead of starting the unit.
Before that, an API opted into blue/green after the host booted was never
seeded on that path: `nginx.conf` referenced `$agx_api_backend` with no map
file present, and the whole edge crash-looped
(`unknown "agx_api_backend" variable`) until the file was copied by hand.
Existing old-format static upstream files require an operator-reviewed migration
to maps preserving the current target. Do not blindly reset active slots to blue.

For an existing host, user-data edits alone do not update its installed systemd
unit. Publish and sync the rendered host config through the normal deployment
process, update the unit from the new user-data template (or replace the host),
and run `systemctl daemon-reload`. Before recreating nginx:

```bash
docker network inspect nomaos_edge >/dev/null 2>&1 || docker network create nomaos_edge
sudo bash -ec 'for f in /opt/agrovesto/nginx/*_api-active.conf; do
  [ -f "$f" ] || continue
  dst="/opt/nomaos/nginx/upstreams/$(basename "$f" -active.conf).conf"
  [ -f "$dst" ] || cp "$f" "$dst"
done'
sudo docker compose -f /opt/agrovesto/compose/docker-compose.yml run --rm --no-deps nginx nginx -t &&
sudo docker compose -f /opt/agrovesto/compose/docker-compose.yml up -d --no-deps --force-recreate nginx
curl -iS --max-time 15 -H 'Host: dev-noma-api.nomaos.com' http://localhost/__edge_health
curl -iS --max-time 15 -H 'Host: dev-noma-api.nomaos.com' http://localhost/health
```

The checked-in dev NomaOS hostname is `dev-noma-api.nomaos.com`; always match the
rendered `server_name` and keep dev API hosts under the `dev-` prefix. Edge health must
return `200 edge-ok`; backend health separately verifies slot connectivity.
Verify public DNS/TLS routing independently: a successful localhost request does
not prove the public hostname reaches this host. Application image identity and
dependency health checks belong to the application repository; an empty `checks`
list does not demonstrate database health.

## HTTPS for all dev APIs

All seven APIs in `dev/terraform.auto.tfvars` set `tls_via_caddy = true`.
Caddy obtains and renews certificates for their individual hostnames, redirects
HTTP to HTTPS with status 308, and forwards requests to the existing nginx slot
routes. This is **not a wildcard certificate**: adding another API requires its
hostname and `tls_via_caddy = true` in the API configuration. Production ECS
continues using its ALB/ACM setup, not this Caddy instance.

Before rollout, point each hostname at the dev Elastic IP in the authoritative
DNS zone. An explicit stale A/CNAME overrides wildcard DNS; also remove/fix any
stale AAAA record. Allow public 80/443 to reach Caddy for ACME validation. Enabling
HTTPS in Terraform does not change externally managed DNS or make undeployed
backend slots healthy.

Publish and sync the newly rendered config through the normal infrastructure
workflow. On an existing host, validate the new Caddyfile and recreate the edge
so its single-file bind mount picks up the new contents:

```bash
sudo docker compose -f /opt/agrovesto/compose/docker-compose.yml \
  run --rm --no-deps edge caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile &&
sudo docker compose -f /opt/agrovesto/compose/docker-compose.yml \
  up -d --no-deps --force-recreate edge
docker logs --since 5m --tail 100 agrovesto-edge
curl -iS --max-time 15 http://dev-noma-api.nomaos.com/health
curl -iS --max-time 15 https://dev-noma-api.nomaos.com/health
```

Expect HTTP 308 and, once the certificate is issued and the API is healthy,
HTTPS 200. Preserve Caddy's mounted `/data` and `/config`; do not delete its
certificate storage while troubleshooting. A successful `caddy validate` checks
configuration, not DNS or successful certificate issuance.

After this change, a localhost request through Caddy on port 80 also redirects
when it carries an API Host header. For a backend-only local diagnostic, call
nginx from inside its container, or use the real HTTPS hostname. The reference
`deploy.sh` checks the edge from inside nginx, so it bypasses Caddy's redirect.

### AGX API

AGX uses `--app agx-api`, upstream `agx_api`, and slot ports 5019 (blue)
and 5020 (green). Its Compose placeholder uses 5006; it does not serve real API
traffic once blue/green routing is enabled. The active slot file is
`/opt/nomaos/nginx/upstreams/agx_api.conf`, seeded only when missing.

Point `dev-agx-api.nomaos.com` at the dev Elastic IP, sync the rendered config,
seed missing slot files through the host refresh process, and deploy the actual
AGX image using the updated app deployment script. Slots must join `nomaos_edge`
and the networks needed by their dependencies. Caddy manages HTTPS; until a slot
is deployed and healthy, backend requests return 502 while `/__edge_health`
can return 200. No AGX database or production service is added by this change.
