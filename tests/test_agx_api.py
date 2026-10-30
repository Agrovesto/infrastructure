"""AGX dev deployment contract and port allocation regression checks."""
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AgxApiTests(unittest.TestCase):
    def test_config_and_non_overlapping_ports(self):
        config = (ROOT / 'dev/terraform.auto.tfvars').read_text().split('apis = {', 1)[1].split('\n# `sonar`', 1)[0]
        agx = re.search(r'^  agx = \{(.*?)^  \}', config, re.M | re.S).group(1)
        for pattern in (r'subdomain\s*= "dev-agx-api"', r'tls_via_caddy\s*= true',
                        r'host_port\s*= 5006', r'blue_port\s*= 5019', r'green_port\s*= 5020'):
            self.assertRegex(agx, pattern)
        ports = re.findall(r'(?:host_port|blue_port|green_port)\s*=\s*(\d+)', config)
        self.assertEqual(len(ports), len(set(ports)))

    def test_example_script_recognizes_agx(self):
        script = (ROOT / 'docs/examples/deploy.sh').read_text()
        functions = '\n'.join(re.search(r'^' + name + r'\(\) \{.*?^\}', script, re.M | re.S).group()
                              for name in ('slot_port', 'is_managed_app', 'vhost_hostname'))
        result = subprocess.run(['bash', '-ec', functions + '\nAPP_NAME=agx-api; DOMAIN_NAME=nomaos.com; is_managed_app "$APP_NAME"; slot_port blue; slot_port green; vhost_hostname "$APP_NAME"'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ['5019', '5020', 'dev-agx-api.nomaos.com'])


if __name__ == '__main__':
    unittest.main()
