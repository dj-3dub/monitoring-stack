#!/usr/bin/env bash
# Sends a test alert through Alertmanager, so you can check that notifications
# reach your phone. It resolves itself after two minutes.
set -euo pipefail

cd "$(dirname "$0")/.."

end=$(date -u -d "+2 minutes" +%Y-%m-%dT%H:%M:%SZ)

docker compose exec -T alertmanager amtool alert add \
  --alertmanager.url=http://localhost:9093 \
  --end="$end" \
  --annotation=summary="Test alert from monitoring-stack" \
  --annotation=description="If you can read this, alerts reach you. It resolves in 2 minutes." \
  alertname=TestAlert severity=warning instance=test

echo "Test alert sent. It should arrive within about 30 seconds."
