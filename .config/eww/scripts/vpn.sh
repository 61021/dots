#!/usr/bin/env bash
# eww status module for the dev2-uat OpenVPN connection (NetworkManager).
# Outputs JSON with text/class/tooltip describing VPN state.
set -u

conn="dev2-uat-vpn"

if [ "${1:-}" = "settings" ]; then
  uuid=$(nmcli -g connection.uuid connection show "$conn" 2>/dev/null)
  setsid -f nm-connection-editor ${uuid:+--edit="$uuid"} >/dev/null 2>&1
  exit 0
fi
state_dir="${XDG_RUNTIME_DIR:-/tmp}/eww-vpn"
mkdir -p "$state_dir"
connecting_flag="$state_dir/connecting"

icon_on=""    # nf-md-shield_lock
icon_off=""   # nf-md-shield_off
icon_wait="" # nf-md-shield_sync

json() {
  # $1 text, $2 class, $3 tooltip, $4 tile detail (optional)
  printf '{"text":"%s","class":"%s","tooltip":"%s","alt":"%s","detail":"%s"}\n' \
    "$1" "$2" "$3" "$2" "${4:-}"
}

gstate=$(nmcli -g GENERAL.STATE connection show "$conn" 2>/dev/null | head -1)
dev=""
ip_addr=""

if [ "$gstate" = "activated" ]; then
  rm -f "$connecting_flag"
  ip_addr=$(nmcli -g IP4.ADDRESS connection show "$conn" 2>/dev/null | head -1 | cut -d/ -f1)
  if [ -n "$ip_addr" ]; then
    dev=$(ip -4 -o addr show 2>/dev/null | awk -v a="$ip_addr" '$4 ~ ("^" a "/"){print $2; exit}')
  fi
  [ -z "$dev" ] && dev="tun0"
  [ -z "$ip_addr" ] && ip_addr="n/a"
  tooltip="VPN connected\nInterface: ${dev}\nIP: ${ip_addr}\n\nLeft-click: disconnect\nRight-click: settings"
  json "$icon_on  VPN" "connected" "$tooltip" "${conn%-vpn}"
elif [ "$gstate" = "activating" ] || [ -f "$connecting_flag" ]; then
  # Drop a stale connecting flag (older than 1 min with nothing activating).
  if [ "$gstate" != "activating" ] && [ -f "$connecting_flag" ] \
     && [ -n "$(find "$connecting_flag" -mmin +1 2>/dev/null)" ]; then
    rm -f "$connecting_flag"
    json "$icon_off  VPN" "disconnected" "VPN disconnected\n\nLeft-click: connect\nRight-click: settings"
  else
    json "$icon_wait  VPN" "connecting" "Connecting to VPN…\n\nLeft-click: cancel"
  fi
else
  json "$icon_off  VPN" "disconnected" "VPN disconnected\n\nLeft-click: connect\nRight-click: settings"
fi
