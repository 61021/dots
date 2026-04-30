#!/usr/bin/env bash
# Open one `bar` window per connected monitor.
# eww on this build identifies monitors by GDK model name (which can be
# duplicated for identical externals), so we address by the GDK monitor
# INDEX, derived from sorting Hyprland monitor ids ascending. That order
# matches GDK's wl_output registry order at session start.
#
# To survive monitor hotplug/lid events we tear down and recreate every
# bar; this script is also re-run by the Hyprland monitor add/remove
# events (see ~/.config/hypr/hyprland.conf).

set -euo pipefail

for _ in $(seq 1 20); do
  eww ping >/dev/null 2>&1 && break
  sleep 0.1
done

# Close any previously opened bar instances.
mapfile -t open < <(eww active-windows 2>/dev/null | awk -F: '/^bar(-|$)/ {print $1}')
for w in "${open[@]}"; do
  eww close "$w" >/dev/null 2>&1 || true
done

# Hyprland id -> GDK monitor index = position in id-sorted list.
mapfile -t ids < <(hyprctl -j monitors | jq -r '[.[].id] | sort | .[]')
for id in "${ids[@]}"; do
  gdk_idx=$(printf '%s\n' "${ids[@]}" | awk -v t="$id" '$0==t{print NR-1; exit}')
  eww open --id "bar-${id}" --screen "${gdk_idx}" bar >/dev/null 2>&1 || true
done
