#!/usr/bin/env bash
# CPU%, RAM%, temp C as JSON. CPU is the delta since the previous poll (kept
# in $XDG_RUNTIME_DIR), so the sidebar rings fill on the first tick instead of
# after a 0.4s sample; a stale sample (>30s, sidebar was closed) is resampled.
set -eu
prev_file="${XDG_RUNTIME_DIR:-/tmp}/kw-sys-stats.prev"

snap() { awk '/^cpu /{tot=0; for(i=2;i<=NF;i++) tot+=$i; print tot, $5+$6; exit}' /proc/stat; }

now=$(snap)
if [ -s "$prev_file" ] && [ -z "$(find "$prev_file" -mmin +0.5 2>/dev/null)" ]; then
  read -r prev_total prev_idle < "$prev_file"
else
  prev_total=${now% *}; prev_idle=${now#* }
  sleep 0.4
  now=$(snap)
fi
printf '%s\n' "$now" > "$prev_file"
total=${now% *}; idle=${now#* }

dt=$(( total - prev_total ))
di=$(( idle - prev_idle ))
cpu=0
[ "$dt" -gt 0 ] && cpu=$(( (100 * (dt - di)) / dt ))

mem=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d", (t-a)*100/t}' /proc/meminfo)

temp=0
for z in /sys/class/thermal/thermal_zone*/type; do
  [ -e "$z" ] || continue
  case "$(cat "$z" 2>/dev/null || true)" in
    *x86_pkg*|*coretemp*|*acpitz*|*cpu*)
      raw=$(cat "${z%/type}/temp" 2>/dev/null || echo 0)
      temp=$(( raw / 1000 ))
      break ;;
  esac
done
if [ "$temp" -eq 0 ] && [ -e /sys/class/thermal/thermal_zone0/temp ]; then
  temp=$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))
fi

printf '{"cpu":%d,"mem":%d,"temp":%d}\n' "$cpu" "$mem" "$temp"
