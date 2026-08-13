#!/usr/bin/env bash
# Toggle the kw-sidebar (+ click-outside backdrop) on the monitor under the
# cursor. Invariant: at most ONE sidebar can ever be on screen.
#
# The open/close decision keys off `hyprctl layers`, NOT `eww active-windows`:
# when the daemon socket file is dead, any eww CLI call silently forks a fresh
# daemon that reports "no windows"; deciding on that opened a second sidebar
# on the new daemon while the old daemon's sidebar + backdrop stayed up as
# unclosable click-eating zombies (bit us 2026-08-05). A surface that survives
# `eww close` belongs to a daemon this CLI can't reach; only a full relaunch
# kills it (same heal as kw-wifi.sh). flock drops toggles that arrive while
# one is mid-flight: this eww build stacks duplicate surfaces on double-open.
# Every eww call closes fd 9: an auto-forked daemon would inherit the lock
# and hold it forever.
set -euo pipefail

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/kw-sidebar-toggle.lock"
flock -n 9 || exit 0

surfaces() {
  hyprctl -j layers 2>/dev/null \
    | jq '[.. | objects | select(.namespace? // "" | startswith("kw-sidebar"))] | length' \
    2>/dev/null || echo 0
}

if [ "${1:-}" = "close" ] || [ "$(surfaces)" -gt 0 ]; then
  eww close kw-sidebar 9>&- >/dev/null 2>&1 || true
  eww close kw-sidebar-bg 9>&- >/dev/null 2>&1 || true
  # The slide-out animation needs a few frames to unmap before we can tell
  # a normal close from a zombie surface.
  for _ in $(seq 1 12); do
    [ "$(surfaces)" -eq 0 ] && exit 0
    sleep 0.1
  done
  setsid -f ~/.config/eww/scripts/kw-bar-launch.sh 9>&- >/dev/null 2>&1
  exit 0
fi

# Panel-open sound (button clicks give the press half; this is the response).
~/.local/bin/kw-sound -v .55 -g 300 completion-rotation &

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
sidebar_w=300
logical_h="$(awk -v v="$mon_h" -v s="$mon_scale" 'BEGIN{printf "%d", v/s}')"
sidebar_h=$(( logical_h - bar_h ))

eww open --screen "$mon_id" kw-sidebar-bg 9>&- >/dev/null 2>&1 || true
eww open --screen "$mon_id" --size "${sidebar_w}x${sidebar_h}" kw-sidebar 9>&- \
  || { eww close kw-sidebar-bg 9>&- >/dev/null 2>&1 || true; exit 1; }
