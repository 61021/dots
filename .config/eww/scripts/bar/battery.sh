#!/usr/bin/env bash
# Battery → JSON: {"percent": 87, "icon": "battery-high", "label": "87%"}
ICONS=~/.config/eww/icons
BAT=$(ls /sys/class/power_supply/ 2>/dev/null | grep -m1 '^BAT')
if [ -z "$BAT" ]; then
  printf '{"percent":0,"icon":"%s/plug.svg","label":"AC"}\n' "$ICONS"
  exit
fi
P=$(cat "/sys/class/power_supply/$BAT/capacity" 2>/dev/null || echo 0)
S=$(cat "/sys/class/power_supply/$BAT/status"   2>/dev/null || echo Unknown)

if [ "$S" = "Charging" ] || [ "$S" = "Full" ]; then
  ICON="battery-charging-vertical"
elif [ "$P" -le 10 ]; then
  ICON="battery-warning"
elif [ "$P" -le 25 ]; then
  ICON="battery-low"
elif [ "$P" -le 50 ]; then
  ICON="battery-medium"
elif [ "$P" -le 80 ]; then
  ICON="battery-high"
else
  ICON="battery-full"
fi

printf '{"percent":%s,"icon":"%s/%s.svg","label":"%s%%"}\n' "$P" "$ICONS" "$ICON" "$P"
