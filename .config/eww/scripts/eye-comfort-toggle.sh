#!/usr/bin/env bash
# Toggle hyprsunset warm filter (3000K) via IPC against the persistent daemon
# (started by hyprland.conf exec-once). Falls back to spawning one if absent.
TEMP=3000

if ! pgrep -x hyprsunset >/dev/null 2>&1; then
  setsid -f hyprsunset --temperature "$TEMP" >/dev/null 2>&1
  exit 0
fi

cur=$(hyprctl hyprsunset temperature 2>/dev/null)
if [ "${cur:-6500}" -lt 6500 ] 2>/dev/null; then
  hyprctl hyprsunset temperature 6500 >/dev/null 2>&1   # neutral = "off" (identity has no query)
else
  hyprctl hyprsunset temperature "$TEMP" >/dev/null 2>&1
fi
