#!/usr/bin/env bash
# Toggle the kw-sidebar on the currently focused monitor, sized so it
# starts below the waybar and never overflows the screen.

mon_json="$(hyprctl -j monitors | jq '.[] | select(.focused==true)')"
mon_id="$(echo "$mon_json"    | jq -r '.id')"
mon_w="$(echo "$mon_json"     | jq -r '.width')"
mon_h="$(echo "$mon_json"     | jq -r '.height')"
mon_scale="$(echo "$mon_json" | jq -r '.scale')"
waybar_h=40
sidebar_w=240

# Convert physical monitor dimensions to logical pixels using the monitor scale.
logical_w="$(awk -v v="$mon_w" -v s="$mon_scale" 'BEGIN{printf "%d", v/s}')"
logical_h="$(awk -v v="$mon_h" -v s="$mon_scale" 'BEGIN{printf "%d", v/s}')"
sidebar_h=$(( logical_h - waybar_h ))
scrim_w=$(( logical_w - sidebar_w ))

if [ "$1" = "close" ] || eww active-windows 2>/dev/null | grep -q '^kw-sidebar'; then
  eww close kw-sidebar kw-scrim
  # Pre-fetch the next quote so it's ready the next time the sidebar opens.
  ( quote="$(~/.config/eww/scripts/quote.sh)"; eww update "kw-quote=$quote" ) &
else
  eww open kw-sidebar \
    --screen "$mon_id" \
    --pos "0x0" \
    --size "${sidebar_w}x${sidebar_h}"
  eww open kw-scrim \
    --screen "$mon_id" \
    --pos "${sidebar_w}x0" \
    --size "${scrim_w}x${sidebar_h}"
fi
