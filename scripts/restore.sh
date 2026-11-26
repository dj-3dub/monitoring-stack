#!/usr/bin/env bash
# Restores a backup made by scripts/backup.sh. This REPLACES the current data
# volumes and .env (the current .env is kept as .env.before-restore).
#
# Usage: scripts/restore.sh <backup.tar.gz> [--yes]
set -euo pipefail

cd "$(dirname "$0")/.."
project=${COMPOSE_PROJECT_NAME:-monitoring-stack}
env_file=${COMPOSE_ENV_FILES:-.env}
tar_image=alpine:3.22

archive=${1:-}
[[ -f "$archive" ]] || { echo "Usage: $0 <backup.tar.gz> [--yes]" >&2; exit 1; }
archive=$(realpath "$archive")

if [[ "${2:-}" != "--yes" ]]; then
  read -r -p "This replaces all current monitoring data with the backup. Continue? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 1; }
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tar -xzf "$archive" -C "$work"

echo "==> Stopping the stack"
docker compose down

echo "==> Restoring settings"
if [[ -f "$env_file" ]]; then cp "$env_file" "$env_file.before-restore"; fi
cp "$work/.env" "$env_file" && chmod 600 "$env_file"
if compgen -G "$work/targets/*.yml" >/dev/null; then
  cp "$work"/targets/*.yml config/prometheus/targets/
fi

for file in "$work"/volumes/*.tar.gz; do
  [[ -e "$file" ]] || continue
  name=$(basename "$file" .tar.gz)
  volume="${project}_${name}"
  echo "==> Restoring volume $volume"
  # Same labels Compose uses, so it adopts the volume instead of warning.
  docker volume create \
    --label "com.docker.compose.project=$project" \
    --label "com.docker.compose.volume=$name" \
    "$volume" >/dev/null
  docker run --rm -v "$volume:/data" -v "$work/volumes:/backup:ro" "$tar_image" \
    sh -c "find /data -mindepth 1 -delete && tar -xzpf /backup/$(basename "$file") -C /data"
done

echo "==> Starting the stack"
docker compose up -d
echo "==> Restore complete."
