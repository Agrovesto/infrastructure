"""Regression for first-time external-group setup and repeated bootstrap."""
from pathlib import Path
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1] / 'dev/configure-vault-oidc.sh'


class VaultGroupTests(unittest.TestCase):
    def script(self):
        tail = SOURCE.read_text().split('# Upsert by name:', 1)[1]
        tail = '# Upsert by name:' + tail
        tail = tail.replace('${github_org}', 'Agrovesto').replace('${github_team}', 'infrastructure')
        return '''set -euo pipefail
accessor=auth_oidc_fixture
vault() {
  printf '%s\\n' "$*" >> calls
  case "$1 $2" in
    'write identity/group/name/dev-vault-github-operators')
      [ ! -f deny ] || return 2
      touch group_exists ;;
    'read -format=json')
      [ -f group_exists ] || return 2
      if [ -f alias_exists ]; then
        echo '{"data":{"id":"group-fixture","alias":{"id":"alias-fixture"}}}'
      else
        echo '{"data":{"id":"group-fixture","alias":{}}}'
      fi ;;
    'write identity/group-alias')
      [ ! -f alias_exists ] || return 2
      touch alias_exists ;;
    'write identity/group-alias/id/alias-fixture')
      [ -f alias_exists ] ;;
    *) return 99 ;;
  esac
}
''' + tail

    def test_first_run_and_repeat_are_clean(self):
        with tempfile.TemporaryDirectory() as folder:
            for _ in range(2):
                result = subprocess.run(['bash'], input=self.script(), text=True,
                                        capture_output=True, cwd=folder)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, '')
                self.assertIn('OIDC configured.', result.stdout)
            calls = (Path(folder) / 'calls').read_text()
            self.assertEqual(calls.count('write identity/group-alias name='), 1)
            self.assertIn('write identity/group-alias/id/alias-fixture', calls)

    def test_permission_failure_does_not_report_success(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / 'deny').touch()
            result = subprocess.run(['bash'], input=self.script(), text=True,
                                    capture_output=True, cwd=folder)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('OIDC configured.', result.stdout)
            self.assertNotIn('read -format=json', (Path(folder) / 'calls').read_text())


if __name__ == '__main__':
    unittest.main()
