#!/usr/bin/env bash
# End-to-end test: starts a throwaway copy of the stack next to a local ntfy
# server and checks that metrics, logs, traces, alerts, and backup/restore all
# work. Takes about 6 minutes, mostly waiting for alert timers.
set -euo pipefail

cd "$(dirname "$0")/.."

export COMPOSE_PROJECT_NAME=monitoring-stack-e2e
export COMPOSE_FILE=compose.yaml:tests/compose.e2e.yaml
env_file=$(mktemp)
export COMPOSE_ENV_FILES=$env_file
cat > "$env_file" <<ENV
HOST_NAME=e2e-host
NTFY_URL=http://ntfy
NTFY_TOPIC=e2e
GRAFANA_ADMIN_PASSWORD=e2e-password
ENV

network=${COMPOSE_PROJECT_NAME}_monitoring
backup_dir=$(mktemp -d)

cleanup() {
  status=$?
  if ((status != 0)); then
    echo "--- test failed; recent logs ---"
    docker compose logs --tail=30 2>/dev/null || true
  fi
  docker compose down --volumes --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$env_file" "$backup_dir"
  exit "$status"
}
trap cleanup EXIT

pass() { printf '  \033[32mok\033[0m    %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; exit 1; }

# curl from inside the stack's network.
http() { docker run --rm -i --network "$network" curlimages/curl:8.17.0 -sf "$@"; }

# wait_for <seconds> <description> <command...>: retry until the command succeeds.
wait_for() {
  local timeout=$1 what=$2; shift 2
  local end=$((SECONDS + timeout))
  until "$@" >/dev/null 2>&1; do
    ((SECONDS < end)) || fail "$what (gave up after ${timeout}s)"
    sleep 5
  done
  pass "$what"
}

prom_query() { http -G "http://prometheus:9090/api/v1/query" --data-urlencode "query=$1"; }

all_targets_up() {
  local targets
  targets=$(http "http://prometheus:9090/api/v1/targets?state=active")
  [[ $(jq '[.data.activeTargets[] | select(.health != "up")] | length' <<<"$targets") == 0 ]] &&
    [[ $(jq '.data.activeTargets | length' <<<"$targets") -ge 8 ]]
}

ntfy_has() { http "http://ntfy/e2e/json?poll=1&since=all" | jq -e --arg re "$1" 'select((.title // "") + " " + (.message // "") | test($re))' >/dev/null; }

echo "Starting the stack"
docker compose up -d --wait --wait-timeout 300 >/dev/null 2>&1 || {
  docker compose ps; fail "stack did not become healthy"
}
pass "all services started and healthy"

echo "Metrics"
wait_for 120 "every Prometheus target is up (including this host's node-exporter)" all_targets_up
has_results() { prom_query "$1" | jq -e '.data.result | length > 0'; }
wait_for 60 "host metrics are collected" has_results 'node_uname_info{instance="localhost"}'
wait_for 60 "cAdvisor reports container metrics" has_results 'container_last_seen{name=~".+"}'
alerts_have_host_label() {
  http "http://prometheus:9090/api/v1/status/config" | jq -e '.data.yaml | test("host: e2e-host")'
}
wait_for 30 "alerts carry host=e2e-host" alerts_have_host_label

echo "Logs"
loki_has_container() {
  http "http://loki:3100/loki/api/v1/label/container_name/values" | jq -e --arg c "$1" '.data | index($c)'
}
wait_for 120 "container logs reach Loki, labelled by container" loki_has_container "${COMPOSE_PROJECT_NAME}-grafana-1"

echo "OpenTelemetry"
trace_id=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
span_id=$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')
now=$(date +%s%N)
http -X POST http://otel-collector:4318/v1/traces -H 'Content-Type: application/json' -d @- >/dev/null <<JSON
{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"e2e-app"}}]},
 "scopeSpans":[{"spans":[{"traceId":"$trace_id","spanId":"$span_id","name":"e2e-span","kind":1,
 "startTimeUnixNano":"$now","endTimeUnixNano":"$((now + 1000000))"}]}]}]}
JSON
http -X POST http://otel-collector:4318/v1/metrics -H 'Content-Type: application/json' -d @- >/dev/null <<JSON
{"resourceMetrics":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"e2e-app"}}]},
 "scopeMetrics":[{"metrics":[{"name":"e2e_requests","gauge":{"dataPoints":[{"asInt":"42","timeUnixNano":"$now"}]}}]}]}]}
JSON
http -X POST http://otel-collector:4318/v1/logs -H 'Content-Type: application/json' -d @- >/dev/null <<JSON
{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"e2e-app"}}]},
 "scopeLogs":[{"logRecords":[{"timeUnixNano":"$now","body":{"stringValue":"hello from e2e"},"traceId":"$trace_id","spanId":"$span_id"}]}]}]}
