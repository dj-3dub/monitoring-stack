# Deploys this repository's Docker Compose stack to a Linux host over SSH.
#
# compose.yaml stays the single definition of the stack: Terraform copies the
# working copy (compose.yaml, config/, scripts/) to the host, writes .env from
# your variables, and runs `docker compose up`. Any change to those files or
# variables triggers a redeploy on the next `terraform apply`.

resource "random_password" "grafana" {
  length  = 24
  special = false
}

resource "random_id" "ntfy_topic" {
  byte_length = 12
}

locals {
  repo_root = abspath("${path.module}/..")
  staging   = "/tmp/monitoring-stack-deploy"

  host_name              = var.host_name != "" ? var.host_name : var.host
  ntfy_topic             = var.ntfy_topic != "" ? var.ntfy_topic : "alerts-${random_id.ntfy_topic.hex}"
  grafana_admin_password = var.grafana_admin_password != "" ? var.grafana_admin_password : random_password.grafana.result

  env_file = templatefile("${path.module}/templates/env.tftpl", {
    host_name                 = local.host_name
    timezone                  = var.timezone
    ntfy_url                  = trimsuffix(var.ntfy_url, "/")
    ntfy_topic                = local.ntfy_topic
    ntfy_token                = var.ntfy_token
    grafana_admin_user        = var.grafana_admin_user
    grafana_admin_password    = local.grafana_admin_password
    bind_address              = var.bind_address
    admin_bind_address        = var.admin_bind_address
    grafana_port              = var.grafana_port
    prometheus_retention_time = var.prometheus_retention_time
    prometheus_retention_size = var.prometheus_retention_size
  })

  # Every file that is copied to the host. A change to any of them redeploys.
  stack_files = sort(concat(
    ["compose.yaml"],
    tolist(fileset(local.repo_root, "config/**")),
    tolist(fileset(local.repo_root, "scripts/*.sh")),
  ))
  stack_hash = sha256(join("", [for f in local.stack_files : filesha256("${local.repo_root}/${f}")]))

  connection = {
    host     = var.host
    user     = var.ssh_user
    port     = var.ssh_port
    key_path = var.ssh_private_key_path
  }
}

# Represents the installed stack for its whole lifetime. Its only job is to
# stop the stack on `terraform destroy`. It is kept separate from the deploy
# below so that a redeploy doesn't take the stack down first.
resource "terraform_data" "install" {
  input = merge(local.connection, {
    install_dir = var.install_dir
    remove_data = var.remove_data_on_destroy
  })

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "cd '${self.input.install_dir}' 2>/dev/null || exit 0",
      "SUDO=$([ \"$(id -u)\" -eq 0 ] || echo 'sudo -n')",
      "$SUDO docker compose down ${self.input.remove_data ? "--volumes" : ""}",
      self.input.remove_data ? "cd / && $SUDO rm -rf '${self.input.install_dir}'" : "true",
    ]

    connection {
      type        = "ssh"
      host        = self.input.host
      user        = self.input.user
      port        = self.input.port
      private_key = self.input.key_path != "" ? file(pathexpand(self.input.key_path)) : null
      agent       = self.input.key_path == ""
    }
  }
}

resource "terraform_data" "deploy" {
  depends_on = [terraform_data.install]

  triggers_replace = {
    stack = local.stack_hash
    env   = sha256(local.env_file)
    host  = var.host
    dir   = var.install_dir
  }

  connection {
    type        = "ssh"
    host        = var.host
    user        = var.ssh_user
    port        = var.ssh_port
    private_key = var.ssh_private_key_path != "" ? file(pathexpand(var.ssh_private_key_path)) : null
    agent       = var.ssh_private_key_path == ""
  }

  # Private staging folder: .env holds secrets.
  provisioner "remote-exec" {
    inline = ["rm -rf ${local.staging} && mkdir -m 700 ${local.staging}"]
  }

  provisioner "file" {
    source      = "${local.repo_root}/compose.yaml"
    destination = "${local.staging}/compose.yaml"
  }

  provisioner "file" {
    source      = "${local.repo_root}/config"
    destination = local.staging
  }

  provisioner "file" {
    source      = "${local.repo_root}/scripts"
    destination = local.staging
  }

  provisioner "file" {
    content     = local.env_file
    destination = "${local.staging}/.env"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/deploy.sh"
    destination = "${local.staging}/deploy.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "bash ${local.staging}/deploy.sh '${local.staging}' '${var.install_dir}' '${var.install_docker}'",
    ]
  }
}
