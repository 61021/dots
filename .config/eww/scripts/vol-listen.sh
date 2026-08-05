#!/usr/bin/env bash
# Streams the sink volume percent for the sidebar slider's `deflisten`.
# Event-driven via pactl, so slider drags never fight a stale poll.
set -u

emit() { ~/.config/eww/scripts/volume.sh get; }

emit
pactl subscribe 2>/dev/null |
while IFS= read -r line; do
  case "$line" in
    *" on sink "*|*" on server"*)
      while IFS= read -r -t 0.05 _; do :; done
      emit
      ;;
  esac
done
