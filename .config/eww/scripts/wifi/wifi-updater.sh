#!/usr/bin/env bash
# Refreshes kw-wifi panel data every 2s while the window is open; exits with it.
# Spawned detached by kw-wifi.sh on open. Pauses while a password prompt is up
# so list rebuilds can't eat keystrokes.
DIR="$HOME/.config/eww/scripts/wifi"

nmcli device wifi rescan 2>/dev/null &

for _ in $(seq 1 900); do # hard cap ~30 min against leaks
  eww active-windows 2>/dev/null | grep -q '^kw-wifi: ' || exit 0
  if [ -z "$(eww get kw-wifi-prompt 2>/dev/null)" ]; then
    data="$("$DIR/wifi-data.py" 2>/dev/null)" || data=""
    case "$data" in
      '{'*) eww update "kw-wifi=$data" 2>/dev/null || exit 0 ;;
      *) : ;; # never push garbage into the var — skip this tick
    esac
  fi
  sleep 2
done
