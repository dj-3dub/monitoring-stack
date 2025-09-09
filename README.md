# Homelab (Pi-hole · Caddy · Homepage)

Reusable Docker stack + backup/restore tooling.

## What’s inside
- **compose/** – Docker Compose for Homepage and Pi-hole + Caddy
- **configs/** – redacted example configs (copy & edit for your env)
- **scripts/** – automation:
  - `homelab-backup.sh` / `homelab-restore.sh` – snapshot named volumes, bind mounts, images list
  - `make-backup-image.sh` – bake a single Docker image that contains your backup bundle
  - `inspect_backup_image.py` – verify exactly what the backup captured
  - `auto_patch_backup.py` – ensure Pi-hole binds `/etc/pihole` and `/etc/dnsmasq.d` are included
  - `add_adlists.py` – programmatically add OISD Big + extras to Pi-hole (Docker-safe)

## Quickstart (demo)
```bash
<<<<<<< HEAD
# use .env.example as a template
docker compose -f compose/homepage/docker-compose.yml --env-file .env.example up -d
docker compose -f compose/pihole-caddy/docker-compose.yml --env-file .env.example up -d
```
=======
cd ~/monitoring-stack
cp .env.sample .env
# edit .env: admin creds, TZ=America/Chicago, domain names (if using Traefik)

docker compose pull
docker compose up -d


Built by Tim Heverin (dj-3dub). If this project is useful, ⭐ the repo and say hi on GitHub.
