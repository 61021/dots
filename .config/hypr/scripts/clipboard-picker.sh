#!/usr/bin/env bash
# Clipboard history picker ($mainMod+V in hyprland.conf): cliphist behind rofi,
# with image thumbnails, correct image MIME on re-copy, and Alt+d to delete.
#   --warm   only (re)generate/prune thumbnails, no UI
set -euo pipefail
shopt -s nullglob

thumbs="$HOME/.cache/cliphist/thumbs"
theme="$HOME/.config/rofi/clipboard.rasi"
img_re='^\[\[ binary data ([0-9.]+ [A-Za-z]+) ([a-z0-9]+) ([0-9]+)x([0-9]+) \]\]$'
mkdir -p "$thumbs"

# A rare entry can carry a NUL byte in its preview; strip them (display-only,
# entries are resolved by their id prefix) so bash doesn't warn on every open.
list="$(cliphist list | tr -d '\0')"

# Thumbnails for image entries the store hook hasn't rendered yet (normally
# none). Temp file + rename keeps a concurrent hook run from tearing the file.
gen_missing() {
    local line id
    while IFS= read -r line; do
        [[ ${line#*$'\t'} =~ $img_re ]] || continue
        id="${line%%$'\t'*}"
        [[ -f "$thumbs/$id.png" ]] && continue
        { cliphist decode <<<"$line" |
            magick - -auto-orient -thumbnail '384x192>' "png:$thumbs/.$id.$$" &&
            mv -f "$thumbs/.$id.$$" "$thumbs/$id.png" ||
            rm -f "$thumbs/.$id.$$"; } &
    done < <(grep -P '^\d+\t\[\[ binary data ' <<<"$list" || true)
    wait
}

# Drop thumbnails whose entries aged out of the history. No subprocess spawns.
prune_stale() {
    local f id
    local -A live=()
    while IFS=$'\t' read -r id _; do live[$id]=1; done <<<"$list"
    for f in "$thumbs"/*.png; do
        id="${f##*/}"
        id="${id%.png}"
        [[ ${live[$id]:-} ]] || rm -f "$f"
    done
}

if [[ ${1:-} == --warm ]]; then
    gen_missing
    prune_stale
    exit 0
fi

[[ -n $list ]] || exit 0
~/.local/bin/kw-sound -v .55 -g 300 completion-rotation &
mapfile -t entries <<<"$list"

gen_missing
prune_stale & # housekeeping; never blocks the UI

# One display row per history entry, same order (rofi -format i maps back by
# index): id column stripped, image rows get their thumbnail attached.
menu() {
    gawk -v thumbs="$thumbs" '{
        preview = substr($0, index($0, "\t") + 1)
        if (match(preview, /^\[\[ binary data ([0-9.]+ [A-Za-z]+) ([a-z0-9]+) ([0-9]+)x([0-9]+) \]\]$/, m))
            printf "image/%s · %s×%s · %s\0icon\x1f%s/%s.png\n",
                m[2], m[3], m[4], m[1], thumbs, substr($0, 1, index($0, "\t") - 1)
        else
            print preview
    }' <<<"$list"
}

set +e
idx="$(menu | rofi -dmenu -i -p "Clipboard" -theme "$theme" -format i \
    -matching fuzzy -sort -sorting-method fzf \
    -kb-custom-1 Alt+d \
    -mesg "${#entries[@]} entries    Enter: copy    Alt+d: delete")"
rc=$?
set -e

# Resolving through the stored line keeps the right entry even if the history
# gained items while the picker was open.
[[ $idx =~ ^[0-9]+$ ]] || exit 0
line="${entries[$idx]}"

case $rc in
0)
    # explicit MIME for images so paste targets accept the data
    if [[ ${line#*$'\t'} =~ $img_re ]]; then
        ext="${BASH_REMATCH[2]}"
        [[ $ext == jpg ]] && ext=jpeg
        cliphist decode <<<"$line" | wl-copy --type "image/$ext"
    else
        cliphist decode <<<"$line" | wl-copy
    fi
    ;;
10)
    ~/.local/bin/kw-sound -v .6 -g 80 button-pressed &
    cliphist delete <<<"$line"
    rm -f "$thumbs/${line%%$'\t'*}.png"
    exec "$0"
    ;;
esac
