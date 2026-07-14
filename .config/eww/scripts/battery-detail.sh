#!/usr/bin/env bash
# Battery JSON for sidebar: {percent, status, charging}
set -eu
bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1 || true)
if [ -z "$bat" ]; then
  printf '{"percent":-1,"status":"AC","charging":false}\n'; exit 0
fi
pct=$(cat "$bat/capacity" 2>/dev/null || echo 0)
status=$(cat "$bat/status" 2>/dev/null || echo Unknown)
charging=false
[ "$status" = "Charging" ] && charging=true
[ "$status" = "Full" ] && charging=true
printf '{"percent":%d,"status":"%s","charging":%s}\n' "$pct" "$status" "$charging"
