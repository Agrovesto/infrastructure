"""Regression checks for edge bootstrap without Docker, AWS or Terraform."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NginxRecoveryTests(unittest.TestCase):
    def test_health_location_opens_block(self):
        template = (ROOT / 'dev/nginx.conf.tftpl').read_text()
        self.assertIn('location /health {\n', template)

    def test_example_deploy_uses_configured_nomaos_hostname(self):
        deploy = (ROOT / 'docs/examples/deploy.sh').read_text()
        self.assertIn('echo "dev-noma-api.${domain}"', deploy)
        config = (ROOT / 'dev/terraform.auto.tfvars').read_text()
        api_config = config.split('apis = {', 1)[1].split('# `sonar`', 1)[0]
        hosts = re.findall(r'subdomain\s*=\s*"([^"]+)"', api_config)
        self.assertEqual(len(hosts), 7)
        self.assertIn('dev-noma-api', hosts)
        self.assertTrue(all(host.startswith('dev-') for host in hosts))

    def test_persistent_edge_network(self):
        compose = (ROOT / 'dev/docker-compose.yml.tftpl').read_text()
        nginx = compose.split('  nginx:', 1)[1].split('  edge:', 1)[0]
        self.assertIn('networks:\n      - default\n      - nomaos_edge', nginx)
        self.assertIn('nomaos_edge:\n    external: true\n    name: nomaos_edge', compose)
        source = (ROOT / 'dev/user_data.sh.tftpl').read_text()
        self.assertEqual(source.count('docker network inspect nomaos_edge'), 2)

    def test_boot_and_sync_seed_missing_maps_preserving_active_slots(self):
        source = (ROOT / 'dev/user_data.sh.tftpl').read_text()
        boot = re.search(r'for f in /opt/agrovesto/nginx/.*?\ndone', source, re.S).group()
        sync = re.search(r"ExecStart=/bin/bash -ec '(mkdir -p /opt/nomaos.*?)'\n", source).group(1)
        for script in (boot, sync):
            with self.subTest(script=script), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                seeds = root / 'seeds'
                slots = root / 'slots'
                seeds.mkdir()
                slots.mkdir()
                active = "map '' $nomaos_api_backend { default nomaos-api-green:5008; }\n"
                (slots / 'nomaos_api.conf').write_text(active)
                for app in ('nomaos', 'input', 'wallet', 'moneval', 'onboarding', 'serviceprovider'):
                    (seeds / f'{app}_api-active.conf').write_text(f"map '' ${app}_api_backend {{ default {app}-api-blue:5007; }}\n")
                (seeds / 'nomaos-active.conf').write_text('upstream nomaos_api { server absent:5007; }')
                command = script.replace('/opt/agrovesto/nginx', str(seeds)).replace('/opt/nomaos/nginx/upstreams', str(slots))
                for _ in range(2):
                    result = subprocess.run(['bash', '-ec', command], capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((slots / 'nomaos_api.conf').read_text(), active)
                self.assertEqual(len(list(slots.glob('*.conf'))), 6)
                self.assertFalse((slots / 'nomaos.conf').exists())


if __name__ == '__main__':
    unittest.main()
