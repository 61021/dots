#!/usr/bin/env bash
# Toggle openfortivpn. Uses pkexec for the graphical sudo prompt.

config="$HOME/.config/openfortivpn/config"
state_dir="${XDG_RUNTIME_DIR:-/tmp}/waybar-vpn"
mkdir -p "$state_dir"
log="$state_dir/openfortivpn.log"
connecting_flag="$state_dir/connecting"

if pgrep -x openfortivpn >/dev/null 2>&1; then
  pkexec pkill -INT -x openfortivpn
  rm -f "$connecting_flag"
  exit 0
fi

if [ ! -r "$config" ]; then
  notify-send -u critical "VPN" "Config not found at $config"
  exit 1
fi

# Mark connecting so the indicator updates immediately.
touch "$connecting_flag"
pkill -RTMIN+8 waybar 2>/dev/null

# Run openfortivpn detached. setsid keeps it alive after this script exits.
setsid -f bash -c "pkexec openfortivpn -c '$config' >'$log' 2>&1" >/dev/null 2>&1 &

# Give it a moment, then refresh waybar.
sleep 0.3
pkill -RTMIN+8 waybar 2>/dev/null
