#!/usr/bin/env bash
# Toggle the kw-wifi panel on the focused monitor.
# Open path stays far under eww's 200ms onclick budget: the panel renders with
# the daemon's last-known data at once; SIGUSR1 tells scripts/net/nm-listen.py
# to scan now and keep scanning every 15s while the panel is up.
# Decision comes from `hyprctl layers`, never from `eww active-windows`: with a
# dead socket file the eww CLI answers from a fresh empty daemon (see
# kw-sidebar-toggle.sh). A surface that survives `eww close` belongs to a
# daemon this CLI can't reach; only a full relaunch kills it.
set -euo pipefail

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/kw-wifi-toggle.lock"
flock -n 9 || exit 0

PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/kw-net.pid"
signal_net() { kill "-$1" "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null || true; }
open_surfaces() { hyprctl layers 2>/dev/null | grep -c 'namespace: kw-wifi' || true; }

if [ "${1:-}" = "close" ] || [ "$(open_surfaces)" -gt 0 ]; then
  signal_net USR2
  eww close kw-wifi kw-wifi-bg kw-wifi-pw 9>&- >/dev/null 2>&1 || true
  # Reset prompt/error/busy here, not on open: the open path stays one IPC call.
  eww update kw-wifi-prompt='' kw-wifi-error='' kw-wifi-busy='' 9>&- >/dev/null 2>&1 || true
  for _ in $(seq 1 12); do
    [ "$(open_surfaces)" -eq 0 ] && exit 0
    sleep 0.1
  done
  setsid -f ~/.config/eww/scripts/kw-bar-launch.sh 9>&- >/dev/null 2>&1
  exit 0
fi


mon_id="$(hyprctl -j monitors | jq -r '[to_entries[] | select(.value.focused)][0].key // 0')"

eww open-many --arg "kw-wifi-bg:mon=$mon_id" --arg "kw-wifi:mon=$mon_id" kw-wifi-bg kw-wifi 9>&- \
  || { eww close kw-wifi-bg kw-wifi 9>&- >/dev/null 2>&1 || true; exit 1; }
signal_net USR1
