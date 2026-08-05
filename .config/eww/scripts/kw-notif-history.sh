#!/usr/bin/env bash
# Last dunst notifications as compact JSON for the sidebar:
# [{"app": "...", "summary": "..."}] (newest first, max 2).
set -eu
if ! command -v dunstctl >/dev/null 2>&1; then
  echo '[]'; exit 0
fi
dunstctl history 2>/dev/null | jq -c '
  [.data[0][:2][] | {
    app: (.appname.data // ""),
    summary: ((.summary.data // "") | .[0:40])
  }]' 2>/dev/null || echo '[]'
