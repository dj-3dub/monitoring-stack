# monitoring-stack: run `make` for the list of commands.

SHELL := /bin/bash
COMPOSE := docker compose

# Tool images, used when the tool isn't installed locally (and always in CI).
TERRAFORM_IMAGE  := hashicorp/terraform:1.17.2
PROMETHEUS_IMAGE := prom/prometheus:v3.16.0
SHELLCHECK_IMAGE := koalaman/shellcheck:v0.11.0

# Use local Terraform if installed, otherwise run it in a container with your
# SSH keys (read-only) and SSH agent available.
ifneq ($(shell command -v terraform 2>/dev/null),)
TERRAFORM := terraform -chdir=terraform
else
TERRAFORM := docker run --rm -i $(shell [ -t 0 ] && echo -t) \
	--user $(shell id -u):$(shell id -g) \
	-e HOME=/home/terraform \
	-v "$(HOME)/.ssh:/home/terraform/.ssh:ro" \
	$(if $(SSH_AUTH_SOCK),-v "$(SSH_AUTH_SOCK):/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent) \
	-v "$(CURDIR):/workspace" -w /workspace/terraform \
	$(TERRAFORM_IMAGE)
endif

.DEFAULT_GOAL := help
.PHONY: help setup up down restart logs status pull update test-alert \
	backup restore \
	tf-init tf-plan tf-apply tf-destroy tf-output \
	lint test test-rules test-e2e test-terraform

help: ## Show this list
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2} /^## / {printf "\n%s\n", substr($$0, 4)}' $(MAKEFILE_LIST)

## Run the stack on this machine
setup: ## Create .env with generated secrets (safe to re-run)
	@scripts/setup.sh

up: ## Start the stack
	$(COMPOSE) up -d

down: ## Stop the stack (data is kept)
	$(COMPOSE) down

restart: ## Restart all services
	$(COMPOSE) restart

logs: ## Follow logs from all services
	$(COMPOSE) logs -f --tail=100

status: ## Show service status and health
	$(COMPOSE) ps

pull: ## Download the image versions in compose.yaml
	$(COMPOSE) pull

update: pull ## Pull images and recreate changed services
	$(COMPOSE) up -d --remove-orphans

test-alert: ## Send a test notification to your ntfy topic
	@scripts/test-alert.sh

## Backups
backup: ## Back up settings and all data to ./backups
	@scripts/backup.sh

restore: ## Restore a backup: make restore FILE=backups/<file>.tar.gz
	@test -n "$(FILE)" || { echo "Usage: make restore FILE=backups/<file>.tar.gz"; exit 1; }
	@scripts/restore.sh "$(FILE)"

## Deploy to another machine with Terraform (see terraform/README.md)
tf-init: ## Download Terraform providers
	$(TERRAFORM) init

tf-plan: ## Preview a deployment
	$(TERRAFORM) plan

tf-apply: ## Deploy or update the stack on the remote host
	$(TERRAFORM) apply

tf-destroy: ## Stop the stack on the remote host (its data is kept)
	$(TERRAFORM) destroy

tf-output: ## Show Grafana URL, password and ntfy topic for the deployment
	@$(TERRAFORM) output
	@echo "grafana_admin_password = $$($(TERRAFORM) output -raw grafana_admin_password)"
	@echo "ntfy_subscribe_url = $$($(TERRAFORM) output -raw ntfy_subscribe_url)"

## Checks (the same ones CI runs)
lint: ## Validate every config file and lint the shell scripts
	@tests/lint.sh

test-rules: ## Unit-test the alert rules
	docker run --rm -v "$(CURDIR):/w:ro" -w /w/tests/rules --entrypoint promtool $(PROMETHEUS_IMAGE) test rules alerts.test.yml

test: lint test-rules ## Run lint and the alert rule tests

test-e2e: ## Start a throwaway copy of the stack and check alerts are delivered (~6 min)
	@tests/e2e.sh

test-terraform: ## Deploy with Terraform to a throwaway SSH host container (~5 min)
	@tests/terraform/run.sh
