#!/usr/bin/env bash
# Battery → JSON: {"percent": 87, "icon": "battery-high", "label": "87%", "state": "ok"}
# state: charging | critical (<=10) | low (<=25) | ok — drives label tint in CSS.
ICONS=~/.config/eww/icons
BAT=$(ls /sys/class/power_supply/ 2>/dev/null | grep -m1 '^BAT')
if [ -z "$BAT" ]; then
  printf '{"percent":0,"icon":"%s/plug.svg","label":"AC","state":"ok"}\n' "$ICONS"
  exit
fi
P=$(cat "/sys/class/power_supply/$BAT/capacity" 2>/dev/null || echo 0)
S=$(cat "/sys/class/power_supply/$BAT/status"   2>/dev/null || echo Unknown)

if [ "$S" = "Charging" ] || [ "$S" = "Full" ]; then
  ICON="battery-charging-vertical"
  STATE="charging"
elif [ "$P" -le 10 ]; then
  ICON="battery-warning"
  STATE="critical"
elif [ "$P" -le 25 ]; then
  ICON="battery-low"
  STATE="low"
elif [ "$P" -le 50 ]; then
  ICON="battery-medium"
  STATE="ok"
elif [ "$P" -le 80 ]; then
  ICON="battery-high"
  STATE="ok"
else
  ICON="battery-full"
  STATE="ok"
fi

printf '{"percent":%s,"icon":"%s/%s.svg","label":"%s%%","state":"%s"}\n' "$P" "$ICONS" "$ICON" "$P" "$STATE"
