#!/usr/bin/env bash
# Toggle the kw-sidebar on the focused Hyprland monitor.
set -euo pipefail

monitors_json="$(hyprctl -j monitors)"
mon_json="$(echo "$monitors_json" | jq '.[] | select(.focused==true)')"
mon_hypr_id="$(echo "$mon_json" | jq -r '.id')"
mon_idx="$(echo "$monitors_json" | jq --argjson id "$mon_hypr_id" '[.[] | .id] | sort | index($id)')"
mon_h="$(echo "$mon_json" | jq -r '.height')"
mon_scale="$(echo "$mon_json" | jq -r '.scale')"
bar_h=36
sidebar_w=240
logical_h="$(awk -v v="$mon_h" -v s="$mon_scale" 'BEGIN{printf "%d", v/s}')"
sidebar_h=$(( logical_h - bar_h ))

if [ "${1:-}" = "close" ] || eww active-windows 2>/dev/null | grep -q '^kw-sidebar'; then
  eww close kw-sidebar >/dev/null 2>&1 || true
else
  eww open kw-sidebar \
    --screen "$mon_idx" \
    --pos "0x0" \
    --size "${sidebar_w}x${sidebar_h}"
fi
