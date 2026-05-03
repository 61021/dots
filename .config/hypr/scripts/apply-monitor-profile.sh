#!/usr/bin/env bash
# Apply a monitor layout based on what's currently connected.
#   0 externals -> laptop only (cafe).
#   1 external  -> laptop on left, external to its right.
#   2+ externals -> laptop off, externals arranged per WORK_ORDER (work / TV+ext).
# All keyword changes are batched so Hyprland never sees an overlapping state.
set -euo pipefail

WORK_ORDER=("HDMI-A-1" "DP-1" "DP-2")

batch=()
push() { batch+=("keyword monitor $1"); }

mons_json="$(hyprctl -j monitors all)"
mapfile -t externals < <(echo "$mons_json" | jq -r '.[] | select(.name != "eDP-1") | .name')
n=${#externals[@]}

case "$n" in
  0)
    push "eDP-1,2880x1800@120,0x0,2.0"
    ;;
  1)
    push "eDP-1,2880x1800@120,0x0,2.0"
    # Laptop is 2880/2 = 1440 logical wide, so the external sits at x=1440.
    push "${externals[0]},preferred,1440x0,1.0"
    ;;
  *)
    # Park laptop far to the right so its tracked geometry doesn't collide
    # with the externals' positions; disable it in a follow-up step.
    push "eDP-1,2880x1800@120,99999x0,2.0"
    ordered=()
    for name in "${WORK_ORDER[@]}"; do
      for ext in "${externals[@]}"; do
        [[ "$ext" == "$name" ]] && ordered+=("$ext")
      done
    done
    for ext in $(printf '%s\n' "${externals[@]}" | sort); do
      [[ " ${ordered[*]} " == *" $ext "* ]] || ordered+=("$ext")
    done
    x=0
    for ext in "${ordered[@]}"; do
      push "$ext,preferred,${x}x0,1.0"
      # Advance by the external's actual logical width if known, else 1920.
      w=$(echo "$mons_json" | jq -r --arg n "$ext" '.[] | select(.name==$n) | .width // 1920')
      x=$((x + ${w:-1920}))
    done
    ;;
esac

# Apply all monitor keywords atomically (avoids overlap errors during the swap).
joined="$(printf ' ; %s' "${batch[@]}")"
hyprctl --batch "${joined# ; }" >/dev/null

# Disable laptop only after externals are safely placed (work/TV+ext mode).
if [[ "$n" -ge 2 ]]; then
  hyprctl keyword monitor "eDP-1,disable" >/dev/null
fi

# Refresh bars (one per active monitor).
~/.config/eww/scripts/kw-bar-launch.sh >/dev/null 2>&1 || true

# Work-mode (2+ externals) extras: warm up the work GitHub SSH key.
if [[ "$n" -ge 2 ]]; then
  ssh -T git@github.com-work >/dev/null 2>&1 || true
fi
