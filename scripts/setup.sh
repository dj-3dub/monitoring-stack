#!/usr/bin/env bash
# First-time setup: checks Docker, creates .env and fills in generated secrets.
# Safe to run again; it never overwrites a value that is already set.
set -euo pipefail

cd "$(dirname "$0")/.."

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# --- Docker ------------------------------------------------------------------
command -v docker >/dev/null || die "Docker is not installed. See https://docs.docker.com/engine/install/"
docker compose version >/dev/null 2>&1 || die "Docker Compose v2 is missing (the 'docker compose' command)."
docker info >/dev/null 2>&1 || die "Can't talk to Docker. Is it running, and is your user in the 'docker' group?"

# --- .env --------------------------------------------------------------------
if [[ ! -f .env ]]; then
  cp .env.example .env
  info "Created .env from .env.example"
fi
chmod 600 .env

get_env() { sed -n "s/^$1=//p" .env | tail -n 1; }

set_env() {
  if grep -q "^$1=" .env; then
    sed -i.bak "s|^$1=.*|$1=$2|" .env && rm -f .env.bak
  else
    printf '%s=%s\n' "$1" "$2" >> .env
  fi
}

random_string() { head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c "1-$1"; }

host_name=$(get_env HOST_NAME)
if [[ -z "$host_name" || "$host_name" == "my-server" ]]; then
  host_name=$(hostname -s 2>/dev/null || hostname)
  set_env HOST_NAME "$host_name"
  info "HOST_NAME set to $host_name"
fi

if [[ -z "$(get_env NTFY_TOPIC)" ]]; then
  # ntfy.sh topics are public: a long random name keeps alerts private.
  topic="alerts-$(printf '%s' "$host_name" | tr -cd 'A-Za-z0-9-' | cut -c 1-20)-$(random_string 16)"
  set_env NTFY_TOPIC "$topic"
  info "Generated a private ntfy topic"
fi

if [[ -z "$(get_env GRAFANA_ADMIN_PASSWORD)" ]]; then
  set_env GRAFANA_ADMIN_PASSWORD "$(random_string 24)"
  info "Generated a Grafana admin password"
fi

# --- Firewall hint -----------------------------------------------------------
# node-exporter listens on the host network; Prometheus reaches it from the
# Docker bridge. A default-deny host firewall blocks that.
if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
  warn "UFW is active. If the local host shows as down, allow Docker to reach node-exporter:"
  warn "  sudo ufw allow from 172.16.0.0/12 to any port 9100 proto tcp"
fi

# --- Summary -----------------------------------------------------------------
ntfy_url=$(get_env NTFY_URL); ntfy_url=${ntfy_url:-https://ntfy.sh}
cat <<SUMMARY

Setup complete. Next steps:

  1. Subscribe to alerts in the ntfy app (or browser):
       ${ntfy_url%/}/$(get_env NTFY_TOPIC)
  2. Start the stack:            make up
  3. Send a test notification:   make test-alert
  4. Open Grafana:               http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo localhost):$(get_env GRAFANA_PORT)
       user: $(get_env GRAFANA_ADMIN_USER)   password: in .env (GRAFANA_ADMIN_PASSWORD)

SUMMARY
