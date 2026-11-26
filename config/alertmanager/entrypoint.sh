#!/bin/sh
# Renders alertmanager.yml from the template using values from .env, then
# starts Alertmanager. Alertmanager itself can't read environment variables.
set -eu

: "${NTFY_URL:=https://ntfy.sh}"
: "${NTFY_TOPIC:?NTFY_TOPIC is not set. Run "make setup" to create .env}"
NTFY_TOKEN="${NTFY_TOKEN:-}"
NTFY_URL="${NTFY_URL%/}"

template=/etc/alertmanager/alertmanager.yml.tmpl
config=/tmp/alertmanager.yml

# "|" is the sed delimiter, so it must not appear in the values.
for value in "$NTFY_URL" "$NTFY_TOPIC" "$NTFY_TOKEN"; do
  case "$value" in *"|"*) echo "ntfy settings in .env must not contain '|'" >&2; exit 1 ;; esac
done

sed -e "s|\${NTFY_URL}|${NTFY_URL}|g" \
    -e "s|\${NTFY_TOPIC}|${NTFY_TOPIC}|g" \
    -e "s|\${NTFY_TOKEN}|${NTFY_TOKEN}|g" \
    "$template" > "$config"

if [ -z "$NTFY_TOKEN" ]; then
  sed -i '/# if-token$/d' "$config"
fi

exec /bin/alertmanager \
  --config.file="$config" \
  --storage.path=/alertmanager \
  "$@"
