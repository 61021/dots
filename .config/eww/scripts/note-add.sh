#!/usr/bin/env bash
# Append a line to ~/notes.md with timestamp
set -eu
note="$*"
[ -z "$note" ] && exit 0
mkdir -p "$(dirname ~/notes.md)"
printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M')" "$note" >> ~/notes.md
