#!/usr/bin/env bash
# Open nmtui in a floating kitty window, fully detached from eww.
setsid -f kitty --class dotfiles-floating -e nmtui >/dev/null 2>&1
