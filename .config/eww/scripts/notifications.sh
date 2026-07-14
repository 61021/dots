#!/usr/bin/env bash
# Notification state as JSON {count,dnd,last}.
# count = unseen (waiting in DND queue + popups currently displayed);
# last  = newest history entry summary, for the bar tooltip.
set -eu
if ! command -v dunstctl >/dev/null 2>&1; then
  printf '{"count":0,"dnd":false,"last":""}\n'; exit 0
fi
waiting=$(dunstctl count waiting 2>/dev/null || echo 0)
displayed=$(dunstctl count displayed 2>/dev/null || echo 0)
count=$((waiting + displayed))
dnd=$(dunstctl is-paused 2>/dev/null || echo false)
last=$(dunstctl history 2>/dev/null | jq -r '.data[0][0].summary.data // ""' 2>/dev/null | head -c 60)
printf '{"count":%d,"dnd":%s,"last":%s}\n' "$count" "$dnd" "$(printf '%s' "$last" | jq -Rs .)"
