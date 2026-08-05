#!/usr/bin/env bash
# CPU%, RAM%, temp°C as JSON
set -eu

snap() { awk '/^cpu /{tot=0; for(i=2;i<=NF;i++) tot+=$i; print tot, $5+$6; exit}' /proc/stat; }

p1=$(snap); sleep 0.4; p2=$(snap)
prev_total=${p1% *}; prev_idle=${p1#* }
total=${p2% *};      idle=${p2#* }

dt=$(( total - prev_total ))
di=$(( idle - prev_idle ))
cpu=0
[ "$dt" -gt 0 ] && cpu=$(( (100 * (dt - di)) / dt ))

mem=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d", (t-a)*100/t}' /proc/meminfo)

temp=0
for z in /sys/class/thermal/thermal_zone*/type; do
  [ -e "$z" ] || continue
  t=$(cat "$z" 2>/dev/null || true)
  case "$t" in
    *x86_pkg*|*coretemp*|*acpitz*|*cpu*)
      raw=$(cat "${z%/type}/temp" 2>/dev/null || echo 0)
      temp=$(( raw / 1000 ))
      break ;;
  esac
done
if [ "$temp" -eq 0 ] && [ -e /sys/class/thermal/thermal_zone0/temp ]; then
  raw=$(cat /sys/class/thermal/thermal_zone0/temp)
  temp=$(( raw / 1000 ))
fi

printf '{"cpu":%d,"mem":%d,"temp":%d}\n' "$cpu" "$mem" "$temp"
