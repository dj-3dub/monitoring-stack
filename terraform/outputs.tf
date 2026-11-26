output "grafana_url" {
  description = "Grafana web UI."
  value       = "http://${var.host}:${var.grafana_port}"
}

output "grafana_admin_user" {
  description = "Grafana admin username."
  value       = var.grafana_admin_user
}

output "grafana_admin_password" {
  description = "Grafana admin password. Show it with: terraform output -raw grafana_admin_password"
  value       = local.grafana_admin_password
  sensitive   = true
}

output "ntfy_subscribe_url" {
  description = "Subscribe to this topic in the ntfy app to receive alerts."
  value       = "${trimsuffix(var.ntfy_url, "/")}/${local.ntfy_topic}"
  sensitive   = true
}

output "install_dir" {
  description = "Where the stack lives on the host."
  value       = var.install_dir
}
