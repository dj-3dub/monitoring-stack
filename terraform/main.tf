terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }
}

variable "project_root" {
  type    = string
  default = ".."
}

variable "project_name" {
  type    = string
  default = "monitoring-stack"
}

resource "null_resource" "monitoring_stack" {
  triggers = {
    compose_hash = filemd5("${abspath(var.project_root)}/docker-compose.yml")
    project_name = var.project_name
  }

  provisioner "local-exec" {
    command = "docker compose -p ${self.triggers.project_name} -f ${abspath(var.project_root)}/docker-compose.yml up -d --remove-orphans"
    environment = {
      GRAFANA_ADMIN_USER     = "admin"
      GRAFANA_ADMIN_PASSWORD = "admin"
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "docker compose -p ${self.triggers.project_name} -f ${abspath(path.module)}/../docker-compose.yml down -v"
  }
}

resource "null_resource" "post_deploy_check" {
  depends_on = [null_resource.monitoring_stack]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    # This loop checks port 3000 every 2 seconds for up to 60 seconds.
    # It proceeds immediately once the port is open.
    command = <<EOT
      echo "Waiting for Grafana (port 3000) to open..."
      for i in {1..30}; do
        if nc -z localhost 3000; then
          echo "Grafana is up! Running smoke tests..."
          sleep 5
          python3 ${abspath(var.project_root)}/monitoring_smoke_test.py
          exit 0
        fi
        echo "Still waiting... ($i/30)"
        sleep 2
      done
      echo "Grafana failed to start in time."
      exit 1
    EOT
  }
}
