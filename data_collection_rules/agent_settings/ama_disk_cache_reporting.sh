#!/usr/bin/env bash
set -uo pipefail

# Reports the AMA disk-cache setting and current local usage.
# Run as root because the agent configuration and state directories can be restricted.

LOG_FILE="/var/opt/microsoft/azuremonitoragent/log/mdsd.info"
CONFIG_CHUNKS_PATH="/etc/opt/microsoft/azuremonitoragent/config-cache/configchunks"

log() {
  printf '%s\n' "$1"
}

find_configured_quota() {
  local file quota=""
  [[ -d "$CONFIG_CHUNKS_PATH" ]] || return 1

  for file in "$CONFIG_CHUNKS_PATH"/*.json; do
    [[ -f "$file" ]] || continue
    if command -v jq >/dev/null 2>&1; then
      quota=$(jq -r '.. | objects | select(.name? == "MaxDiskQuotaInMB") | .value? // empty' "$file" 2>/dev/null | tail -n 1)
    else
      quota=$(grep -A2 '"name"[[:space:]]*:[[:space:]]*"MaxDiskQuotaInMB"' "$file" 2>/dev/null |
        grep -oE '"value"[[:space:]]*:[[:space:]]*"[0-9]+"' |
        grep -oE '[0-9]+' |
        tail -n 1)
    fi
    if [[ "$quota" =~ ^[0-9]+$ ]]; then
      printf '%s\n' "$quota"
      return 0
    fi
  done
  return 1
}

show_usage() {
  local dir size_kb=0
  local -a candidates=(
    "/var/opt/microsoft/azuremonitoragent/state"
    "/var/opt/microsoft/azuremonitoragent/events"
    "/var/opt/microsoft/azuremonitoragent/log"
    "/var/cache/azuremonitoragent"
    "/var/lib/azuremonitoragent"
    "/run/mdsd"
    "/var/run/mdsd"
  )

  for dir in "${candidates[@]}"; do
    [[ -d "$dir" ]] || continue
    size_kb=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
    [[ "$size_kb" =~ ^[0-9]+$ ]] || continue
    if (( size_kb > 1024 )); then
      log "Observed path: $dir ($((size_kb / 1024)) MB)"
    fi
  done
}

log "Azure Monitor Agent cache report"
if command -v systemctl >/dev/null 2>&1; then
  if systemctl is-active azuremonitoragent >/dev/null 2>&1; then
    log "Service: active"
  else
    log "Service: not active"
  fi
fi

if pgrep -x mdsd >/dev/null 2>&1; then
  log "Process: mdsd is running"
else
  log "Process: mdsd is not running"
fi

if quota_mb=$(find_configured_quota); then
  log "Configured MaxDiskQuotaInMB: $quota_mb"
else
  log "No custom MaxDiskQuotaInMB found in $CONFIG_CHUNKS_PATH"
  log "The agent may be using its platform default."
fi

show_usage

if [[ -f "$LOG_FILE" ]]; then
  log "Log file: $LOG_FILE"
else
  log "Log file not found: $LOG_FILE"
fi
