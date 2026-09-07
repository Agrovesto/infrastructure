#!/usr/bin/env bash
set -Eeuo pipefail
# Official immutable v0.74.0 Linux x86-64 release checksum. Update version and
# checksum together after reviewing the upstream release and its attestations.
version=0.74.0
sha256=2ae6fe3ee734b7fdf11335663e18c75ea12dccc76062f09f164a3b0f8be4371a
destination=${1:?Usage: install-trivy.sh /absolute/bin/directory}
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || { echo 'This installer is pinned for Linux x86-64 CI.' >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
archive="trivy_${version}_Linux-64bit.tar.gz"
curl --fail --silent --show-error --location --retry 5 \
  "https://github.com/aquasecurity/trivy/releases/download/v$version/$archive" -o "$tmp/$archive"
printf '%s  %s\n' "$sha256" "$tmp/$archive" | sha256sum --check
tar -xzf "$tmp/$archive" -C "$tmp" trivy
install -D -m 0755 "$tmp/trivy" "$destination/trivy"
"$destination/trivy" --version
