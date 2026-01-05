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
    # Fixed filename to compose.yaml and used path.module for reliability
    compose_hash = filemd5("${path.module}/../compose.yaml")
    project_name = var.project_name
  }

  provisioner "local-exec" {
    # Using path.module to ensure we target the root compose file correctly
    command = "docker compose -p ${self.triggers.project_name} -f ${path.module}/../compose.yaml up -d --remove-orphans"
    environment = {
      GRAFANA_ADMIN_USER     = "admin"
      GRAFANA_ADMIN_PASSWORD = "admin"
    }
  }

  provisioner "local-exec" {
    when    = destroy
    # Fixed filename to compose.yaml for the destroy provisioner
    command = "docker compose -p ${self.triggers.project_name} -f ${path.module}/../compose.yaml down -v"
  }
}

resource "null_resource" "post_deploy_check" {
  depends_on = [null_resource.monitoring_stack]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    # Corrected path to the smoke test script in the project root
    command = <<EOT
      echo "Waiting for Grafana (port 3000) to open..."
      for i in {1..30}; do
        if nc -z localhost 3000; then
          echo "Grafana is up! Running smoke tests..."
          sleep 5
          python3 ${path.module}/../monitoring_smoke_test.py
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
