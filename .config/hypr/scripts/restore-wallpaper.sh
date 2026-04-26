#!/usr/bin/env bash
# Restore last wallpaper on login (matugen saves it here).
WALL="$(cat "$HOME/.cache/last-wallpaper" 2>/dev/null)"
[[ -z "$WALL" || ! -f "$WALL" ]] && WALL="$HOME/stuff/constants/car.jpg"
[[ -f "$WALL" ]] && matugen --source-color-index 0 image "$WALL"
