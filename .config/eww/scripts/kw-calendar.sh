#!/usr/bin/env bash
# Click-to-toggle kw-calendar on the focused Hyprland monitor.
flag=/tmp/kw-calendar.open

if [ -f "$flag" ]; then
  rm -f "$flag"
  eww close kw-calendar
else
  mon=$(hyprctl -j monitors | jq -r '[.[] | select(.focused)][0].name')
  eww open --screen "$mon" kw-calendar 2>/dev/null
  touch "$flag"
fi
