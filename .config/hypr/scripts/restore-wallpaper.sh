#!/usr/bin/env bash
# Restore last wallpaper on login.
WALL="$(cat "$HOME/.cache/last-wallpaper" 2>/dev/null)"
[[ -z "$WALL" || ! -f "$WALL" ]] && WALL="$HOME/stuff/constants/wallpapers/car.jpg"
[[ ! -f "$WALL" ]] && exit 0

# Wait briefly for awww-daemon socket
for i in {1..30}; do
    awww query >/dev/null 2>&1 && break
    sleep 0.1
done

awww img "$WALL" --transition-type none >/dev/null 2>&1 || awww img "$WALL"
