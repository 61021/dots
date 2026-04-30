#!/usr/bin/env bash
# Recent dunst notifications as JSON {count,last}
set -eu
if ! command -v dunstctl >/dev/null 2>&1; then
  printf '{"count":0,"last":""}\n'; exit 0
fi
hist=$(dunstctl history 2>/dev/null || echo '{}')
count=$(echo "$hist" | jq -r '.data[0] | length' 2>/dev/null || echo 0)
last=$(echo "$hist" | jq -r '.data[0][0].summary.data // ""' 2>/dev/null | head -c 60)
printf '{"count":%d,"last":%s}\n' "$count" "$(printf '%s' "$last" | jq -Rs .)"
