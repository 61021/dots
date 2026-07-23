#!/usr/bin/env bash
# Open one bar per active monitor, bound by output name (eww window args).
#
# eww 0.5.0 is unreliable about reusing an existing daemon: `eww daemon`
# happily spawns a second one, and `eww open` sometimes wedges and ends
# up owning its own layer-shell surface. To avoid stacked duplicate bars
# we nuke everything every time and start fresh. After opening we verify
# each bar actually RENDERED (surfaces opened mid-hotplug can exist but
# paint nothing) and retry once if not.
set -e

exec 9>/tmp/kw-bar-launch.lock
# Non-blocking: if another launcher is already running, just bail.
flock -n 9 || exit 0

mons() { hyprctl -j monitors | jq -r '.[] | select(.disabled | not) | "\(.name) \((.width / .scale) | floor) \(.scale)"'; }

# Map hyprland output names to GDK monitor indices by matching logical
# geometry. GDK's own identifiers are model names, which are ambiguous
# with two identical displays.
gdk_index_map() { # stdout: "<name> <gdk_index>" per active monitor
  python3 - <<'EOF'
import json, subprocess
import gi
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk

hypr = json.loads(subprocess.run(["hyprctl", "-j", "monitors"], capture_output=True, text=True).stdout)
display = Gdk.Display.get_default()
gdk = []
for i in range(display.get_n_monitors()):
    geo = display.get_monitor(i).get_geometry()
    gdk.append((i, geo.x, geo.y))
for m in hypr:
    if m.get("disabled"):
        continue
    idx = next((i for i, x, y in gdk if int(m["x"]) == x and int(m["y"]) == y), 0)
    print(m["name"], idx)
EOF
}

launch_all() {
  # Kill every eww process so we start from a known state.
  pkill -x eww 2>/dev/null || true
  for _ in $(seq 1 20); do
    pgrep -x eww >/dev/null || break
    sleep 0.1
  done

  # pkill -x eww doesn't reach deflisten children (bash/python); orphaned to
  # PID 1 they idle forever since they only write on events. Reap them here.
  pkill -f "$HOME/.config/eww/scripts/(bar/|vol-listen)" 2>/dev/null || true
  # ...and the long-lived CLIs those listeners spawn — killing the wrapper
  # orphans them and they only die on their next (possibly never) write.
  pkill -f 'playerctl --follow' 2>/dev/null || true
  pkill -f 'nmcli monitor' 2>/dev/null || true
  pkill -fx 'pactl subscribe' 2>/dev/null || true

  # Start a fresh daemon. Close fd 9 so it doesn't inherit the lock.
  eww daemon 9>&- >/dev/null 2>&1
  for _ in $(seq 1 30); do
    eww ping >/dev/null 2>&1 && break
    sleep 0.1
  done

  local expected=0
  local -A gdk_idx=()
  while read -r name idx; do gdk_idx["$name"]=$idx; done < <(gdk_index_map)
  while read -r name w _; do
    eww open bar --id "bar-$name" --screen "${gdk_idx[$name]:-0}" \
      --arg "monitor=$name" --size "${w}x36" 9>&- >/dev/null 2>&1 &
    disown
    expected=$((expected + 1))
  done < <(mons)

  # Wait until the daemon reports every bar open, then reap stray CLIs
  # (SIGTERM is sometimes ignored by eww 0.5.0, so SIGKILL).
  for _ in $(seq 1 40); do
    n=$(eww active-windows 2>/dev/null | grep -c '^bar-' || true)
    [ "$n" -ge "$expected" ] && break
    sleep 0.1
  done
  pkill -9 -f "eww open .* bar" 2>/dev/null || true
}

# A rendered bar always shows the white "KW" launcher text in the top-left
# strip; a wedged surface shows wallpaper there. Returns 0 if every
# monitor's strip contains bright pixels.
verify_render() {
  sleep 0.7
  while read -r name _ scale; do
    grim -o "$name" -t png /tmp/kw-bar-verify.png 2>/dev/null || return 0 # can't check, assume ok
    python3 -W ignore - "$scale" <<'EOF' || return 1
import sys
from PIL import Image
scale = float(sys.argv[1])
im = Image.open("/tmp/kw-bar-verify.png").convert("RGB")
strip = im.crop((0, 0, int(80 * scale), int(36 * scale)))
ok = any(r > 200 and g > 200 and b > 200 for r, g, b in strip.getdata())
sys.exit(0 if ok else 1)
EOF
  done < <(mons)
  return 0
}

launch_all
verify_render || { launch_all; verify_render || true; }
