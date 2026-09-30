#!/usr/bin/env bash
# Streams audio state for the bar's `deflisten`.
# Emits on sink/source/server changes (volume, mute, mic mute, default-device switch).
set -u

emit() { ~/.config/eww/scripts/bar/audio.sh; }

emit
pactl subscribe 2>/dev/null |
while IFS= read -r line; do
  case "$line" in
    *" on sink "*|*" on source "*|*" on server"*)
      # Coalesce volume-key repeats.
      while IFS= read -r -t 0.05 _; do :; done
      emit
      ;;
  esac
done
