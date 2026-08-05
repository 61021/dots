#!/usr/bin/env sh
# Bar workspace-area scroll ($1 = up|down) -> prev/next workspace on the
# bar's monitor. Split out of bar.yuck: the Lua dispatch string plus the
# up/down branch was unreadable as an inline yuck onscroll handler.
if [ "$1" = "up" ]; then ws="m-1"; else ws="m+1"; fi
exec hyprctl dispatch "hl.dsp.focus({ workspace = [[$ws]] })" >/dev/null
