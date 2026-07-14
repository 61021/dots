#!/usr/bin/env bash
# Watches AC adapter; plays a sound when the cable is plugged in.
set -u

AC=$(ls /sys/class/power_supply/ 2>/dev/null | while read d; do
  t=$(cat "/sys/class/power_supply/$d/type" 2>/dev/null || echo)
  [ "$t" = "Mains" ] && echo "$d" && break
done)
[ -z "$AC" ] && exit 0

ONLINE="/sys/class/power_supply/$AC/online"
SOUND_PLUG="${SOUND_PLUG:-/usr/share/sounds/freedesktop/stereo/power-plug.oga}"
SOUND_UNPLUG="${SOUND_UNPLUG:-/usr/share/sounds/freedesktop/stereo/power-unplug.oga}"

play() { paplay "$1" >/dev/null 2>&1 & }

prev=$(cat "$ONLINE" 2>/dev/null || echo 0)
while sleep 1; do
  cur=$(cat "$ONLINE" 2>/dev/null || echo "$prev")
  if [ "$cur" != "$prev" ]; then
    if [ "$cur" = "1" ]; then
      play "$SOUND_PLUG"
    else
      play "$SOUND_UNPLUG"
    fi
    # Push fresh battery state to eww immediately
    command -v eww >/dev/null && \
      eww update "bar-bat=$(~/.config/eww/scripts/bar/battery.sh)" >/dev/null 2>&1 &
    prev=$cur
  fi
done
