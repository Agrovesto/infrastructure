"""Static production RabbitMQ safety contracts; runtime checks run in CI/AWS."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ProdRabbitmqTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT / 'prod/rabbitmq.tf').read_text()

    def test_broker_private_tls_and_protected_from_destroy(self):
        self.assertRegex(self.source, r'publicly_accessible\s*=\s*false')
        self.assertRegex(self.source, r'deployment_mode\s*=\s*"SINGLE_INSTANCE"')
        self.assertIn('prevent_destroy = true', self.source)
        self.assertIn('subnet_ids                 = [aws_subnet.private[0].id]', self.source)
        security = self.source.split('resource "aws_security_group" "rabbitmq"', 1)[1].split('resource "aws_mq_broker"', 1)[0]
        self.assertNotIn('cidr_blocks', security)
        self.assertIn('from_port       = 5671', security)
        self.assertIn('from_port       = 443', security)
        self.assertEqual(security.count('security_groups = [aws_security_group.rabbitmq_clients[0].id]'), 2)
        self.assertNotIn('aws_security_group.ecs.id', security)

    def test_no_external_management_resources(self):
        for kind in ('aws_lb_listener_rule', 'aws_lb_target_group', 'aws_route53_record', 'aws_ecs_task_definition', 'aws_ecs_service'):
            self.assertNotIn(f'resource "{kind}"', self.source)
        self.assertFalse((ROOT / 'prod/rabbitmq-nginx.conf.tftpl').exists())
        variables = (ROOT / 'prod/variables.tf').read_text().split('variable "rabbitmq"', 1)[1]
        self.assertNotIn('allowed_cidrs', variables)
        self.assertNotIn('proxy_image', variables)

    def test_only_application_services_receive_client_group(self):
        ecs = (ROOT / 'prod/ecs.tf').read_text()
        self.assertIn('var.rabbitmq.enabled ? [aws_security_group.rabbitmq_clients[0].id] : []', ecs)
        self.assertNotIn('rabbitmq_clients', (ROOT / 'prod/vault.tf').read_text())
        self.assertIn('cluster         = aws_ecs_cluster.main.id', ecs)

    def test_no_admin_credentials_in_tasks_or_outputs(self):
        self.assertNotIn('random_password.rabbitmq', (ROOT / 'prod/ecs.tf').read_text())
        output = (ROOT / 'prod/outputs.tf').read_text().split('output "rabbitmq_access"', 1)[1]
        self.assertNotIn('.result', output)
        self.assertNotIn('secret_string', output)
        self.assertIn('instances[0].console_url', output)

    def test_production_enabled_without_public_hostname(self):
        config = (ROOT / 'prod/terraform.auto.tfvars').read_text().split('rabbitmq = {', 1)[1]
        self.assertRegex(config, r'enabled\s*= true')
        self.assertNotIn('subdomain', config)
        self.assertNotIn('allowed_cidrs', config)


if __name__ == '__main__':
    unittest.main()
