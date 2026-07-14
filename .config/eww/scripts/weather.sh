#!/usr/bin/env bash
# Cached weather JSON via wttr.in
set -eu
cache=/tmp/kw-weather.json
max_age=900  # 15 min

emit_empty() { printf '{"temp":"--","cond":"","label":"weather"}\n'; }

if [ -f "$cache" ] && [ "$(( $(date +%s) - $(stat -c %Y "$cache") ))" -lt "$max_age" ]; then
  cat "$cache"; exit 0
fi

raw=$(curl -fsS --max-time 4 'https://wttr.in/?format=j1' 2>/dev/null || true)
if [ -z "$raw" ]; then
  if [ -f "$cache" ]; then cat "$cache"; else emit_empty; fi
  exit 0
fi

temp=$(echo "$raw" | jq -r '.current_condition[0].temp_C' 2>/dev/null || echo "--")
cond=$(echo "$raw" | jq -r '.current_condition[0].weatherDesc[0].value' 2>/dev/null || echo "")
loc=$(echo "$raw"  | jq -r '.nearest_area[0].areaName[0].value' 2>/dev/null || echo "")
out=$(printf '{"temp":"%s°","cond":"%s","label":"%s"}\n' "$temp" "$cond" "$loc")
echo "$out" | tee "$cache"
