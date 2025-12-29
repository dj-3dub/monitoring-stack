# ===== Monitoring Stack Makefile (Fixed Shell Path) =====
.RECIPEPREFIX := >
# Using a more universal path for bash
SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

# ---- Paths & Config ----
STACK_DIR   ?= $(CURDIR)
TERRAFORM_DIR := $(STACK_DIR)/terraform
COMPOSE_FILES := -f $(STACK_DIR)/docker-compose.yml

# Env vars for Docker and Grafana API
export GRAFANA_ADMIN_USER ?= admin
export GRAFANA_ADMIN_PASSWORD ?= admin

DC := docker compose $(COMPOSE_FILES)

# ---- Grafana API config ----
GRAFANA_URL ?= http://localhost:3000
GRAFANA_FOLDER ?= Monitoring Stack

# Dashboard IDs
DASH_NODE_EXPORTER ?= 1860
DASH_DOCKER        ?= 193
DASH_BLACKBOX      ?= 7587

# =========================
# Terraform Lifecycle
# =========================
.PHONY: tf-init tf-up tf-down tf-status smoke-test

tf-init:
> terraform -chdir=$(TERRAFORM_DIR) init

tf-up:
> @echo "Deploying stack via Terraform..."
> terraform -chdir=$(TERRAFORM_DIR) apply -auto-approve
> @$(MAKE) smoke-test

tf-down:
> @echo "Destroying stack via Terraform..."
> terraform -chdir=$(TERRAFORM_DIR) destroy -auto-approve

tf-status:
> terraform -chdir=$(TERRAFORM_DIR) show

smoke-test:
> @echo "Running monitoring smoke tests..."
> python3 $(STACK_DIR)/monitoring_smoke_test.py --retries 15 --sleep 3

# =========================
# Basic Docker targets
# =========================
.PHONY: up ps logs restart down status
up:
> $(DC) up -d

ps:
> $(DC) ps

logs:
> $(DC) logs -f

restart:
> $(DC) restart

down:
> $(DC) down

status: ps targets

# =========================
# Prometheus helpers
# =========================
.PHONY: reload-prom targets rules
reload-prom:
> echo "Reloading Prometheus config..."
> $(DC) exec -T prometheus wget -qO- --post-data '' 'http://localhost:9090/-/reload' >/dev/null || true
> echo "Prometheus reloaded."

targets:
> echo "Active Prometheus targets:"
> $(DC) exec -T prometheus wget -qO- 'http://localhost:9090/api/v1/targets' | jq -r '.data.activeTargets[] | " - \(.labels.job) / \(.labels.instance): \(.health)"'

rules:
> echo "Loaded Prometheus rule groups:"
> $(DC) exec -T prometheus wget -qO- 'http://localhost:9090/api/v1/rules' | jq -r '.data.groups[]?.name' | sed 's/^/ - /' || true

# =========================
# Blackbox Exporter wiring
# =========================
.PHONY: blackbox-setup
blackbox-setup:
> mkdir -p "$(STACK_DIR)/config/blackbox"
> if [ ! -f "$(STACK_DIR)/config/blackbox/blackbox.yml" ]; then
> echo "modules:" > "$(STACK_DIR)/config/blackbox/blackbox.yml"
> echo "  http_2xx:" >> "$(STACK_DIR)/config/blackbox/blackbox.yml"
> echo "    prober: http" >> "$(STACK_DIR)/config/blackbox/blackbox.yml"
> echo "    timeout: 5s" >> "$(STACK_DIR)/config/blackbox/blackbox.yml"
> echo "    http:" >> "$(STACK_DIR)/config/blackbox/blackbox.yml"
> echo "      method: GET" >> "$(STACK_DIR)/config/blackbox/blackbox.yml"
> echo "      preferred_ip_protocol: \"ip4\"" >> "$(STACK_DIR)/config/blackbox/blackbox.yml"
> echo "  icmp:" >> "$(STACK_DIR)/config/blackbox/blackbox.yml"
> echo "    prober: icmp" >> "$(STACK_DIR)/config/blackbox/blackbox.yml"
> echo "    timeout: 5s" >> "$(STACK_DIR)/config/blackbox/blackbox.yml"
> echo "Wrote blackbox.yml"
> fi
> $(DC) up -d blackbox
> $(MAKE) reload-prom

# =========================
# Grafana helpers
# =========================
.PHONY: grafana-health grafana-clean-victoria grafana-import-node grafana-import-docker grafana-import-blackbox grafana-move-core dashboards-tidy grafana-folder-id

grafana-health:
> curl -sS -u "$(GRAFANA_ADMIN_USER):$(GRAFANA_ADMIN_PASSWORD)" "$(GRAFANA_URL)/api/health" | jq .

grafana-folder-id:
> tmpdir="$$(mktemp -d)"; trap 'rm -rf "$$tmpdir"' EXIT
> curl -sS -u "$(GRAFANA_ADMIN_USER):$(GRAFANA_ADMIN_PASSWORD)" "$(GRAFANA_URL)/api/folders" >"$$tmpdir/folders.json"
> fid="$$(jq -r --arg name '$(GRAFANA_FOLDER)' '.[] | select(.title==$$name) | .id' "$$tmpdir/folders.json" | head -n1)"
> if [[ -z "$$fid" || "$$fid" == "null" ]]; then
> echo '{"title":"$(GRAFANA_FOLDER)"}' >"$$tmpdir/create.json"
> curl -sS -u "$(GRAFANA_ADMIN_USER):$(GRAFANA_ADMIN_PASSWORD)" -H "Content-Type: application/json" -X POST --data-binary "@$$tmpdir/create.json" "$(GRAFANA_URL)/api/folders" >"$$tmpdir/resp.json"
> fid="$$(jq -r '.id' "$$tmpdir/resp.json")"
> echo "Created folder id=$$fid"
> else
> echo "Folder exists id=$$fid"
> fi
> echo "$$fid"

