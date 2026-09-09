#!/usr/bin/env bash
# Called under /var/lock/agrovesto-config.lock by cloud-init and SSM.
set -Eeuo pipefail
umask 077
cd /opt/agrovesto

dnf install -y docker amazon-cloudwatch-agent python3.12 python3.12-pip jq xfsprogs rsyslog
# The standard AL2023 AMI already includes curl-minimal, AWS CLI v2 and SSM.
# Do not install conflicting curl/curl-minimal packages.
command -v curl >/dev/null
python3.12 -m venv /opt/agrovesto/venv
/opt/agrovesto/venv/bin/pip install --disable-pip-version-check -r requirements.txt

# Version and checksum are verified before the executable is installed.
compose_version=v2.39.4
if ! docker compose version --short 2>/dev/null | grep -qx "${compose_version#v}"; then
  tmp=$(mktemp -d)
  (
    cd "$tmp"
    curl --fail --silent --show-error --location --retry 5 -O \
      "https://github.com/docker/compose/releases/download/$compose_version/docker-compose-linux-x86_64"
    curl --fail --silent --show-error --location --retry 5 -O \
      "https://github.com/docker/compose/releases/download/$compose_version/docker-compose-linux-x86_64.sha256"
    sha256sum --check docker-compose-linux-x86_64.sha256
    install -D -m 0755 docker-compose-linux-x86_64 /usr/local/lib/docker/cli-plugins/docker-compose
  )
  rm -rf -- "$tmp"
fi
systemctl enable --now docker rsyslog

volume_id=$(jq -er .volume_id runtime.json)
serial=${volume_id//-/}
device=""
for _ in $(seq 1 120); do
  # Never rely on /dev/sdf: Nitro device ordering changes across boots.
  device=$(lsblk -dn -o PATH,SERIAL | awk -v serial="$serial" '$2 == serial {print $1}')
  [[ -b "$device" ]] && break
  sleep 5
done
[[ -b "$device" ]] || { echo 'Database EBS volume is not attached; refusing startup.' >&2; exit 1; }
[[ $(lsblk -nr -o TYPE "$device" | wc -l) -eq 1 ]] || { echo 'Unexpected partition layout; manual recovery required.' >&2; exit 1; }

if filesystem=$(blkid -p -s TYPE -o value "$device"); then
  [[ "$filesystem" == xfs ]] || { echo 'Unexpected filesystem; never formatting an existing volume.' >&2; exit 1; }
else
  probe_status=$?
  [[ "$probe_status" -eq 2 ]] || { echo 'Filesystem probe failed.' >&2; exit 1; }
  [[ -z $(wipefs --no-act --noheadings "$device") ]] || { echo 'Unknown disk signature; refusing format.' >&2; exit 1; }
  mkfs.xfs "$device"  # No -f: fail rather than overwrite any existing signature.
fi
uuid=$(blkid -s UUID -o value "$device")
mkdir -p /srv/mssql
if mountpoint -q /srv/mssql; then
  [[ $(findmnt -rn -o UUID --mountpoint /srv/mssql) == "$uuid" ]] || { echo 'Wrong volume mounted.' >&2; exit 1; }
else
  [[ -z $(find /srv/mssql -mindepth 1 -maxdepth 1 -print -quit) ]] || { echo 'Unmounted data directory is not empty; manual recovery required.' >&2; exit 1; }
  mount -t xfs "UUID=$uuid" /srv/mssql
fi
if awk '$2 == "/srv/mssql" {found=1} END {exit !found}' /etc/fstab; then
  grep -Fq "UUID=$uuid /srv/mssql " /etc/fstab || { echo 'Conflicting fstab entry.' >&2; exit 1; }
else
  # Keep the host accessible through SSM after a disk failure. The application
  # service separately REQUIRES the mount and checks mountpoint before starting.
  printf 'UUID=%s /srv/mssql xfs defaults,nofail,x-systemd.device-timeout=180 0 2\n' "$uuid" >> /etc/fstab
fi
xfs_growfs /srv/mssql
install -d -m 0750 -o 10001 -g 0 /srv/mssql/{data,log,secrets,backup}
cat > /srv/mssql/mssql.conf <<'CONFIG'
[network]
forceencryption = 1
CONFIG
chown 10001:0 /srv/mssql/mssql.conf
chmod 0640 /srv/mssql/mssql.conf
chown 10001:0 /srv/mssql
chmod 0750 /srv/mssql

# Containers do not receive the host's IAM credentials (also enforced by IMDSv2 hop=1).
iptables -C DOCKER-USER -d 169.254.169.254/32 -j REJECT 2>/dev/null || \
  iptables -I DOCKER-USER -d 169.254.169.254/32 -j REJECT

install -m 0644 agrovesto.service /etc/systemd/system/agrovesto.service
install -m 0644 agrovesto-backup.service /etc/systemd/system/agrovesto-backup.service
install -m 0644 agrovesto-backup.timer /etc/systemd/system/agrovesto-backup.timer
chmod 0750 /opt/agrovesto/start.sh
systemctl daemon-reload
systemctl enable agrovesto.service agrovesto-backup.timer
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/agrovesto/cloudwatch.json -s
systemctl restart agrovesto.service
systemctl start agrovesto-backup.timer
