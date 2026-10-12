"""Static production RabbitMQ safety contracts; runtime checks run in CI/AWS."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ProdRabbitmqTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT / 'prod/rabbitmq.tf').read_text()
        cls.proxy = (ROOT / 'prod/rabbitmq-nginx.conf.tftpl').read_text()

    def test_broker_private_tls_and_protected_from_destroy(self):
        broker = self.source.split('resource "aws_mq_broker"', 1)[1].split('\nlocals {', 1)[0]
        self.assertRegex(broker, r'publicly_accessible\s*=\s*false')
        self.assertRegex(broker, r'deployment_mode\s*=\s*"SINGLE_INSTANCE"')
        self.assertIn('prevent_destroy = true', broker)
        self.assertIn('subnet_ids                 = [aws_subnet.private[0].id]', broker)
        security = self.source.split('resource "aws_security_group" "rabbitmq"', 1)[1].split('resource "aws_mq_broker"', 1)[0]
        self.assertNotIn('cidr_blocks', security)
        self.assertIn('from_port       = 5671', security)
        self.assertIn('aws_security_group.ecs.id', security)
        self.assertIn('aws_security_group.rabbitmq_proxy[0].id', security)

    def test_no_proxy_service_until_allowlisted(self):
        proxy_service = self.source.split('resource "aws_ecs_service" "rabbitmq_proxy"', 1)[1]
        self.assertRegex(proxy_service, r'count\s*= var.rabbitmq.enabled && length\(var.rabbitmq.allowed_cidrs\) > 0 \? 1 : 0')
        self.assertIn('source_ip { values = var.rabbitmq.allowed_cidrs }', self.source)
        self.assertIn('status_code  = "403"', self.source)
        self.assertIn('assign_public_ip = false', proxy_service)

    def test_proxy_checks_upstream_tls_and_resolves_at_runtime(self):
        for directive in ('proxy_ssl_verify on;', 'proxy_ssl_server_name on;',
                          'proxy_ssl_name ${broker_host};',
                          'proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;',
                          'proxy_pass https://$mq_host;', 'resolver ${dns_server}'):
            self.assertIn(directive, self.proxy)
        self.assertNotIn('proxy_set_header Authorization', self.proxy)

    def test_no_admin_credentials_in_tasks_or_outputs(self):
        task = self.source.split('resource "aws_ecs_task_definition"', 1)[1].split('resource "aws_lb_target_group"', 1)[0]
        self.assertNotIn('random_password', task)
        self.assertNotIn('secret_string', task)
        output = (ROOT / 'prod/outputs.tf').read_text().split('output "rabbitmq_access"', 1)[1]
        self.assertNotIn('.result', output)
        self.assertNotIn('secret_string', output)

    def test_production_enabled_but_management_closed(self):
        config = (ROOT / 'prod/terraform.auto.tfvars').read_text().split('rabbitmq = {', 1)[1]
        self.assertRegex(config, r'enabled\s*= true')
        self.assertRegex(config, r'allowed_cidrs\s*= \[\]')


if __name__ == '__main__':
    unittest.main()
