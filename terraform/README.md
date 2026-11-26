# Deploying with Terraform

This installs the stack on another Linux machine over SSH: a homelab server, a
VM or a cloud instance. Terraform:

1. Connects over SSH and installs Docker if it's missing (with Docker's official
   install script).
2. Copies `compose.yaml`, `config/` and `scripts/` from your working copy to
   `/opt/monitoring-stack`.
3. Writes `.env` from your variables, with a generated Grafana password and
   private ntfy topic unless you set your own.
4. Runs `docker compose up` and waits until every service is healthy.

Edit any config file (for example `config/prometheus/targets/nodes.yml`) and
run `make tf-apply` again to redeploy. Your data is kept across redeploys.

## Requirements

- **SSH access:** you can SSH to the host with a key, either a key file or your
  SSH agent.
- **Root or passwordless sudo:** the SSH user is root or has passwordless sudo.
- **Terraform 1.6 or newer, or Docker:** without Terraform, the `make tf-*`
  commands run `hashicorp/terraform` in a container. Your `~/.ssh` is mounted
  read-only, along with your SSH agent if one is running.

## Usage

From the repository root:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# set host and ssh_user (everything else is optional)

make tf-init      # once
make tf-plan      # preview
make tf-apply     # deploy or update
make tf-output    # Grafana URL and password, ntfy topic to subscribe to
make tf-destroy   # stop the stack (data is kept unless remove_data_on_destroy = true)
```

## Variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `host` | (required) | IP or DNS name of the target |
| `ssh_user` | (required) | SSH user (root or passwordless sudo) |
| `ssh_port` | `22` | |
| `ssh_private_key_path` | `~/.ssh/id_ed25519` | `""` uses your SSH agent |
| `install_dir` | `/opt/monitoring-stack` | |
| `install_docker` | `true` | Install Docker if missing |
| `remove_data_on_destroy` | `false` | Also delete metrics, logs and dashboards on destroy |
| `host_name` | value of `host` | Name shown in alerts |
| `timezone` | `UTC` | |
| `ntfy_url` / `ntfy_topic` / `ntfy_token` | ntfy.sh / generated / none | Alert delivery |
| `grafana_admin_user` / `grafana_admin_password` | `admin` / generated | |
| `grafana_port` | `3000` | |
| `bind_address` | `0.0.0.0` | Where Grafana and OTLP listen |
| `admin_bind_address` | `127.0.0.1` | Where Prometheus and Alertmanager listen |
| `prometheus_retention_time` / `_size` | `15d` / `10GB` | |

## How it works

[`main.tf`](main.tf) uses two `terraform_data` resources:

- **`install`** lasts as long as the deployment. Its only job is to run
  `docker compose down` on `terraform destroy`.
- **`deploy`** is replaced whenever a stack file or a variable changes. That
  re-uploads the files and runs `docker compose up`, which only recreates the
  containers that changed.

Keeping them separate means a redeploy never takes the stack down first.

State is stored locally in `terraform/terraform.tfstate`, which is ignored by
git. It holds the generated passwords, so keep it private. If you want remote
state, add a backend block.

The deployment is tested in CI by [`tests/terraform/run.sh`](../tests/terraform/run.sh)
against a throwaway SSH + Docker container.
