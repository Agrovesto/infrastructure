"""Validate the rendered host-side Vault service helpers without AWS or Vault."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SERVICES = ["agx", "nomaos", "wallet", "onboarding", "input", "moneval", "serviceprovider"]


def render(
    template: str,
    *,
    environment: str,
    kv_mount: str,
    path_environment: str = "staging",
    env_dir: str = "/data/vault/services",
) -> str:
    """Render the small Terraform template surface used by the shell helpers."""
    loop = re.compile(r"%\{ for service in services ~\}(.*?)%\{ endfor ~\}", re.DOTALL)

    def render_services(match):
        body = match.group(1)
        return "".join(body.replace("${service}", service) for service in SERVICES)

    rendered = loop.sub(render_services, template)
    # Protect Terraform's escaped shell expansions before substituting actual
    # template variables such as ${environment}.
    escaped = "__TERRAFORM_LITERAL_DOLLAR_BRACE__"
    rendered = rendered.replace("$${", escaped)
    for name, value in {
        "environment": environment,
        "kv_mount": kv_mount,
        "path_environment": path_environment,
        "env_dir": env_dir,
    }.items():
        rendered = rendered.replace("${" + name + "}", value)
    # Terraform's $${ escape emits a literal ${ for Bash at runtime.
    return rendered.replace(escaped, "${")


class VaultServiceScriptTests(unittest.TestCase):
    def test_host_helpers_render_to_valid_bash(self):
        templates = [
            ROOT / "dev/configure-vault-services.sh.tftpl",
            ROOT / "dev/write-vault-service-secret.sh.tftpl",
        ]
        for template in templates:
            with self.subTest(template=template.name), tempfile.NamedTemporaryFile("w", suffix=".sh") as script:
                script.write(render(template.read_text(), environment="dev", kv_mount="kv"))
                script.flush()
                result = subprocess.run(["bash", "-n", script.name], text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_per_service_paths_and_credentials_are_generated_at_runtime(self):
        source = (ROOT / "dev/configure-vault-services.sh.tftpl").read_text()
        rendered = render(source, environment="dev", kv_mount="kv")
        for service in SERVICES:
            with self.subTest(service=service):
                self.assertIn(f'"{service}"', rendered)
        self.assertIn("printf 'VAULT_SECRET_PATH=%s/%s/%s/appsettings\\n'", rendered)
        self.assertIn('policy="dev-${service}-read"', rendered)
        self.assertIn('role="dev-${service}"', rendered)
        self.assertIn("chmod 0640", rendered)
        self.assertIn("secret_id_ttl=8760h", rendered)
        self.assertIn("secret-id-accessor/destroy", rendered)
        self.assertNotIn("VAULT_DEV_ROOT_TOKEN_ID", rendered)
        self.assertNotRegex(rendered, r"VAULT_SECRET_ID=[A-Za-z0-9]")

    def test_secret_payload_is_streamed_to_vault_not_command_arguments(self):
        rendered = render(
            (ROOT / "dev/write-vault-service-secret.sh.tftpl").read_text(),
            environment="dev",
            kv_mount="kv",
        )
        self.assertIn("python3 - \"$secret_file\"", rendered)
        self.assertIn('vault write -format=json "$secret_api_path" -', rendered)
        self.assertIn(">/dev/null", rendered)
        self.assertIn('secret_api_path="kv/data/$service/staging/appsettings"', rendered)

    def test_vault_network_hook_is_valid_and_idempotent(self):
        path = ROOT / "dev/connect-vault-network.sh"
        result = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        source = path.read_text()
        self.assertIn("docker network connect --alias vault", source)
        self.assertIn(".NetworkSettings.Networks", source)
        self.assertIn('exit 0', source)

    def test_prod_vault_helpers_are_valid_bash(self):
        for script in [
            ROOT / "prod/configure-vault-services.sh",
            ROOT / "prod/write-vault-service-secret.sh",
        ]:
            with self.subTest(script=script.name):
                result = subprocess.run(["bash", "-n", str(script)], text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_prod_ecs_uses_service_scoped_appsettings_paths_and_ecs_controller(self):
        ecs = (ROOT / "prod/ecs.tf").read_text()
        access = (ROOT / "prod/vault_service_access.tf").read_text()
        self.assertIn('"${local.vault_kv_mount}/${service}/${local.vault_path_environment}/appsettings"', access)
        self.assertIn('"Vault__SecretPath"', ecs)
        self.assertIn('aws_secretsmanager_secret.vault_service_credentials[each.key].arn', ecs)
        self.assertIn('deployment_controller {\n    type = "ECS"', ecs)
        self.assertIn('deployment_controller {\n    type = "ECS"', (ROOT / "prod/vault.tf").read_text())


if __name__ == "__main__":
    unittest.main()
