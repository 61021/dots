#!/usr/bin/env bash
# wl-paste --watch hook: store clipboard changes into cliphist, skipping offers
# that password managers mark sensitive (x-kde-passwordManagerHint). Image
# entries get their picker thumbnail pre-rendered here, in the background, so
# the picker never pays that cost at open time.
set -u

types="$(wl-paste --list-types 2>/dev/null)" || types=""

if grep -qx 'x-kde-passwordManagerHint' <<<"$types"; then
    cat >/dev/null # drain stdin so the writer doesn't hit a broken pipe
    exit 0
fi

cliphist store
# Copy acknowledgment blip, after the password-manager filter above, so
# sensitive copies stay silent too.
~/.local/bin/kw-sound -v .35 -g 800 message &

grep -q '^image/' <<<"$types" || exit 0

thumbs="$HOME/.cache/cliphist/thumbs"
img_re='^\[\[ binary data [0-9.]+ [A-Za-z]+ [a-z0-9]+ [0-9]+x[0-9]+ \]\]$'
newest="$(cliphist list | head -n1 | tr -d '\0')"
[[ ${newest#*$'\t'} =~ $img_re ]] || exit 0
id="${newest%%$'\t'*}"
[[ -f "$thumbs/$id.png" ]] && exit 0
mkdir -p "$thumbs"
{ cliphist decode <<<"$newest" |
    magick - -auto-orient -thumbnail '384x192>' "png:$thumbs/.$id.$$" &&
    mv -f "$thumbs/.$id.$$" "$thumbs/$id.png" ||
    rm -f "$thumbs/.$id.$$"; } &
