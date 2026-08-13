#!/usr/bin/env bash
# Click-to-toggle the kw-wifi panel on the monitor under the cursor.
# MUST stay well under eww's 200ms onclick timeout: open the window right away
# with last-known data; wifi-updater.sh pushes a fresh scan immediately after.
# A full-screen backdrop window (kw-wifi-bg) opens beneath the panel so any
# click outside it lands here again and dismisses both.
set -euo pipefail

# One toggle at a time: a double-fire racing the open path stacks a duplicate
# surface on this eww build. fd 9 must not leak into anything long-lived:
# an auto-forked daemon or the updater would hold the lock forever.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/kw-wifi-toggle.lock"
flock -n 9 || exit 0

if eww active-windows 2>/dev/null | grep -q '^kw-wifi: '; then
  eww close kw-wifi 2>/dev/null 9>&- || true
  eww close kw-wifi-bg 2>/dev/null 9>&- || true
  eww close kw-wifi-pw 2>/dev/null 9>&- || true
  # Surfaces that survive the close belong to a daemon this CLI can't reach;
  # only a full relaunch kills them (mirrors kw-sidebar-toggle.sh).
  for _ in $(seq 1 12); do
    hyprctl layers 2>/dev/null | grep -q 'namespace: kw-wifi' || exit 0
    sleep 0.1
  done
  setsid -f ~/.config/eww/scripts/kw-bar-launch.sh 9>&- >/dev/null 2>&1
  exit 0
fi

# Self-heal: a kw-wifi surface exists on screen but THIS daemon doesn't own it
# (daemon/socket split; bit us 2026-07-25 while another agent hacked on eww).
# A stuck foreign surface can only die with its daemon: full relaunch.
if hyprctl layers 2>/dev/null | grep -q 'namespace: kw-wifi,'; then
  setsid -f ~/.config/eww/scripts/kw-bar-launch.sh 9>&- >/dev/null 2>&1
  exit 0
fi

# Panel-open sound; backgrounded so it costs nothing against the 200ms budget.
~/.local/bin/kw-sound -v .55 -g 300 completion-rotation &

monitors_json="$(hyprctl -j monitors)"
cursor_json="$(hyprctl -j cursorpos)"
cx="$(echo "$cursor_json" | jq -r '.x')"
cy="$(echo "$cursor_json" | jq -r '.y')"
mon_id="$(echo "$monitors_json" | jq --argjson x "$cx" --argjson y "$cy" \
  '[to_entries[] | select(.value.x <= $x and $x < (.value.x + .value.width) and .value.y <= $y and $y < (.value.y + .value.height))][0].key')"

eww update kw-wifi-prompt='' kw-wifi-error='' kw-wifi-busy='' 9>&-
eww open --screen "$mon_id" kw-wifi-bg 2>/dev/null 9>&- || true
eww open --screen "$mon_id" kw-wifi 9>&-
setsid -f ~/.config/eww/scripts/wifi/wifi-updater.sh 9>&- >/dev/null 2>&1
