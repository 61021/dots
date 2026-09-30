#!/usr/bin/env bash
# Audio → JSON: {"icon": "...", "label": "55%", "mic_muted": false}
ICONS=~/.config/eww/icons
out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
vol=$(echo "$out" | awk '{printf "%d", $2*100}')
mic=false
wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED && mic=true
if echo "$out" | grep -q MUTED || [ -z "$vol" ]; then
  printf '{"icon":"%s/speaker-x.svg","label":"%s%%","mic_muted":%s}\n' "$ICONS" "${vol:-0}" "$mic"
  exit
fi
if   [ "$vol" -ge 66 ]; then ic="speaker-high"
elif [ "$vol" -ge 33 ]; then ic="speaker-low"
elif [ "$vol" -gt  0 ]; then ic="speaker-low"
else                          ic="speaker-none"
fi
printf '{"icon":"%s/%s.svg","label":"%s%%","mic_muted":%s}\n' "$ICONS" "$ic" "$vol" "$mic"