grafana-clean-victoria:
> echo "Removing old VictoriaMetrics dashboards..."
> curl -sS -u "$(GRAFANA_ADMIN_USER):$(GRAFANA_ADMIN_PASSWORD)" "$(GRAFANA_URL)/api/search?type=dash-db&query=" | jq -r '.[] | select(.title=="Level0 VictoriaMetrics Overview") | .uid' | while read -r u; do [ -z "$$u" ] && continue; curl -sS -u "$(GRAFANA_ADMIN_USER):$(GRAFANA_ADMIN_PASSWORD)" -X DELETE "$(GRAFANA_URL)/api/dashboards/uid/$$u" >/dev/null || true; done
> echo "Done."

grafana-import-node:
> tmp="$$(mktemp -d)"; trap 'rm -rf "$$tmp"' EXIT
> curl -fsSL "https://grafana.com/api/dashboards/$(DASH_NODE_EXPORTER)/revisions/latest/download" > "$$tmp/model.json"
> jq '{dashboard: ., overwrite: true, folderId: 0}' "$$tmp/model.json" > "$$tmp/payload.json"
> curl -sS -u "$(GRAFANA_ADMIN_USER):$(GRAFANA_ADMIN_PASSWORD)" -H "Content-Type: application/json" -X POST --data-binary "@$$tmp/payload.json" "$(GRAFANA_URL)/api/dashboards/db" >/dev/null
> echo "Imported Node Exporter Full"

grafana-import-docker:
> tmp="$$(mktemp -d)"; trap 'rm -rf "$$tmp"' EXIT
> curl -fsSL "https://grafana.com/api/dashboards/$(DASH_DOCKER)/revisions/latest/download" > "$$tmp/model.json"
> jq '{dashboard: ., overwrite: true, folderId: 0}' "$$tmp/model.json" > "$$tmp/payload.json"
> curl -sS -u "$(GRAFANA_ADMIN_USER):$(GRAFANA_ADMIN_PASSWORD)" -H "Content-Type: application/json" -X POST --data-binary "@$$tmp/payload.json" "$(GRAFANA_URL)/api/dashboards/db" >/dev/null
> echo "Imported Docker / cAdvisor"

grafana-import-blackbox:
> tmp="$$(mktemp -d)"; trap 'rm -rf "$$tmp"' EXIT
> curl -fsSL "https://grafana.com/api/dashboards/$(DASH_BLACKBOX)/revisions/latest/download" > "$$tmp/model.json"
> jq '{dashboard: ., overwrite: true, folderId: 0}' "$$tmp/model.json" > "$$tmp/payload.json"
> curl -sS -u "$(GRAFANA_ADMIN_USER):$(GRAFANA_ADMIN_PASSWORD)" -H "Content-Type: application/json" -X POST --data-binary "@$$tmp/payload.json" "$(GRAFANA_URL)/api/dashboards/db" >/dev/null
> echo "Imported Blackbox Exporter"

grafana-move-core:
> fid="$$( $(MAKE) -s grafana-folder-id | tail -n1 )"
> echo "Moving dashboards into folder ID $$fid..."
> move() { title="$$1"; q="$$(jq -rn --arg x "$$title" '$$x|@uri')"; tmp="$$(mktemp -d)"; trap 'rm -rf "$$tmp"' RETURN; curl -sS -u "$(GRAFANA_ADMIN_USER):$(GRAFANA_ADMIN_PASSWORD)" "$(GRAFANA_URL)/api/search?type=dash-db&query=$$q" >"$$tmp/s.json"; duid="$$(jq -r --arg t "$$title" '.[] | select(.title==$$t) | .uid' "$$tmp/s.json" | head -n1)"; if [[ -z "$$duid" || "$$duid" == "null" ]]; then echo "Not found: $$title"; return 0; fi; curl -sS -u "$(GRAFANA_ADMIN_USER):$(GRAFANA_ADMIN_PASSWORD)" "$(GRAFANA_URL)/api/dashboards/uid/$$duid" >"$$tmp/dash.json"; jq '.dashboard' "$$tmp/dash.json" >"$$tmp/model.json"; jq -n --slurpfile m "$$tmp/model.json" --argjson folderId "$$fid" '{dashboard: $$m[0], overwrite: true, folderId: $$folderId}' >"$$tmp/payload.json"; curl -sS -u "$(GRAFANA_ADMIN_USER):$(GRAFANA_ADMIN_PASSWORD)" -H "Content-Type: application/json" -X POST --data-binary "@$$tmp/payload.json" "$(GRAFANA_URL)/api/dashboards/db" >/dev/null; echo "✓ Moved $$title"; }
> move "Docker monitoring"
> move "Node Exporter Full"
> move "Containers Overview"
> move "Node / Host Overview"

dashboards-tidy: grafana-clean-victoria grafana-import-node grafana-import-docker grafana-import-blackbox grafana-move-core
> echo "Dashboards tidied."
