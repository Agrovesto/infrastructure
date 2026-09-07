# Docker Compose reference

## How Compose is used

| Environment | Who owns Compose | Where it runs |
|---|---|---|
| **Dev AWS** | Terraform (`modules/dev_host`) renders `compose.yaml` | `/opt/agrovesto/compose.yaml` on the private EC2 host |
| **Prod AWS** | **No Compose** — 5 APIs + 2 frontends on ECS Fargate behind the ALB | N/A |
| **Local laptop** | Files in this directory | Your machine only |

Do **not** commit real passwords. Dev host credentials are generated at runtime into `/run/agrovesto/*.env`.

## Current application map (5 APIs + 2 frontends)

| Kind | Name | Dev hostname | Prod hostname | Host port (dev) | Database |
|---|---|---|---|---|---|
| API | `core` | `api.<zone>` | `api.<zone>` | 8080 | `AgrovestoCore` |
| API | `auth` | `auth.<zone>` | `auth.<zone>` | 8081 | `AgrovestoAuth` |
| API | `trading` | `trading.<zone>` | `trading.<zone>` | 8082 | `AgrovestoTrading` |
| API | `catalog` | `catalog.<zone>` | `catalog.<zone>` | 8083 | `AgrovestoCatalog` |
| API | `notifications` | `notifications.<zone>` | `notifications.<zone>` | 8084 | `AgrovestoNotifications` |
| Frontend | `portal` | Amplify `portal.<zone>` | ECS apex `https://<zone>` | — | none |
| Frontend | `admin` | Amplify `admin.<zone>` | ECS `admin.<zone>` | — | none |

Rename keys in `environments/*/terraform.tfvars` if your real service names differ — keep them lowercase, unique hostnames/priorities/ports.

## Local quick start

```bash
cp compose/local/env/sql.env.example compose/local/env/sql.env
for s in core auth trading catalog notifications; do
  cp "compose/local/env/${s}.env.example" "compose/local/env/${s}.env"
done
docker compose -f compose/local/compose.yaml up -d --build
```

- APIs: `http://localhost:8080` … `8084` (`/health`)
- Portal: `http://localhost:3000/`
- Admin: `http://localhost:3001/`
- SQL: `localhost:1433` (local only)

See `apps/api` and `apps/web` for sample images that meet the platform contract (x86-64, UID 10001, port 8080, `/health`, `DB_*`).
