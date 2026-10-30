"""Local fail-closed checks; no AWS, Docker daemon, disks, or root required."""
import pathlib
import subprocess
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parents[1]


class VaultSetupSafety(unittest.TestCase):
    def run_setup(self, *, files=False, running=False, mounted=False, wrong_disk=False,
                  partitioned=False, filesystem="ext4", config=False):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            root = base / "vault"
            (root / "data").mkdir(parents=True)
            if files:
                (root / "data" / "existing").write_text("must survive")
            if config:
                (root / "config").mkdir()
                (root / "config" / "vault.hcl").write_text("existing config")
            source = (REPO / "dev/prepare-vault.sh.tftpl").read_text()
            for key, value in {
                "volume_serial": "voltest", "image": "vault:test",
                "bucket": "test", "region": "eu-west-1", "oidc_exec": "",
            }.items():
                source = source.replace("${" + key + "}", value)
            source = source.replace("root=/data/vault", f"root='{root}'")
            source = source.replace("9>/run/agrovesto-vault-setup.lock", f"9>{base}/lock")
            # No actual block device is accessed in these guard tests.
            source = source.replace('[ -b "$dev" ]', 'true')
            devices = 'fake\\npartition\\n' if partitioned else 'fake\\n'
            functions = f'''
mountpoint() {{ return {0 if mounted else 1}; }}
lsblk() {{
  case "$*" in
    *SERIAL*) echo 'fake voltest' ;;
    *MAJ:MIN*) echo '1:1' ;;
    *) printf '{devices}' ;;
  esac
}}
findmnt() {{ echo '{"2:2" if wrong_disk else "1:1"}'; }}
docker() {{ echo '{str(running).lower()}'; }}
blkid() {{ echo '{filesystem}'; }}
mkfs.ext4() {{ echo UNEXPECTED_FORMAT; exit 90; }}
mount() {{ echo UNEXPECTED_MOUNT; exit 91; }}
install() {{ echo UNEXPECTED_INSTALL; exit 92; }}
'''
            source = source.replace("set -euo pipefail", "set -euo pipefail\n" + functions)
            result = subprocess.run(["bash"], input=source, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("UNEXPECTED", result.stdout)
            if files:
                self.assertEqual((root / "data" / "existing").read_text(), "must survive")
            return result.stderr

    def test_repeated_setup_preserves_data_and_config(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            root = base / "vault"
            (root / "data").mkdir(parents=True)
            (root / "config").mkdir()
            data = root / "data" / "existing"
            data.write_text("preserve opaque stored data")
            source_config = base / "source.hcl"
            source_config.write_text("storage and seal config")
            config = root / "config" / "vault.hcl"
            config.write_text(source_config.read_text())
            original_inode = config.stat().st_ino
            source = (REPO / "dev/prepare-vault.sh.tftpl").read_text()
            for key, value in {
                "volume_serial": "voltest", "image": "vault:test",
                "bucket": "test", "region": "eu-west-1", "oidc_exec": "",
            }.items():
                source = source.replace("${" + key + "}", value)
            source = source.replace("root=/data/vault", f"root='{root}'")
            source = source.replace("9>/run/agrovesto-vault-setup.lock", f"9>{base}/lock")
            source = source.replace('[ -b "$dev" ]', 'true')
            source = source.replace("/opt/agrovesto/vault/managed-vault.hcl", str(source_config))
            source = source.replace("/etc/systemd/system", str(base / "systemd"))
            functions = r"""
mountpoint() { return 0; }
lsblk() {
  case "$*" in
    *SERIAL*) echo 'fake voltest' ;;
    *MAJ:MIN*) echo '1:1' ;;
    *) exit 93 ;;
  esac
}
findmnt() { echo '1:1'; }
docker() {
  case "$*" in
    'image inspect '*) return 0 ;;
    'run --rm --entrypoint id '*) echo 100 ;;
    *) echo UNEXPECTED_DOCKER; exit 94 ;;
  esac
}
chown() { return 0; }
systemctl() { return 0; }
mkfs.ext4() { echo UNEXPECTED_FORMAT; exit 90; }
mount() { echo UNEXPECTED_MOUNT; exit 91; }
install() { echo UNEXPECTED_INSTALL; exit 92; }
"""
            source = source.replace("set -euo pipefail", "set -euo pipefail\n" + functions)
            for _ in range(2):
                result = subprocess.run(["bash"], input=source, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("UNEXPECTED", result.stdout)
                self.assertEqual(config.stat().st_ino, original_inode)
                self.assertEqual(data.read_text(), "preserve opaque stored data")
            self.assertIn("RequiresMountsFor=/data/vault", (
                base / "systemd/docker.service.d/vault-storage.conf").read_text())

    def test_existing_root_data_is_not_hidden(self):
        self.assertIn("existing root-disk files", self.run_setup(files=True))

    def test_running_vault_blocks_first_mount(self):
        self.assertIn("stop Vault", self.run_setup(running=True))

    def test_wrong_mounted_disk_is_rejected(self):
        self.assertIn("wrong volume", self.run_setup(mounted=True, wrong_disk=True))

    def test_partitioned_volume_is_not_formatted(self):
        self.assertIn("partitioned volume", self.run_setup(partitioned=True))

    def test_existing_other_filesystem_is_not_formatted(self):
        self.assertIn("expected ext4", self.run_setup(filesystem="xfs"))

    def test_config_is_not_overwritten(self):
        self.assertIn("existing config differs", self.run_setup(mounted=True, config=True))


if __name__ == "__main__":
    unittest.main()
