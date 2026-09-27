# Scoped secrets operator role for the nominated GitHub team. Extend the paths
# only after auditing actual migrated mounts. Does NOT grant root, sudo, or
# access to sys/* / auth/*; keep recovery material offline for break-glass.
path "kv/data/*" {
  capabilities = ["create", "read", "update", "delete"]
}
path "kv/metadata/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
