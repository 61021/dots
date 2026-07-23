#!/usr/bin/env bash
# Two-click confirmation for destructive power actions.
# First click arms the button (red) for 3s; second click executes.
set -u
action="${1:-}"
case "$action" in reboot|poweroff) ;; *) exit 1 ;; esac

armed="$(eww get power-arm 2>/dev/null || echo '')"
if [ "$armed" = "$action" ]; then
  eww update power-arm='' 2>/dev/null
  eww close kw-sidebar >/dev/null 2>&1 || true
  exec systemctl "$action"
fi

eww update "power-arm=$action" 2>/dev/null
(
  sleep 3
  [ "$(eww get power-arm 2>/dev/null)" = "$action" ] && eww update power-arm='' 2>/dev/null
) &
