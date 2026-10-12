"""RabbitMQ deployment safety checks, without AWS/Docker dependencies."""
from pathlib import Path
import os
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RabbitmqTests(unittest.TestCase):
    def test_broker_is_private_and_persistent(self):
        source = (ROOT / 'dev/docker-compose.yml.tftpl').read_text()
        broker = source.split('  rabbitmq:\n', 1)[1].split('%{ endif ~}', 1)[0]
        self.assertNotIn('ports:', broker)
        self.assertIn('hostname: rabbitmq', broker)
        self.assertIn('RABBITMQ_NODENAME: rabbit@rabbitmq', broker)
        self.assertIn('${rabbitmq.data_dir}:/var/lib/rabbitmq', broker)
        self.assertIn('      - default\n      - nomaos_data', broker)
        self.assertNotIn('nomaos_edge', broker)
        self.assertIn('check_running && rabbitmq-diagnostics -q check_local_alarms', broker)
        self.assertIn('$${RABBITMQ_PASSWORD:?', broker)

    def test_management_is_allowlisted_and_uses_runtime_dns(self):
        source = (ROOT / 'dev/nginx.conf.tftpl').read_text()
        block = source.split('%{ if rabbitmq.enabled ~}', 1)[1].split('  # ── Vault:', 1)[0]
        self.assertIn('rabbitmq.allowed_cidrs', block)
        self.assertIn('deny all;', block)
        self.assertIn('proxy_pass http://$rabbitmq_backend;', block)
        locals_tf = (ROOT / 'dev/locals.tf').read_text()
        self.assertIn('tls_proxy_enabled = var.rabbitmq.enabled ||', locals_tf)
        self.assertIn('var.rabbitmq.enabled ? "${var.rabbitmq.subdomain}.${var.domain_name}" : ""', locals_tf)

    def test_password_fails_closed_and_is_not_logged(self):
        source = (ROOT / 'dev/user_data.sh.tftpl').read_text()
        script = re.search(r'RABBITMQ_PW=\$\(aws .*?unset RABBITMQ_PW', source, re.S).group()
        script = script.replace('${rabbitmq_parameter}', '/test/rabbitmq_password').replace('${aws_region}', 'eu-west-1')
        with tempfile.TemporaryDirectory() as tmp:
            aws = Path(tmp) / 'aws'
            aws.write_text('#!/bin/sh\nprintf "%s" "$TEST_PASSWORD"\n')
            aws.chmod(0o755)
            for value, valid in [('ab' * 32, True), ('', False), ('short', False), ('abc$unsafe', False), ('a' * 32 + '\ninjected=yes', False)]:
                with self.subTest(valid=valid, length=len(value)):
                    output = Path(tmp) / 'env'
                    env = dict(os.environ, PATH=tmp + ':' + os.environ['PATH'], TEST_PASSWORD=value)
                    result = subprocess.run(['bash', '-ec', '{\n' + script + '\n} > "$1"', 'test', str(output)], env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode == 0, valid)
                    self.assertEqual(result.stdout, '')
                    if valid:
                        self.assertEqual(output.read_text(), f'RABBITMQ_PASSWORD={value}\n')
                    else:
                        self.assertEqual(output.read_text(), '')

    def test_network_is_created_on_boot_and_refresh(self):
        source = (ROOT / 'dev/user_data.sh.tftpl').read_text()
        self.assertEqual(source.count('docker network inspect nomaos_data'), 2)


if __name__ == '__main__':
    unittest.main()
