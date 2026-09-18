#!/usr/bin/env bash
# Click-to-toggle kw-calendar on the focused monitor.
# Same hardening as kw-sidebar-toggle.sh: decide from `hyprctl layers` (the
# eww CLI forks a fresh empty-handed daemon when the socket file is dead, so
# `eww active-windows` lies exactly when a zombie is on screen), flock away
# double-fires, full relaunch if a surface survives the close.
set -euo pipefail

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/kw-calendar-toggle.lock"
flock -n 9 || exit 0

surfaces() {
  hyprctl -j layers 2>/dev/null \
    | jq '[.. | objects | select(.namespace? == "kw-calendar")] | length' \
    2>/dev/null || echo 0
}

if [ "$(surfaces)" -gt 0 ]; then
  eww close kw-calendar 9>&- >/dev/null 2>&1 || true
  for _ in $(seq 1 12); do
    [ "$(surfaces)" -eq 0 ] && exit 0
    sleep 0.1
  done
  setsid -f ~/.config/eww/scripts/kw-bar-launch.sh 9>&- >/dev/null 2>&1
  exit 0
fi

# Panel-open sound (the clock click gives the press half; this is the response).
~/.local/bin/kw-sound -v .55 -g 300 completion-rotation &

mon_id="$(hyprctl -j monitors | jq -r '[to_entries[] | select(.value.focused)][0].key // 0')"

~/.config/eww/scripts/bar/calendar-data.py reset 9>&-
eww open --screen "$mon_id" kw-calendar 9>&-
