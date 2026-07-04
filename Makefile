# Cloud-Native Observability Platform Makefile
# Use tabs, not spaces, for command indentation.

SHELL := /bin/bash
COMPOSE := docker compose
BACKUP_DIR := backups
DATE := $(shell date +%Y%m%d-%H%M%S)

ANSIBLE_INVENTORY := ansible/inventory.ini
TERRAFORM_DIR := terraform/vsphere

.PHONY: help \
	up down restart logs status ps config validate pull update \
	automation-up automation-down \
	telemetry-up telemetry-down \
	ansible-monitoring ansible-node-exporter ansible-ping ansible-check \
	terraform-init terraform-plan terraform-apply terraform-destroy \
	platform-up \
	backup clean prune shell-grafana shell-prometheus \
	platform-up guard-source \

help:
	@echo ""
	@echo "Cloud-Native Observability Platform Commands"
	@echo ""
	@echo "Platform"
	@echo "--------"
	@echo "  make platform-up             Deploy full platform through Ansible"
	@echo ""
	@echo "Docker Runtime"
	@echo "--------------"
	@echo "  make up                      Start core monitoring stack"
	@echo "  make down                    Stop core monitoring stack"
	@echo "  make restart                 Restart stack"
	@echo "  make logs                    Follow logs"
	@echo "  make status                  Show container status and stats"
	@echo "  make ps                      Show compose services"
	@echo "  make config                  Render compose config"
	@echo "  make validate                Validate compose config"
	@echo "  make pull                    Pull latest images"
	@echo "  make update                  Pull and restart stack"
	@echo ""
	@echo "Automation"
	@echo "----------"
	@echo "  make automation-up           Start n8n automation profile"
	@echo "  make automation-down         Stop n8n"
	@echo ""
	@echo "Telemetry"
	@echo "---------"
	@echo "  make telemetry-up            Start OTel Collector and Tempo"
	@echo "  make telemetry-down          Stop OTel Collector and Tempo"
	@echo ""
	@echo "Ansible"
	@echo "-------"
	@echo "  make ansible-ping            Test Ansible connectivity"
	@echo "  make ansible-check           Dry-run monitoring playbook"
	@echo "  make ansible-monitoring      Configure monitoring server"
	@echo "  make ansible-node-exporter   Configure monitored hosts"
	@echo ""
	@echo "Terraform"
	@echo "---------"
	@echo "  make terraform-init          Initialize Terraform"
	@echo "  make terraform-plan          Show Terraform plan"
	@echo "  make terraform-apply         Apply Terraform changes"
	@echo "  make terraform-destroy       Destroy Terraform resources"
	@echo ""
	@echo "Maintenance"
	@echo "-----------"
	@echo "  make backup                  Backup configs"
	@echo "  make clean                   Remove stopped containers"
	@echo "  make prune                   Docker system prune"
	@echo ""

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f --tail=100

status:
	$(COMPOSE) ps
	@echo ""
	@docker stats --no-stream

ps:
	$(COMPOSE) ps

config:
	$(COMPOSE) config

validate:
	$(COMPOSE) --profile automation --profile telemetry config >/dev/null
	@echo "compose.yaml is valid."

pull:
	$(COMPOSE) --profile automation --profile telemetry pull

update: pull
	$(COMPOSE) --profile automation --profile telemetry up -d
	@echo "Monitoring platform updated."

automation-up:
	$(COMPOSE) --profile automation up -d n8n

automation-down:
	$(COMPOSE) stop n8n

telemetry-up:
	$(COMPOSE) --profile telemetry up -d otel-collector tempo

telemetry-down:
	$(COMPOSE) stop otel-collector tempo

ansible-ping:
	ansible -i $(ANSIBLE_INVENTORY) all -m ping

ansible-check:
	ansible-playbook -i $(ANSIBLE_INVENTORY) ansible/monitoring.yml --check

ansible-monitoring:
	ansible-playbook -i $(ANSIBLE_INVENTORY) ansible/monitoring.yml

ansible-node-exporter:
	ansible-playbook -i $(ANSIBLE_INVENTORY) ansible/node-exporter.yml

terraform-init:
	cd $(TERRAFORM_DIR) && terraform init

terraform-plan:
	cd $(TERRAFORM_DIR) && terraform plan

terraform-apply:
	cd $(TERRAFORM_DIR) && terraform apply

terraform-destroy:
	cd $(TERRAFORM_DIR) && terraform destroy

guard-source:
	@if [ "$$(pwd)" = "/opt/monitoring" ]; then \
		echo "ERROR: Do not run Make from /opt/monitoring."; \
		echo "Run from ~/monitoring-stack instead."; \
		exit 1; \
	fi

platform-up: guard-source ansible-monitoring
	@echo "Platform deployed through Ansible."

backup:
	@mkdir -p $(BACKUP_DIR)
	@tar -czf $(BACKUP_DIR)/monitoring-config-$(DATE).tar.gz \
		compose.yaml \
		Makefile \
		.env \
		config \
		ansible \
		terraform \
		scripts \
		tools \
		docs
	@echo "Backup created: $(BACKUP_DIR)/monitoring-config-$(DATE).tar.gz"

clean:
	docker container prune -f

prune:
	docker system prune -f

shell-grafana:
	$(COMPOSE) exec grafana /bin/sh

shell-prometheus:
	$(COMPOSE) exec prometheus /bin/sh
