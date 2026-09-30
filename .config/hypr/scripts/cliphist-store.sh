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

in="$(mktemp -p "${XDG_RUNTIME_DIR:-/tmp}" cliphist-in.XXXXXX)" || exit 1
trap 'rm -f "$in"' EXIT
cat >"$in"
[[ -s $in ]] || exit 0

list="$(cliphist list | tr -d '\0')"
top="${list%%$'\n'*}"

# wl-clip-persist re-offers every selection it takes over: content already on
# top is a no-op, which also spares an image a second thumbnail render.
if [[ -n $top ]] && cliphist decode <<<"$top" | cmp -s - "$in"; then
    exit 0
fi

# Text that differs only in leading/trailing whitespace (a terminal line copy's
# trailing newline) replaces its older copies instead of sitting beside them.
# Candidates come from cliphist's preview: whitespace collapsed, 100 runes + "…".
dedupe_trimmed() {
    local text old line
    text="$(<"$in")"
    text="${text#"${text%%[![:space:]]*}"}"
    text="${text%"${text##*[![:space:]]}"}"
    [[ -n $text ]] || return 0
    while IFS= read -r line; do
        old="$(cliphist decode <<<"$line")"
        old="${old#"${old%%[![:space:]]*}"}"
        old="${old%"${old##*[![:space:]]}"}"
        [[ $old == "$text" ]] && cliphist delete <<<"$line"
    done < <(head -n 100 <<<"$list" | TEXT="$text" gawk -F'\t' '
        BEGIN {
            p = ENVIRON["TEXT"]
            gsub(/[[:space:]]+/, " ", p)
            if (length(p) > 100)
                p = substr(p, 1, 100) "…"
        }
        substr($0, index($0, "\t") + 1) == p')
}

if (($(stat -c %s "$in") <= 16384)) && ! grep -qaP '\x00' "$in"; then
    dedupe_trimmed
fi

cliphist store <"$in"

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
