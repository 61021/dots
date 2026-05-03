#!/usr/bin/env bash
# Toggle the kw-sidebar on the monitor under the cursor.
set -euo pipefail

if [ "${1:-}" = "close" ] || eww active-windows 2>/dev/null | grep -q '^kw-sidebar'; then
  eww close kw-sidebar >/dev/null 2>&1 || true
  exit 0
fi

monitors_json="$(hyprctl -j monitors)"
cursor_json="$(hyprctl -j cursorpos)"
cx="$(echo "$cursor_json" | jq -r '.x')"
cy="$(echo "$cursor_json" | jq -r '.y')"
mon="$(echo "$monitors_json" | jq --argjson x "$cx" --argjson y "$cy" \
  '[to_entries[] | select(.value.x <= $x and $x < (.value.x + .value.width) and .value.y <= $y and $y < (.value.y + .value.height))][0]')"
mon_id="$(echo "$mon" | jq -r '.key')"
mon_h="$(echo "$mon" | jq -r '.value.height')"
mon_scale="$(echo "$mon" | jq -r '.value.scale')"
bar_h=36
sidebar_w=240
logical_h="$(awk -v v="$mon_h" -v s="$mon_scale" 'BEGIN{printf "%d", v/s}')"
sidebar_h=$(( logical_h - bar_h ))

eww open --screen "$mon_id" \
  --size "${sidebar_w}x${sidebar_h}" \
  kw-sidebar
