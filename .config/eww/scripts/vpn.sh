#!/usr/bin/env bash
# eww status module for openfortivpn.
# Outputs JSON with text/class/tooltip describing VPN state.

state_dir="${XDG_RUNTIME_DIR:-/tmp}/eww-vpn"
mkdir -p "$state_dir"
connecting_flag="$state_dir/connecting"

icon_on=""    # nf-md-shield_lock
icon_off=""   # nf-md-shield_off
icon_wait="" # nf-md-shield_sync

json() {
  # $1 text, $2 class, $3 tooltip
  printf '{"text":"%s","class":"%s","tooltip":"%s","alt":"%s"}\n' \
    "$1" "$2" "$3" "$2"
}

if pgrep -x openfortivpn >/dev/null 2>&1; then
  if ip -o link show ppp0 2>/dev/null | grep -q 'state UP\|UNKNOWN'; then
    rm -f "$connecting_flag"
    ip_addr=$(ip -4 -o addr show ppp0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
    [ -z "$ip_addr" ] && ip_addr="—"
    tooltip="VPN connected\rInterface: ppp0\rIP: ${ip_addr}\r\rLeft-click: disconnect"
    json "$icon_on  VPN" "connected" "$tooltip"
  else
    json "$icon_wait  VPN" "connecting" "Connecting to VPN…\r\rLeft-click: cancel"
  fi
elif [ -f "$connecting_flag" ]; then
  # If the flag is older than 30s without a process, drop it.
  if [ -n "$(find "$connecting_flag" -mmin +0.5 2>/dev/null)" ]; then
    rm -f "$connecting_flag"
    json "$icon_off  VPN" "disconnected" "VPN disconnected\r\rLeft-click: connect"
  else
    json "$icon_wait  VPN" "connecting" "Connecting to VPN…"
  fi
else
  json "$icon_off  VPN" "disconnected" "VPN disconnected\r\rLeft-click: connect\rRight-click: view log"
fi
