#!/usr/bin/env bash
# Runs on the target host (uploaded by Terraform). Installs Docker if needed,
# moves the uploaded stack into place and starts it.
# Usage: deploy.sh <staging-dir> <install-dir> <install-docker: true|false>
set -euo pipefail

staging=$1
install_dir=$2
install_docker=$3

SUDO=""
if [[ $(id -u) -ne 0 ]]; then
  sudo -n true 2>/dev/null || { echo "error: $(whoami) needs passwordless sudo" >&2; exit 1; }
  SUDO="sudo -n"
fi

if ! command -v docker >/dev/null; then
  if [[ $install_docker != true ]]; then
    echo "error: Docker is not installed and install_docker = false" >&2
    exit 1
  fi
  echo "==> Installing Docker with Docker's official install script"
  curl -fsSL https://get.docker.com | $SUDO sh
  $SUDO systemctl enable --now docker
fi

$SUDO docker compose version >/dev/null 2>&1 || { echo "error: Docker Compose v2 is missing" >&2; exit 1; }

echo "==> Installing the stack to $install_dir"
$SUDO mkdir -p "$install_dir"
# Replace config and scripts wholesale so deleted files don't linger.
# Data lives in Docker volumes, not in this folder.
$SUDO rm -rf "$install_dir/config" "$install_dir/scripts"
$SUDO cp -a "$staging/compose.yaml" "$staging/config" "$staging/scripts" "$staging/.env" "$install_dir/"
$SUDO chown -R root:root "$install_dir"
$SUDO chmod 600 "$install_dir/.env"
rm -rf "$staging"

echo "==> Starting the stack"
cd "$install_dir"
# Retry: one slow registry download shouldn't fail the whole deploy.
for attempt in 1 2 3; do
  $SUDO docker compose pull --quiet && break
  [[ $attempt -lt 3 ]] || { echo "error: could not download images" >&2; exit 1; }
  echo "==> Image download failed; retrying ($attempt/3)"
  sleep 10
done
$SUDO docker compose up -d --remove-orphans --wait --wait-timeout 300
$SUDO docker compose ps
