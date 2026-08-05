#!/usr/bin/env bash
# Low battery notifier.
# Polls every 60s. Fires a notification once when crossing each threshold,
# and again if the battery keeps dropping. Resets when charging or above 30%.

bat="$(upower -e | grep -m1 BAT)"
[ -z "$bat" ] && exit 0

state_file="${XDG_RUNTIME_DIR:-/tmp}/low-bat-notification.state"
: > "$state_file"

last_warn=100

while :; do
  info=$(upower -i "$bat" 2>/dev/null)
  pct=$(printf '%s\n' "$info" | awk -F: '/percentage:/ {gsub(/[ %\t]/,"",$2); print $2; exit}')
  status=$(printf '%s\n' "$info" | awk -F: '/state:/ {gsub(/[ \t]/,"",$2); print $2; exit}')

  case "$status" in
    charging|fully-charged)
      last_warn=100
      ;;
    *)
      if [ -n "$pct" ]; then
        if   [ "$pct" -le 5  ] && [ "$last_warn" -gt 5  ]; then
          notify-send -u critical -i battery-empty   -a "battery" -t 0    "Battery critical (${pct}%)" "Plug in now or the system will suspend."
          last_warn=5
        elif [ "$pct" -le 15 ] && [ "$last_warn" -gt 15 ]; then
          notify-send -u critical -i battery-caution -a "battery" -t 15000 "Battery very low (${pct}%)" "Plug in soon."
          last_warn=15
        elif [ "$pct" -le 25 ] && [ "$last_warn" -gt 25 ]; then
          notify-send -u normal   -i battery-low     -a "battery" -t 8000  "Battery low (${pct}%)" "Consider plugging in."
          last_warn=25
        elif [ "$pct" -gt 30 ]; then
          last_warn=100
        fi
      fi
      ;;
  esac

  sleep 60
done
