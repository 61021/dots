#!/usr/bin/env bash
# Click-to-toggle kw-calendar on the monitor under the cursor.
set -euo pipefail
flag=/tmp/kw-calendar.open

if [ -f "$flag" ]; then
  rm -f "$flag"
  eww close kw-calendar 2>/dev/null || true
  exit 0
fi

monitors_json="$(hyprctl -j monitors)"
cursor_json="$(hyprctl -j cursorpos)"
cx="$(echo "$cursor_json" | jq -r '.x')"
cy="$(echo "$cursor_json" | jq -r '.y')"
mon_id="$(echo "$monitors_json" | jq --argjson x "$cx" --argjson y "$cy" \
  '[to_entries[] | select(.value.x <= $x and $x < (.value.x + .value.width) and .value.y <= $y and $y < (.value.y + .value.height))][0].key')"

eww open --screen "$mon_id" kw-calendar
touch "$flag"
