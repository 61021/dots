#!/usr/bin/env bash
# Toggle the kw-sidebar (+ click-outside backdrop) on the focused monitor. Invariant: at most ONE sidebar can ever be on screen.
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


# One hyprctl + one jq: the focused monitor is the one that got the click.
read -r mon_id sidebar_h < <(hyprctl -j monitors | jq -r \
  '[to_entries[] | select(.value.focused)][0] | "\(.key // 0) \(((.value.height / .value.scale) | floor) - 36)"')
sidebar_w=300

eww open --screen "$mon_id" kw-sidebar-bg 9>&- >/dev/null 2>&1 || true
eww open --screen "$mon_id" --size "${sidebar_w}x${sidebar_h}" kw-sidebar 9>&- \
  || { eww close kw-sidebar-bg 9>&- >/dev/null 2>&1 || true; exit 1; }
