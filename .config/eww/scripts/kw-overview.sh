#!/usr/bin/env bash
# Overview strip under the bar: the occupied workspaces as thumbnails.
#   show      refresh the strip, open it if needed, hide it 1.2s after the last call (ALT+Tab)
#   go <id>   jump to that workspace and close
#   close
# The window is not focusable and holds no keyboard grab; it only shows.
set -euo pipefail

token="${XDG_RUNTIME_DIR:-/tmp}/kw-overview.token"
is_open() {
  hyprctl -j layers 2>/dev/null \
    | jq -e '[.. | objects | select(.namespace? == "kw-overview")] | length > 0' >/dev/null 2>&1
}

case "${1:-show}" in
  close)
    eww close kw-overview >/dev/null 2>&1 || true
    ;;
  go)
    hyprctl dispatch "hl.dsp.focus({ workspace = ${2:?workspace id} })" >/dev/null 2>&1 || true
    eww close kw-overview >/dev/null 2>&1 || true
    ;;
  show)
    stamp="$$-$(date +%s%N)"
    printf '%s' "$stamp" >"$token"
    eww update kw-ov="$(~/.config/eww/scripts/overview-data.py)" >/dev/null 2>&1 || true
    # This eww build stacks duplicate surfaces on a double open: one opener at a time.
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/kw-overview.lock"
    if flock -n 9 && ! is_open; then
      mon_id=$(hyprctl -j monitors | jq -r '[to_entries[] | select(.value.focused)][0].key // 0')
      eww --no-daemonize open --screen "$mon_id" kw-overview 9>&- >/dev/null 2>&1 || true
    fi
    (
      exec 9>&-
      sleep 1.2
      [ "$(cat "$token" 2>/dev/null)" = "$stamp" ] && eww close kw-overview >/dev/null 2>&1
    ) &
    ;;
esac
