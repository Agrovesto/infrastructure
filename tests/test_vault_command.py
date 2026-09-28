"""Guard the official Vault image entrypoint's automatic config loading contract."""
from pathlib import Path
import re
import shlex
import unittest

ROOT = Path(__file__).resolve().parents[1]


class VaultCommandTests(unittest.TestCase):
    def test_server_relies_on_single_automatic_config_directory(self):
        template = (ROOT / 'dev/docker-compose.yml.tftpl').read_text()
        vault_service = template.split('\n  vault:\n', 1)[1].split('\n  dex:', 1)[0]
        command = re.search(r'^    command: (.+)$', vault_service, re.MULTILINE).group(1)
        self.assertEqual(shlex.split(command), ['server'])
        # hashicorp/vault:1.15 expands `server` to `vault server -config=/vault/config ...`.
        # A second file flag would load the seal stanza twice.
        self.assertNotIn('-config=', command)
        self.assertIn('target: /vault/config/vault.hcl', vault_service)


if __name__ == '__main__':
    unittest.main()
