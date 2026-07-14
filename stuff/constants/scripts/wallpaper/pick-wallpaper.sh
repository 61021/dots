#!/usr/bin/env bash
# Pick a wallpaper via rofi (with thumbnails) and apply via awww.
set -e

DIRS=(
    "$HOME/stuff/constants/wallpapers"
)

# Build list of wallpapers
mapfile -t FILES < <(
    for d in "${DIRS[@]}"; do
        [[ -d "$d" ]] && find "$d" -maxdepth 3 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null
    done | sort
)

[[ ${#FILES[@]} -eq 0 ]] && { notify-send "Wallpaper" "No wallpapers found"; exit 1; }

# Generate cached thumbnails (square crops) for snappier rofi rendering.
THUMB_DIR="$HOME/.cache/wallpaper-thumbs"
mkdir -p "$THUMB_DIR"

thumb_for() {
    local src="$1"
    local hash
    hash="$(printf '%s' "$src" | sha1sum | cut -c1-16)"
    local out="$THUMB_DIR/${hash}.png"
    if [[ ! -f "$out" || "$src" -nt "$out" ]]; then
        if command -v magick >/dev/null 2>&1; then
            magick "$src" -auto-orient -thumbnail 256x256^ -gravity center -extent 256x256 "$out" 2>/dev/null || cp -f "$src" "$out"
        elif command -v convert >/dev/null 2>&1; then
            convert "$src" -auto-orient -thumbnail 256x256^ -gravity center -extent 256x256 "$out" 2>/dev/null || cp -f "$src" "$out"
        else
            out="$src"
        fi
    fi
    printf '%s' "$out"
}

# Build rofi entries: "<basename>\0icon\x1f<thumb>\n"
# (Stream directly — bash variables can't hold NUL bytes.)
choice="$(
    for f in "${FILES[@]}"; do
        name="$(basename "$f")"
        name="${name%.*}"
        icon="$(thumb_for "$f")"
        printf '%s\0icon\x1f%s\n' "$name" "$icon"
    done | rofi \
        -dmenu -i -p "Wallpaper" \
        -show-icons \
        -theme "$HOME/.config/rofi/wallpaper.rasi"
)"

[[ -z "$choice" ]] && exit 0

# Map chosen basename back to full path
WALL=""
for f in "${FILES[@]}"; do
    base="$(basename "$f")"
    [[ "${base%.*}" == "$choice" ]] && WALL="$f" && break
done
[[ -z "$WALL" || ! -f "$WALL" ]] && { notify-send "Wallpaper" "Not found: $choice"; exit 1; }

# Apply
awww img "$WALL" --transition-type wipe --transition-fps 60 --transition-duration 1

echo "$WALL" > "$HOME/.cache/last-wallpaper"

notify-send "Wallpaper" "$(basename "$WALL")" -i "$WALL" 2>/dev/null || true
