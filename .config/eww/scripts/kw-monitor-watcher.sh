#!/usr/bin/env bash
# Re-launch eww (full daemon restart) whenever the set of connected
# monitors changes. eww caches its GDK monitor list at daemon start, so
# restarting is the only reliable way to refresh after lid/hotplug.

set -euo pipefail

last=""
while sleep 2; do
  cur="$(hyprctl -j monitors 2>/dev/null | jq -r '[.[].id] | sort | join(",")')" || true
  if [ -n "$cur" ] && [ "$cur" != "$last" ]; then
    if [ -n "$last" ]; then
      eww kill >/dev/null 2>&1 || true
      sleep 0.4
      eww daemon >/dev/null 2>&1 || true
      sleep 0.6
      ~/.config/eww/scripts/kw-bar-launch.sh || true
    fi
    last="$cur"
  fi
done
