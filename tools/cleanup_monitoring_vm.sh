#!/usr/bin/env bash
set -euo pipefail

# ---- Settings --------------------------------------------------------------
DRY_RUN="${DRY_RUN:-1}"               # 1 = show actions, 0 = perform
REPORT_RETENTION_DAYS="${REPORT_RETENTION_DAYS:-30}"  # older than this will be archived
ARCHIVE_DIR="${ARCHIVE_DIR:-$HOME/archive}"

# Important config dirs to protect from accidental delete
PROTECT_PATTERNS=(
  "./monitoring-stack/config"
  "./monitoring-stack/prometheus"
  "./monitoring-stack/grafana"
  "./level0/grafana"
  "./level0/compose.yaml"
)

shout() { echo -e "\n==> $*"; }
doit()  { if [[ "$DRY_RUN" == "1" ]]; then echo "DRY_RUN: $*"; else eval "$@"; fi; }

is_protected() {
  local path="$1"
  for p in "${PROTECT_PATTERNS[@]}"; do
    [[ "$path" == "$p"* ]] && return 0
  done
  return 1
}

# ---- 0) Snapshot disk usage -----------------------------------------------
shout "Disk usage BEFORE:"
df -h /

# ---- 1) Cargo targets ------------------------------------------------------
shout "Cleaning Rust Cargo targets (pizza-* crates)"
for dir in ./pizza-doctor ./pizza-ops-agent ./pizza-ops-check; do
  if [[ -d "$dir/target" ]]; then
    shout "  -> cargo clean in $dir"
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "DRY_RUN: (cd $dir && cargo clean)"
    else
      ( cd "$dir" && cargo clean || true )
    fi
  fi
done

# ---- 2) Python caches ------------------------------------------------------
shout "Removing __pycache__ and *.pyc"
mapfile -t pyc_dirs < <(find . -type d -name "__pycache__" -prune)
for d in "${pyc_dirs[@]:-}"; do doit "rm -rf \"$d\""; done
doit "find . -type f -name \"*.pyc\" -delete"

# ---- 3) Archive big dated reports/logs ------------------------------------
shout "Archiving old reports/logs (> ${REPORT_RETENTION_DAYS}d)"
mkdir -p "$ARCHIVE_DIR/ps-reports"
mapfile -t oldfiles < <(find PowerShell-Automation-Toolkit/{out,reports,logs} -type f -mtime +${REPORT_RETENTION_DAYS} 2>/dev/null || true)
for f in "${oldfiles[@]:-}"; do
  # preserve relative path
  dest="$ARCHIVE_DIR/ps-reports/$f"
  doit "mkdir -p \"$(dirname \"$dest\")\""
  doit "rsync -a \"$f\" \"$dest\" && rm -f \"$f\""
done

# ---- 4) Terraform states: move to ./state (do NOT delete) -----------------
shout "Relocating local terraform state files into ./state (not deleting)"
mkdir -p ./state
mapfile -t tfstate < <(find . -path "*/terraform/terraform.tfstate*" -type f 2>/dev/null || true)
for s in "${tfstate[@]:-}"; do
  dest="./state/${s//\//_}"
  doit "cp -n \"$s\" \"$dest\" || true"
done

# ---- 5) Docker prune -------------------------------------------------------
shout "Docker prune (unused images/networks/volumes)"
doit "docker system prune -af --volumes"

# ---- 6) Apt cache & journals ----------------------------------------------
shout "Apt cache + autoremove"
doit "sudo apt-get autoremove -y"
doit "sudo apt-get autoclean -y"
doit "sudo apt-get clean"

shout "Vacuum systemd-journald to 14 days"
doit "sudo journalctl --vacuum-time=14d"

# ---- 7) Empty directories cleanup (safe) -----------------------------------
shout "Removing empty directories left behind"
doit "find . -type d -empty -not -path '.' -delete"

# ---- 8) Post-snapshot ------------------------------------------------------
shout "Disk usage AFTER (estimate; DRY_RUN may not reflect actual change):"
df -h /

echo
if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run complete. Re-run with: DRY_RUN=0 bash ~/cleanup_monitoring_vm.sh"
else
  echo "Cleanup complete."
fi
