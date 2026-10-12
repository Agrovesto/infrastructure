"""Ensure all checked-in dev API hosts opt in to Caddy-managed HTTPS."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ApiHttpsTests(unittest.TestCase):
    def test_every_configured_api_enables_tls(self):
        source = (ROOT / 'dev/terraform.auto.tfvars').read_text()
        apis = source.split('apis = {', 1)[1].split('\n# `sonar`', 1)[0]
        entries = re.findall(r'^  (\w+) = \{\n(.*?)^  \}', apis, re.M | re.S)
        self.assertEqual(len(entries), 7)
        for name, body in entries:
            with self.subTest(api=name):
                self.assertRegex(body, r'tls_via_caddy\s*=\s*true')
                self.assertRegex(body, r'subdomain\s*=\s*"dev-[^"]+"')

    def test_caddy_covers_configured_hosts_and_redirects(self):
        source = (ROOT / 'dev/Caddyfile.tftpl').read_text()
        self.assertIn('@tls_hosts host ${join(" ", domains)}', source)
        self.assertIn('redir @tls_hosts https://{host}{uri} 308', source)
        self.assertIn('${join(", ", domains)} {', source)
        self.assertIn('reverse_proxy nginx:80', source)
        locals_tf = (ROOT / 'dev/locals.tf').read_text()
        self.assertIn('if api.tls_via_caddy', locals_tf)
        self.assertIn('local.api_tls_domains,', locals_tf)


if __name__ == '__main__':
    unittest.main()
