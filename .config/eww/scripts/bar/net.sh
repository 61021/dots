#!/usr/bin/env bash
# Network → JSON: {"icon": "...", "label": "SSID | Wired | Offline"}
ICONS=~/.config/eww/icons

eth=$(nmcli -t -f TYPE,STATE device 2>/dev/null | awk -F: '$1=="ethernet" && $2=="connected"{print;exit}')
wifi=$(nmcli -t -f ACTIVE,SSID,SIGNAL,DEVICE device wifi list 2>/dev/null | awk -F: '$1=="yes"{print;exit}')

if [ -n "$wifi" ]; then
  ssid=$(echo "$wifi" | cut -d: -f2)
  sig=$(echo "$wifi" | cut -d: -f3)
  if   [ "$sig" -ge 75 ]; then ic="wifi-high"
  elif [ "$sig" -ge 50 ]; then ic="wifi-medium"
  elif [ "$sig" -ge 25 ]; then ic="wifi-low"
  else                          ic="wifi-none"
  fi
  printf '{"icon":"%s/%s.svg","label":"%s"}\n' "$ICONS" "$ic" "${ssid:-Wi-Fi}"
elif [ -n "$eth" ]; then
  printf '{"icon":"%s/plugs-connected.svg","label":"Wired"}\n' "$ICONS"
else
  printf '{"icon":"%s/wifi-slash.svg","label":"Offline"}\n' "$ICONS"
fi
