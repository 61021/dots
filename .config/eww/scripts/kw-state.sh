#!/usr/bin/env bash
# Single source of truth for sidebar toggle states ("connected"/"disconnected").
# Used by the defpolls AND by kw-refresh.sh for instant post-click feedback.
set -u
case "${1:-}" in
  bt)   rfkill list bluetooth | grep -q 'Soft blocked: no' && echo connected || echo disconnected ;;
  mute) wpctl get-volume @DEFAULT_AUDIO_SINK@   2>/dev/null | grep -q MUTED && echo disconnected || echo connected ;;
  mic)  wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED && echo disconnected || echo connected ;;
  dnd)  [ "$(dunstctl is-paused)" = "true" ] && echo disconnected || echo connected ;;
  eye)  pgrep -x hyprsunset >/dev/null && echo connected || echo disconnected ;;
  tv)   ~/.config/eww/scripts/tv-mode.sh get ;;
  *)    echo disconnected ;;
esac
