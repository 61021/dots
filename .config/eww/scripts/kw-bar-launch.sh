#!/usr/bin/env bash
# Open the bar on a single monitor (GDK index 0).
#
# Why this script is paranoid:
# - eww 0.5.0's `eww open` sometimes never exits and ends up owning its
#   own layer-shell surface in addition to the daemon's. That gives you
#   two stacked bars. So we kill any leftover `eww open` first.
# - flock fd 9 must NOT be inherited by any child eww process, otherwise
#   it keeps the lock after we exit and the next run blocks forever.
set -e

exec 9>/tmp/kw-bar-launch.lock
# Non-blocking: if another launcher is already running, just bail.
flock -n 9 || exit 0

# Reap any wedged `eww open` from a previous run (it would still hold a
# layer-shell surface and render a duplicate bar).
pkill -x -f "eww open .* bar" 2>/dev/null || true

# Make sure a daemon exists. Close fd 9 in the child so it doesn't
# inherit the lock.
if ! eww ping >/dev/null 2>&1; then
  eww daemon 9>&- >/dev/null 2>&1
  for _ in $(seq 1 30); do
    eww ping >/dev/null 2>&1 && break
    sleep 0.1
  done
fi

# Close any existing bar, then open a fresh one sized to monitor 0.
eww close bar >/dev/null 2>&1 || true
w=$(hyprctl monitors -j | jq '.[0] | (.width / .scale) | floor')
# Background + close fd 9 so a wedged eww open can't keep the lock.
eww open --screen 0 --size "${w}x36" bar 9>&- >/dev/null 2>&1 &
disown
