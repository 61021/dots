#!/usr/bin/env bash
# Open one bar per monitor.
# Assumes Hyprland's monitor `id` matches GDK's index. If a setup ever
# breaks that (e.g. two identical monitors enumerated in different orders
# by Hyprland and GDK), re-run the probe widget to verify.
set -e

for _ in $(seq 1 20); do
  eww ping >/dev/null 2>&1 && break
  sleep 0.1
done

eww active-windows 2>/dev/null \
  | awk -F: '/^bar(-|$)/ {print $1}' \
  | xargs -r -n1 eww close >/dev/null 2>&1 || true

n=$(hyprctl monitors -j | jq 'length')
for ((i=0; i<n; i++)); do
  eww open --id "bar-$i" --screen "$i" bar
done
