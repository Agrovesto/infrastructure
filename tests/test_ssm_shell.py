"""Exercise the Terraform SSM wrapper under /bin/sh, without AWS or root."""
from pathlib import Path
import re
import subprocess
import unittest


class SsmShellTests(unittest.TestCase):
    def run_payload(self, body):
        source = (Path(__file__).resolve().parents[1] / 'dev/ec2.tf').read_text()
        opening = re.search(r'"(bash <<\'([A-Z_]+)\')"', source)
        self.assertIsNotNone(opening)
        start, delimiter = opening.groups()
        self.assertIn('["' + delimiter + '"],', source)
        self.assertIn('"set -euo pipefail"', source)
        payload = f'{start}\nset -euo pipefail\n{body}\n{delimiter}\n'
        return subprocess.run(['/bin/sh'], input=payload, text=True, capture_output=True)

    def test_bash_syntax_works_under_ssm_sh(self):
        result = self.run_payload('items=(first second); printf "%s" "${items[1]}"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'second')

    def test_pipeline_failure_stops_following_commands(self):
        result = self.run_payload('false | true\nprintf "SHOULD_NOT_START_SERVICES"')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('SHOULD_NOT_START_SERVICES', result.stdout)

    def test_outer_shell_does_not_expand_payload(self):
        result = self.run_payload('value=inside_bash; printf "%s" "$value"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'inside_bash')


if __name__ == '__main__':
    unittest.main()
