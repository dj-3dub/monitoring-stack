#!/usr/bin/env bash
# Validates every config file with the same tool versions the stack runs.
# Used by `make lint` and CI. Needs only Docker.
set -euo pipefail

cd "$(dirname "$0")/.."
root=$PWD

image() { sed -n "s|^ *image: *\(.*$1.*\)|\1|p" compose.yaml | head -n 1; }
PROMETHEUS=$(image prom/prometheus)
ALERTMANAGER=$(image prom/alertmanager)
LOKI=$(image grafana/loki)
OTEL=$(image otel/opentelemetry-collector-contrib)
TERRAFORM=$(sed -n 's/^TERRAFORM_IMAGE *:= *//p' Makefile)
SHELLCHECK=$(sed -n 's/^SHELLCHECK_IMAGE *:= *//p' Makefile)

failed=0
check() {
  local name=$1; shift
  if output=$("$@" 2>&1); then
    printf '  \033[32mok\033[0m    %s\n' "$name"
  else
    printf '  \033[31mFAIL\033[0m  %s\n%s\n' "$name" "$output"
    failed=1
  fi
}

echo "Checking configuration:"

check "compose.yaml" env GRAFANA_ADMIN_PASSWORD=x NTFY_TOPIC=x \
  docker compose -f compose.yaml config --quiet

check "prometheus config and rules" docker run --rm \
  -v "$root/config/prometheus:/etc/prometheus:ro" \
  --entrypoint promtool "$PROMETHEUS" check config /etc/prometheus/prometheus.yml

check "alertmanager config (rendered)" docker run --rm -e NTFY_TOPIC=lint -e NTFY_TOKEN=tk_lint \
  -v "$root/config/alertmanager:/etc/alertmanager:ro" \
  --entrypoint /bin/sh "$ALERTMANAGER" -c \
  'sh /etc/alertmanager/entrypoint.sh --version >/dev/null && amtool check-config /tmp/alertmanager.yml'

check "otel collector config" docker run --rm \
  -v "$root/config/otel/otel-collector-config.yml:/config.yml:ro" \
  "$OTEL" validate --config=/config.yml

check "loki config" docker run --rm \
  -v "$root/config/loki/loki.yml:/loki.yml:ro" \
  "$LOKI" -config.file=/loki.yml -verify-config

for f in config/grafana/provisioning/dashboards/*.json; do
  check "dashboard $(basename "$f")" python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f"
done

check "terraform fmt" docker run --rm -v "$root/terraform:/tf:ro" -w /tf "$TERRAFORM" fmt -check -recursive

# Terraform reads the stack files it deploys, so validate it inside a copy of the repo.
check "terraform validate" docker run --rm -v "$root:/src:ro" --entrypoint /bin/sh "$TERRAFORM" -c \
  'cp -r /src /tmp/repo && cd /tmp/repo/terraform && rm -rf .terraform && terraform init -backend=false -input=false >/dev/null && terraform validate'

mapfile -t scripts < <(find . -name '*.sh' -not -path './.git/*' -not -path './terraform/.terraform/*' | sort)
check "shellcheck (${#scripts[@]} scripts)" docker run --rm -v "$root:/mnt:ro" -w /mnt "$SHELLCHECK" "${scripts[@]}"

exit "$failed"