JSON
wait_for 90 "OTLP trace is stored in Tempo" http "http://tempo:3200/api/v2/traces/$trace_id"
otlp_metric_stored() { prom_query 'e2e_requests' | jq -e '.data.result[0].value[1] == "42"'; }
otlp_log_stored() {
  http -G "http://loki:3100/loki/api/v1/query_range" --data-urlencode 'query={service_name="e2e-app"}' |
    jq -e --arg t "$trace_id" '[.data.result[].stream.trace_id] | index($t)'
}
wait_for 60 "OTLP metric is stored in Prometheus" otlp_metric_stored
wait_for 60 "OTLP log is stored in Loki with its trace ID" otlp_log_stored

echo "Grafana"
grafana() { http -u admin:e2e-password "http://grafana:3000$1" "${@:2}"; }
for uid in prometheus loki tempo alertmanager; do
  wait_for 30 "datasource $uid is provisioned" grafana "/api/datasources/uid/$uid"
done
dashboards_provisioned() { grafana "/api/search?type=dash-db" | jq -e 'length >= 2'; }
wait_for 30 "dashboards are provisioned" dashboards_provisioned
wait_for 30 "Grafana can query Loki" grafana "/api/datasources/uid/loki/health"

echo "Alerts"
scripts/test-alert.sh >/dev/null
wait_for 60 "make test-alert reaches ntfy" ntfy_has "TestAlert"

docker compose stop grafana >/dev/null 2>&1
urgent_probe_alert() {
  http "http://ntfy/e2e/json?poll=1&since=all" |
    jq -e 'select((.title // "") | test("BlackboxProbeFailing")) | select(.priority == 5)'
}
wait_for 240 "stopping Grafana sends an urgent BlackboxProbeFailing alert" urgent_probe_alert
docker compose start grafana >/dev/null 2>&1
wait_for 300 "starting it again sends the resolved notification" ntfy_has "Resolved"

echo "Host overview dashboard"
# Run every panel query directly against Prometheus/Loki over the last 15
# minutes. Each must succeed, and must return data unless listed here.
may_be_empty='^(Disks/D)$'
dashboard=$(grafana /api/dashboards/uid/host-overview)
[[ $(jq -r '.meta.slug' <<<"$dashboard") == host-overview ]] || fail "Host overview dashboard is not provisioned"
# Grafana answers with a redirect to the dashboard set as home.
home=$(grafana /api/dashboards/home | jq -r '.redirectUri // .dashboard.title')
[[ $home == */host-overview ]] || fail "Host overview is not Grafana's home dashboard (got $home)"
pass "Host overview is provisioned and is the home dashboard"
start=$(( $(date +%s) - 900 )); end=$(date +%s)
queries=$(jq -c '.dashboard.panels[] | select(.targets) | .title as $t | .targets[] |
  {name: "\($t)/\(.refId)", type: .datasource.type, expr: .expr}' <<<"$dashboard")
count=0
while IFS= read -r q; do
  name=$(jq -r .name <<<"$q"); type=$(jq -r .type <<<"$q")
  # shellcheck disable=SC2016  # literal Grafana variables, replaced with test values
  expr=$(jq -r .expr <<<"$q" | sed -e 's/\$instance/localhost/g' -e 's/\$__rate_interval/1m/g' -e 's/\$__auto/1m/g')
  if [[ $type == prometheus ]]; then url=http://prometheus:9090/api/v1/query_range; step=30
  else url=http://loki:3100/loki/api/v1/query_range; step=30; fi
  result=$(http -G "$url" --data-urlencode "query=$expr" -d "start=$start" -d "end=$end" -d "step=$step" </dev/null) ||
    fail "panel query $name failed: $expr"
  if ! [[ $name =~ $may_be_empty ]] && ! [[ $name == "Recent errors/A" || $name == "Error log lines by container/A" ]]; then
    jq -e '.data.result | length > 0' <<<"$result" >/dev/null || fail "panel query $name returned no data: $expr"
  fi
  count=$((count + 1))
done <<<"$queries"
pass "all $count panel queries run, and return data where expected"

if [[ -n "${SCREENSHOT_DIR:-}" ]]; then
  mkdir -p "$SCREENSHOT_DIR"
  for theme in dark light; do
    grafana "/render/d/host-overview/host-overview?width=1600&height=2200&kiosk=1&theme=$theme&from=now-15m&to=now&tz=UTC" \
      -o /dev/stdout > "$SCREENSHOT_DIR/host-overview-$theme.png"
    file "$SCREENSHOT_DIR/host-overview-$theme.png" | grep -q PNG || fail "rendering the $theme screenshot"
  done
  pass "screenshots written to $SCREENSHOT_DIR"
fi

echo "Backup and restore"
grafana /api/folders -X POST -H 'Content-Type: application/json' -d '{"title":"e2e-marker"}' >/dev/null
scripts/backup.sh "$backup_dir" >/dev/null 2>&1
archive=$(ls "$backup_dir"/*.tar.gz)
pass "backup written ($(du -h "$archive" | cut -f1))"
docker compose down --volumes >/dev/null 2>&1
scripts/restore.sh "$archive" --yes >/dev/null 2>&1
docker compose up -d --wait --wait-timeout 300 >/dev/null 2>&1
marker_folder_exists() { grafana "/api/folders" | jq -e 'map(.title) | index("e2e-marker")'; }
wait_for 60 "restored Grafana still has the folder created before the backup" marker_folder_exists

echo "All end-to-end checks passed."
