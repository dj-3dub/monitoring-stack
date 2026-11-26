#!/usr/bin/env bash
# Backs up this stack: .env, your target list, and the data volumes
# (Grafana dashboards and users, Prometheus metrics, Alertmanager silences).
# Services are stopped briefly so the copy is consistent.
#
# Usage: scripts/backup.sh [output-dir]    (default: ./backups)
set -euo pipefail

cd "$(dirname "$0")/.."
project=${COMPOSE_PROJECT_NAME:-monitoring-stack}
env_file=${COMPOSE_ENV_FILES:-.env}
tar_image=alpine:3.22
out_dir=$(realpath -m "${1:-backups}")
stamp=$(date +%Y%m%d-%H%M%S)
archive="$out_dir/$project-$(hostname -s)-$stamp.tar.gz"

work=$(mktemp -d)
running=()
cleanup() {
  if ((${#running[@]})); then
    echo "==> Starting services again"
    docker compose start "${running[@]}" >/dev/null
  fi
  rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$out_dir" "$work/volumes"

echo "==> Saving settings"
cp "$env_file" "$work/.env"
mkdir -p "$work/targets"
cp config/prometheus/targets/*.yml "$work/targets/" 2>/dev/null || true

mapfile -t running < <(docker compose ps --services --status running)
if ((${#running[@]})); then
  echo "==> Stopping services: ${running[*]}"
  docker compose stop "${running[@]}" >/dev/null
fi

mapfile -t volumes < <(docker volume ls -q --filter "label=com.docker.compose.project=$project")
for volume in "${volumes[@]}"; do
  echo "==> Backing up volume $volume"
  docker run --rm -v "$volume:/data:ro" -v "$work/volumes:/backup" "$tar_image" \
    tar -czf "/backup/${volume#"${project}"_}.tar.gz" -C /data .
done

tar -czf "$archive" -C "$work" .
chmod 600 "$archive"
echo "==> Backup written to $archive"
echo "    It contains your .env secrets; store it somewhere safe."
