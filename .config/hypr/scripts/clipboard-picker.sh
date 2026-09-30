#!/usr/bin/env bash
# Clipboard history picker ($mainMod+V in hyprland.lua): pinned entries on top,
# cliphist history below with image thumbnails. Enter copies and pastes into
# the window that had focus, Shift+Enter only copies, Alt+t pins or unpins,
# Alt+o opens the whole entry, Alt+d deletes (unpins on a pinned row).
#   --warm   only (re)generate/prune thumbnails, no UI
set -euo pipefail
shopt -s nullglob

thumbs="$HOME/.cache/cliphist/thumbs"
pins="$HOME/.local/share/cliphist/pins"
pin_meta="$HOME/.cache/cliphist/pin-thumbs"
pin_icon="$HOME/.config/rofi/icons/push-pin.svg"
theme="$HOME/.config/rofi/clipboard.rasi"
img_re='^\[\[ binary data ([0-9.]+ [A-Za-z]+) ([a-z0-9]+) ([0-9]+)x([0-9]+) \]\]$'
mkdir -p "$thumbs" "$pins" "$pin_meta"

# A rare entry can carry a NUL byte in its preview; strip them (display-only,
# entries are resolved by their id prefix) so bash doesn't warn on every open.
list="$(cliphist list | tr -d '\0')"
# Pin files are named by pin time, so glob order is pin order.
pin_files=("$pins"/*)
npins=${#pin_files[@]}

# stdin: image bytes. Temp file + rename keeps a concurrent hook run from
# tearing the file.
render_thumb() {
    local tmp="${1%/*}/.${1##*/}.$$"
    magick - -auto-orient -thumbnail '384x192>' "png:$tmp" &&
        mv -f "$tmp" "$1" ||
        rm -f "$tmp"
}

