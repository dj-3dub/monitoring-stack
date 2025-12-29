#!/usr/bin/env bash
set -euo pipefail

# Optional services that are generally safe to disable on a headless homelab VM
# Keep open-vm-tools if you're on VMware (you are), so it's NOT listed here.
OPTIONAL_SERVICES=(
  fwupd.service           # Firmware updater (desktop-oriented)
  ModemManager.service    # Mobile broadband modems (not needed on servers)
  multipathd.service      # SAN multipath (disable if you don't use multipath)
  udisks2.service         # Desktop disk manager (not needed headless)
)

# Toggle this to also disable the local console getty
DISABLE_GETTY=false
GETTY_UNIT="getty@tty1.service"

changed_any=false

echo "==> Checking and disabling optional services..."
for unit in "${OPTIONAL_SERVICES[@]}"; do
  if systemctl list-unit-files --type=service | awk '{print $1}' | grep -qx "${unit}"; then
    active=$(systemctl is-active "${unit}" || true)
    enabled=$(systemctl is-enabled "${unit}" 2>/dev/null || true)

    if [[ "${enabled}" != "disabled" || "${active}" == "active" ]]; then
      echo " - Disabling & stopping ${unit} (was: enabled=${enabled}, active=${active})"
      sudo systemctl disable --now "${unit}" || true
      changed_any=true
    else
      echo " - ${unit} already disabled/stopped"
    fi
  else
    echo " - ${unit} not present on this system (skipping)"
  fi
done

if [[ "${DISABLE_GETTY}" == "true" ]]; then
  if systemctl list-unit-files --type=service | awk '{print $1}' | grep -qx "${GETTY_UNIT}"; then
    active=$(systemctl is-active "${GETTY_UNIT}" || true)
    enabled=$(systemctl is-enabled "${GETTY_UNIT}" 2>/dev/null || true)
    if [[ "${enabled}" != "disabled" || "${active}" == "active" ]]; then
      echo " - Disabling console login (${GETTY_UNIT})"
      sudo systemctl disable --now "${GETTY_UNIT}" || true
      changed_any=true
    else
      echo " - ${GETTY_UNIT} already disabled/stopped"
    fi
  else
    echo " - ${GETTY_UNIT} not present (skipping)"
  fi
else
  echo "==> Leaving console login (${GETTY_UNIT}) enabled (set DISABLE_GETTY=true to disable)"
fi

echo
if [[ "${changed_any}" == "true" ]]; then
  echo "==> Done. Current states for trimmed services:"
  sudo systemctl status fwupd.service ModemManager.service multipathd.service udisks2.service 2>/dev/null | sed 's/^/   /'
else
  echo "==> No changes were necessary."
fi

echo
echo "Tip: Re-enable a service if needed, e.g.:"
echo "  sudo systemctl enable --now fwupd.service"

