#!/usr/bin/env bash
# Pick a wallpaper via rofi from ~/Pictures/Wallpapers + ~/Downloads/arcane wallpapers,
# apply via awww, regenerate matugen color schemes, save as "last".
set -e

DIRS=(
    "$HOME/Pictures/Wallpapers"
    "$HOME/Downloads/arcane wallpapers"
    "$HOME/stuff/constants"
)

# Build list
mapfile -t FILES < <(
    for d in "${DIRS[@]}"; do
        [[ -d "$d" ]] && find "$d" -maxdepth 3 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null
    done
)

[[ ${#FILES[@]} -eq 0 ]] && { notify-send "Wallpaper" "No wallpapers found"; exit 1; }

# Display basenames in rofi
choice="$(printf '%s\n' "${FILES[@]}" | awk -F/ '{print $NF" |"$0}' | \
    rofi -dmenu -i -p "Wallpaper" -theme "$HOME/.config/rofi/minimal.rasi")"

[[ -z "$choice" ]] && exit 0
WALL="${choice#*|}"
WALL="${WALL# }"   # strip leading space if any
[[ ! -f "$WALL" ]] && { notify-send "Wallpaper" "Not found: $WALL"; exit 1; }

# Set wallpaper directly (don't rely on matugen's hook)
awww img "$WALL" --transition-type wipe --transition-fps 60 --transition-duration 1

echo "$WALL" > "$HOME/.cache/last-wallpaper"

# Regenerate color schemes
matugen --source-color-index 0 image "$WALL" >/dev/null 2>&1 || true

notify-send "Wallpaper" "$(basename "$WALL")" -i "$WALL" 2>/dev/null || true
