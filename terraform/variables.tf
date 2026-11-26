# --- Target host -------------------------------------------------------------

variable "host" {
  description = "Address of the Linux host to deploy to (IP or DNS name)."
  type        = string
}

variable "ssh_user" {
  description = "SSH user. Must be root or have passwordless sudo."
  type        = string
}

variable "ssh_port" {
  description = "SSH port on the target host."
  type        = number
  default     = 22
}

variable "ssh_private_key_path" {
  description = "Private key for SSH. Set to \"\" to use your running SSH agent instead."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "install_dir" {
  description = "Where the stack is installed on the target host."
  type        = string
  default     = "/opt/monitoring-stack"
}

variable "install_docker" {
  description = "Install Docker with Docker's official install script if it is missing."
  type        = bool
  default     = true
}

variable "remove_data_on_destroy" {
  description = "On `terraform destroy`, also delete the stored metrics, logs and dashboards."
  type        = bool
  default     = false
}

# --- Stack settings (written to .env on the host) ----------------------------

variable "host_name" {
  description = "Name shown in alerts. Defaults to the value of `host`."
  type        = string
  default     = ""
}

variable "timezone" {
  description = "Timezone, for example America/Chicago."
  type        = string
  default     = "UTC"
}

variable "ntfy_url" {
  description = "ntfy server. Use your own if you self-host ntfy."
  type        = string
  default     = "https://ntfy.sh"
}

variable "ntfy_topic" {
  description = "ntfy topic for alerts. Leave empty to generate a private random one."
  type        = string
  default     = ""
}

variable "ntfy_token" {
  description = "ntfy access token, for protected topics on a self-hosted server."
  type        = string
  default     = ""
  sensitive   = true
}

variable "grafana_admin_user" {
  description = "Grafana admin username."
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password. Leave empty to generate one."
  type        = string
  default     = ""
  sensitive   = true
}

variable "grafana_port" {
  description = "Port Grafana is published on."
  type        = number
  default     = 3000
}

variable "bind_address" {
  description = "Address Grafana and the OTLP ports listen on."
  type        = string
  default     = "0.0.0.0"
}

variable "admin_bind_address" {
  description = "Address Prometheus and Alertmanager (no login) listen on."
  type        = string
  default     = "127.0.0.1"
}

variable "prometheus_retention_time" {
  description = "How long Prometheus keeps metrics."
  type        = string
  default     = "15d"
}

variable "prometheus_retention_size" {
  description = "Maximum disk space for Prometheus metrics."
  type        = string
  default     = "10GB"
}
