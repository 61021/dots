#!/usr/bin/env bash
# Battery JSON for sidebar:
# {percent, status, charging, time, health} — time = "2h 10m to empty|full".
set -eu
bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1 || true)
if [ -z "$bat" ]; then
  printf '{"percent":-1,"status":"AC","charging":false,"time":"","health":0}\n'; exit 0
fi
pct=$(cat "$bat/capacity" 2>/dev/null || echo 0)
status=$(cat "$bat/status" 2>/dev/null || echo Unknown)
charging=false
[ "$status" = "Charging" ] && charging=true
[ "$status" = "Full" ] && charging=true

now=$(cat "$bat/energy_now" 2>/dev/null || echo 0)
full=$(cat "$bat/energy_full" 2>/dev/null || echo 0)
design=$(cat "$bat/energy_full_design" 2>/dev/null || echo 0)
power=$(cat "$bat/power_now" 2>/dev/null || echo 0)

health=0
[ "$design" -gt 0 ] && health=$(( full * 100 / design ))

time=""
if [ "$power" -gt 10000 ]; then # ignore ~0 draw (sleep/settled full)
  case "$status" in
    Discharging) mins=$(( now * 60 / power )); suffix="to empty" ;;
    Charging)    mins=$(( (full - now) * 60 / power )); suffix="to full" ;;
    *)           mins=0; suffix="" ;;
  esac
  if [ -n "$suffix" ] && [ "$mins" -gt 0 ]; then
    if [ "$mins" -ge 60 ]; then time="$(( mins / 60 ))h $(( mins % 60 ))m $suffix"
    else time="${mins}m $suffix"; fi
  fi
fi

printf '{"percent":%d,"status":"%s","charging":%s,"time":"%s","health":%d}\n' \
  "$pct" "$status" "$charging" "$time" "$health"
