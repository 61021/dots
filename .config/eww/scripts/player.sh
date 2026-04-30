#!/usr/bin/env bash
# Now-playing JSON. Empty status="" means no player.
set -eu
if ! command -v playerctl >/dev/null 2>&1; then
  printf '{"status":"","title":"","artist":"","label":""}\n'; exit 0
fi
status=$(playerctl status 2>/dev/null || echo "")
if [ -z "$status" ] || [ "$status" = "Stopped" ]; then
  printf '{"status":"","title":"","artist":"","label":""}\n'; exit 0
fi
title=$(playerctl metadata title 2>/dev/null || echo "")
artist=$(playerctl metadata artist 2>/dev/null || echo "")
label="$title"
[ -n "$artist" ] && label="$artist — $title"
# JSON-escape
esc() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip()))' <<<"$1" 2>/dev/null || printf '"%s"' "$(echo "$1" | sed 's/\\/\\\\/g;s/"/\\"/g')"; }
printf '{"status":%s,"title":%s,"artist":%s,"label":%s}\n' \
  "$(esc "$status")" "$(esc "$title")" "$(esc "$artist")" "$(esc "$label")"
