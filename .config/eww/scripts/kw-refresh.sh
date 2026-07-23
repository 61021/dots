#!/usr/bin/env bash
# Push a fresh sidebar state to eww right after a toggle click, so the
# button reflects the change instantly instead of waiting for the poll.
set -u
name="${1:-}"
case "$name" in
  bt|mute|mic|dnd|eye|tv)
    eww update "${name}-state=$(~/.config/eww/scripts/kw-state.sh "$name")" 2>/dev/null ;;
  vpn)
    # Async connect: this shows "connecting" immediately; the poll follows up.
    (sleep 0.3; eww update "vpn-state=$(~/.config/eww/scripts/vpn.sh | jq -r .class)" 2>/dev/null) & ;;
  notif)
    eww update "notif-hist=$(~/.config/eww/scripts/kw-notif-history.sh)" 2>/dev/null ;;
  *) exit 0 ;;
esac
