#!/usr/bin/env bash
# Click-to-toggle kw-calendar on the focused Hyprland monitor.
set -euo pipefail
flag=/tmp/kw-calendar.open

if [ -f "$flag" ]; then
  rm -f "$flag"
  eww close kw-calendar 2>/dev/null || true
else
  monitors_json="$(hyprctl -j monitors)"
  hypr_id="$(echo "$monitors_json" | jq -r '[.[] | select(.focused)][0].id')"
  mon_idx="$(echo "$monitors_json" | jq --argjson id "$hypr_id" '[.[] | .id] | sort | index($id)')"
  eww open --screen "$mon_idx" kw-calendar
  touch "$flag"
fi
