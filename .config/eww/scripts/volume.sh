#!/usr/bin/env bash
# Volume helpers: get/set as percent (0..100). No arg = print percent.
set -eu
case "${1:-get}" in
  get)
    wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf "%d\n", $2*100}'
    ;;
  set)
    pct="${2:-50}"
    wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1 || true
    wpctl set-volume @DEFAULT_AUDIO_SINK@ "$(awk -v p="$pct" 'BEGIN{printf "%.2f", p/100}')"
    ;;
esac