# Thumbnails for image entries the store hook hasn't rendered yet (normally
# none), and for image pins whose cached thumbnail was cleared.
gen_missing() {
    local line id f name
    while IFS= read -r line; do
        [[ ${line#*$'\t'} =~ $img_re ]] || continue
        id="${line%%$'\t'*}"
        [[ -f "$thumbs/$id.png" ]] && continue
        cliphist decode <<<"$line" | render_thumb "$thumbs/$id.png" &
    done < <(grep -P '^\d+\t\[\[ binary data ' <<<"$list" || true)
    for f in "${pin_files[@]}"; do
        name="${f##*/}"
        [[ $name == *.txt || -f "$pin_meta/$name.png" ]] && continue
        render_thumb "$pin_meta/$name.png" <"$f" &
        magick identify -format "image/${name##*.} · %w×%h\n" "$f[0]" >"$pin_meta/$name.label" &
    done
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

[[ -n $list ]] || ((npins)) || exit 0
~/.local/bin/kw-sound -v .55 -g 300 completion-rotation &
entries=()
[[ -n $list ]] && mapfile -t entries <<<"$list"

# Enter pastes into the window that was focused before rofi took the keyboard.
target_addr="" target_class=""
read -r target_addr target_class < <(hyprctl activewindow -j |
    jq -r '"\(.address // "") \(.class // "")"') || true

gen_missing
prune_stale & # housekeeping; never blocks the UI

# One display row per pin, then per history entry, same order (rofi -format i
# maps back by index): id column stripped, image rows get their thumbnail.
menu() {
    if ((npins)); then
        gawk -v meta="$pin_meta" -v icon="$pin_icon" '
            BEGIN { RS = "^$" }
            BEGINFILE {
                name = FILENAME
                sub(/.*\//, "", name)
                seen = 0
                if (name !~ /\.txt$/) {
                    seen = 1
                    label = "image"
                    getline label < (meta "/" name ".label")
                    close(meta "/" name ".label")
                    sub(/\n+$/, "", label)
                    printf "%s\0icon\x1f%s/%s.png\n", label, meta, name
                    nextfile
                }
            }
            {
                seen = 1
                s = $0
                gsub(/[[:space:][:cntrl:]]+/, " ", s)
                sub(/^ /, "", s)
                sub(/ $/, "", s)
                if (length(s) > 100)
                    s = substr(s, 1, 100) "…"
                printf "%s\0icon\x1f%s\n", s, icon
            }
            ENDFILE { if (!seen) printf "(empty)\0icon\x1f%s\n", icon }
        ' "${pin_files[@]}"
    fi
    [[ -n $list ]] || return 0
    gawk -v thumbs="$thumbs" '{
        preview = substr($0, index($0, "\t") + 1)
        if (match(preview, /^\[\[ binary data ([0-9.]+ [A-Za-z]+) ([a-z0-9]+) ([0-9]+)x([0-9]+) \]\]$/, m))
            printf "image/%s · %s×%s · %s\0icon\x1f%s/%s.png\n",
                m[2], m[3], m[4], m[1], thumbs, substr($0, 1, index($0, "\t") - 1)
        else
            print preview
    }' <<<"$list"
}

# kitty pastes on Ctrl+Shift+V, everything else on Ctrl+V.
paste_into_target() {
    [[ $target_addr == 0x* ]] || return 0
    local mods=CTRL
    [[ $target_class == kitty ]] && mods="CTRL SHIFT"
    hyprctl eval "hl.dispatch(hl.dsp.send_shortcut({ mods = \"$mods\", key = \"V\", window = \"address:$target_addr\" }))" >/dev/null
}

# Explicit MIME for images so paste targets accept the data.
copy_entry() {
    if [[ ${line#*$'\t'} =~ $img_re ]]; then
        local ext="${BASH_REMATCH[2]}"
        [[ $ext == jpg ]] && ext=jpeg
        cliphist decode <<<"$line" | wl-copy --type "image/$ext"
    else
        cliphist decode <<<"$line" | wl-copy
    fi
}

copy_pin() {
    if [[ $pin == *.txt ]]; then
        wl-copy <"$pin"
    else
        wl-copy --type "image/${pin##*.}" <"$pin"
    fi
}

pin_entry() {
    local name="${EPOCHREALTIME/./}" ext=txt label="" f
    if [[ ${line#*$'\t'} =~ $img_re ]]; then
        ext="${BASH_REMATCH[2]}"
        [[ $ext == jpg ]] && ext=jpeg
        label="image/$ext · ${BASH_REMATCH[3]}×${BASH_REMATCH[4]} · ${BASH_REMATCH[1]}"
    fi
    cliphist decode <<<"$line" >"$pins/.$name.$ext"
    for f in "${pin_files[@]}"; do
        if cmp -s "$pins/.$name.$ext" "$f"; then
            rm -f "$pins/.$name.$ext"
            return 0
        fi
    done
    mv -f "$pins/.$name.$ext" "$pins/$name.$ext"
    [[ $ext == txt ]] && return 0
    printf '%s\n' "$label" >"$pin_meta/$name.$ext.label"
    render_thumb "$pin_meta/$name.$ext.png" <"$pins/$name.$ext"
}

unpin() {
    rm -f "$pin" "$pin_meta/${pin##*/}.png" "$pin_meta/${pin##*/}.label"
}

# Blocks until the viewer closes; the caller then reopens the picker.
view_file() {
    if [[ $2 == image ]]; then
        feh --title 'Clipboard image' -- "$1" || true
    else
        kitty --class dotfiles-floating --title 'Clipboard entry' less -R -- "$1" || true
    fi
}

view_entry() {
    local kind=text tmp
    [[ ${line#*$'\t'} =~ $img_re ]] && kind=image
    tmp="$(mktemp -p "$XDG_RUNTIME_DIR" clip-view.XXXXXX)"
    cliphist decode <<<"$line" >"$tmp"
    view_file "$tmp" "$kind"
    rm -f "$tmp"
}

active=()
((npins)) && active=(-a "0-$((npins - 1))")
mesg="${#entries[@]} entries"
((npins)) && mesg="$npins pinned, $mesg"

set +e
idx="$(menu | rofi -dmenu -i -p "Clipboard" -theme "$theme" -format i \
    -matching fuzzy -sort -sorting-method fzf "${active[@]}" \
    -kb-accept-alt '' \
    -kb-custom-1 Alt+d -kb-custom-2 Shift+Return -kb-custom-3 Alt+t -kb-custom-4 Alt+o \
    -mesg "$mesg    Enter paste    Shift+Enter copy    Alt+t pin    Alt+o view    Alt+d delete")"
rc=$?
set -e

# Resolving through the stored line keeps the right entry even if the history
# gained items while the picker was open.
[[ $idx =~ ^[0-9]+$ ]] || exit 0

if ((idx < npins)); then
    pin="${pin_files[$idx]}"
    case $rc in
    0 | 11)
        copy_pin
        if ((rc == 0)); then paste_into_target; fi
        ;;
    10 | 12)
        ~/.local/bin/kw-sound -v .6 -g 80 button-pressed &
        unpin
        exec "$0"
        ;;
    13)
        if [[ $pin == *.txt ]]; then view_file "$pin" text; else view_file "$pin" image; fi
        exec "$0"
        ;;
    esac
    exit 0
fi

line="${entries[$((idx - npins))]}"
case $rc in
0 | 11)
    copy_entry
    if ((rc == 0)); then paste_into_target; fi
    ;;
10)
    ~/.local/bin/kw-sound -v .6 -g 80 button-pressed &
    cliphist delete <<<"$line"
    rm -f "$thumbs/${line%%$'\t'*}.png"
    exec "$0"
    ;;
12)
    ~/.local/bin/kw-sound -v .6 -g 80 button-pressed &
    pin_entry
    exec "$0"
    ;;
13)
    view_entry
    exec "$0"
    ;;
esac
