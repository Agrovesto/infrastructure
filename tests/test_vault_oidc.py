"""Execute the rendered bootstrap with a fake Vault CLI; never contact a host."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class OidcBootstrapSafety(unittest.TestCase):
    def run_bootstrap(self, sealed, auth_error):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            # Intentionally no host .env: Docker membership must suffice.
            script = (ROOT / 'dev/configure-vault-oidc.sh').read_text()
            script = script.replace('$${', '${')
            for key, value in dict(vault_fqdn='dev-vault.nomaos.com',
                                   github_org='Agrovesto', github_team='infrastructure').items():
                script = script.replace('${' + key + '}', value)
            docker_mock = """docker() {
  printf '%s' '[{"State":{"Running":true},"Config":{"Env":["VAULT_OIDC_CLIENT_SECRET=test-fixture-only"]}}]'
}
"""
            script = script.replace('set -euo pipefail', 'set -euo pipefail\n' + docker_mock)
            original = 'vault() { docker exec -i -e VAULT_TOKEN agrovesto-vault vault "$@"; }'
            mock = '''vault() {
  printf '%s\\n' "$*" >> calls
  case "$*" in
    'status -format=json') echo '{"initialized":true,"sealed":SEALED}'; return STATUS ;;
    'auth list -format=json') return AUTH ;;
    *) echo UNEXPECTED_MUTATION; return 95 ;;
  esac
}'''.replace('SEALED', str(sealed).lower()).replace('STATUS', '2' if sealed else '0').replace('AUTH', str(auth_error))
            self.assertIn(original, script)
            script = script.replace(original, mock)
            result = subprocess.run(['bash'], input=script, text=True, capture_output=True,
                                    cwd=folder, env={**os.environ, 'VAULT_TOKEN': 'test-fixture-only'})
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('UNEXPECTED_MUTATION', result.stdout)
            self.assertNotIn('test-fixture-only', result.stdout + result.stderr)
            return (path / 'calls').read_text()

    def test_sealed_vault_is_not_configured(self):
        self.assertNotIn('auth list', self.run_bootstrap(True, 0))

    def test_auth_failure_does_not_enable_mount(self):
        self.assertIn('auth list', self.run_bootstrap(False, 1))


if __name__ == '__main__':
    unittest.main()
