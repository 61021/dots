#!/usr/bin/env bash
# Single source of truth for sidebar toggle states, as {"state","detail"} JSON.
# state: "connected"/"disconnected"; detail: short text the tile shows instead
# of On/Off ("" = plain On/Off). Used by the defpolls AND by kw-refresh.sh.
set -u

out() { jq -cn --arg s "$1" --arg d "${2:-}" '{state: $s, detail: $d}'; }

case "${1:-}" in
  bt)
    if rfkill list bluetooth | grep -q 'Soft blocked: no'; then
      mapfile -t names < <(timeout 2 bluetoothctl devices Connected 2>/dev/null | sed -n 's/^Device [0-9A-F:]\{17\} //p')
      case ${#names[@]} in
        0) out connected ;;
        1) out connected "${names[0]}" ;;
        *) out connected "${#names[@]} devices" ;;
      esac
    else
      out disconnected
    fi ;;
  dnd)
    if [ "$(dunstctl is-paused)" = "true" ]; then
      n=$(dunstctl count waiting 2>/dev/null || echo 0)
      [ "${n:-0}" -gt 0 ] 2>/dev/null && out disconnected "$n waiting" || out disconnected
    else
      out connected
    fi ;;
  eye)
    t=$(hyprctl hyprsunset temperature 2>/dev/null)
    if [ -n "$t" ] && [ "$t" -lt 6500 ] 2>/dev/null; then out connected "${t}K"; else out disconnected; fi ;;
  tv)   out "$(~/.config/eww/scripts/tv-mode.sh get)" ;;
  *)    out disconnected ;;
esac
