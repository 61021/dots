#!/usr/bin/env bash
# Open the bar on a single monitor (GDK index 0).
#
# eww 0.5.0 is unreliable about reusing an existing daemon: `eww daemon`
# happily spawns a second one, and `eww open` sometimes wedges and ends
# up owning its own layer-shell surface. To avoid stacked duplicate bars
# we nuke everything every time and start fresh.
set -e

exec 9>/tmp/kw-bar-launch.lock
# Non-blocking: if another launcher is already running, just bail.
flock -n 9 || exit 0

# Kill every eww process so we start from a known state.
pkill -x eww 2>/dev/null || true
# Wait for them to actually die.
for _ in $(seq 1 20); do
  pgrep -x eww >/dev/null || break
  sleep 0.1
done

# Start a fresh daemon. Close fd 9 so it doesn't inherit the lock.
eww daemon 9>&- >/dev/null 2>&1
for _ in $(seq 1 30); do
  eww ping >/dev/null 2>&1 && break
  sleep 0.1
done

# Open the bar sized to monitor 0's logical width.
w=$(hyprctl monitors -j | jq '.[0] | (.width / .scale) | floor')
eww open --screen 0 --size "${w}x36" bar 9>&- >/dev/null 2>&1 &
open_pid=$!
disown

# Wait until the daemon reports the bar as open, then reap the CLI in
# case it wedged (would otherwise own a duplicate layer-shell surface).
# SIGTERM is sometimes ignored by eww 0.5.0, so use SIGKILL and also
# sweep any other `eww open ... bar` strays.
for _ in $(seq 1 30); do
  eww active-windows 2>/dev/null | grep -q '^bar:' && break
  sleep 0.1
done
kill -9 "$open_pid" 2>/dev/null || true
pkill -9 -f "eww open .* bar" 2>/dev/null || true
