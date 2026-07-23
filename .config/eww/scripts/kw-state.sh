#!/usr/bin/env bash
# Single source of truth for sidebar toggle states ("connected"/"disconnected").
# Used by the defpolls AND by kw-refresh.sh for instant post-click feedback.
set -u
case "${1:-}" in
  bt)   rfkill list bluetooth | grep -q 'Soft blocked: no' && echo connected || echo disconnected ;;
  dnd)  [ "$(dunstctl is-paused)" = "true" ] && echo disconnected || echo connected ;;
  eye)  t=$(hyprctl hyprsunset temperature 2>/dev/null)
        if [ -n "$t" ] && [ "$t" -lt 6500 ] 2>/dev/null; then echo connected; else echo disconnected; fi ;;
  tv)   ~/.config/eww/scripts/tv-mode.sh get ;;
  *)    echo disconnected ;;
esac
