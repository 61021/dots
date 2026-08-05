#!/usr/bin/env bash
# Streams network state for the bar's `deflisten`.
# nmcli monitor catches connect/disconnect instantly; a slow 60s tick keeps
# the wifi signal-strength icon from going stale (strength isn't evented).
set -u

emit() { ~/.config/eww/scripts/bar/net.sh; }

tick() { while sleep 60; do emit; done; }

emit
tick &
trap 'kill "$!" 2>/dev/null' EXIT
nmcli monitor 2>/dev/null |
while IFS= read -r _; do
  # Coalesce bursts (one reconnect prints many lines).
  while IFS= read -r -t 0.5 _; do :; done
  emit
done
