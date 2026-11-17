#!/usr/bin/env bash
# Toggle the keys sheet (ALT+/) on the focused monitor; `close` only closes.
# Same hardening as kw-sidebar-toggle.sh: decide from `hyprctl layers`, flock
# away double-fires, `open --no-daemonize`, full relaunch if a surface
# survives the close.
set -euo pipefail

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/kw-keys-toggle.lock"
flock -n 9 || exit 0

surfaces() {
  hyprctl -j layers 2>/dev/null \
    | jq '[.. | objects | select(.namespace? // "" | startswith("kw-keys"))] | length' \
    2>/dev/null || echo 0
}

if [ "${1:-}" = "close" ] || [ "$(surfaces)" -gt 0 ]; then
  eww close kw-keys 9>&- >/dev/null 2>&1 || true
  eww close kw-keys-bg 9>&- >/dev/null 2>&1 || true
  for _ in $(seq 1 12); do
    [ "$(surfaces)" -eq 0 ] && exit 0
    sleep 0.1
  done
  setsid -f ~/.config/eww/scripts/kw-bar-launch.sh 9>&- >/dev/null 2>&1
  exit 0
fi

mon_id=$(hyprctl -j monitors | jq -r '[to_entries[] | select(.value.focused)][0].key // 0')

# The sheet reads the live binds, so it always matches hyprland.lua.
eww update kw-keys-data="$(~/.config/eww/scripts/keys-data.py 9>&-)" 9>&- >/dev/null 2>&1 || true
open_err=$(eww --no-daemonize open --screen "$mon_id" kw-keys-bg 9>&- 2>&1 >/dev/null || true)
open_err+=$(eww --no-daemonize open --screen "$mon_id" kw-keys 9>&- 2>&1 >/dev/null || true)
case $open_err in *"Failed to connect"*) setsid -f ~/.config/eww/scripts/kw-bar-launch.sh 9>&- >/dev/null 2>&1 ;; esac
