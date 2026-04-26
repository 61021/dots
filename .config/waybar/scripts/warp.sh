#!/usr/bin/env bash
# Waybar status module for Cloudflare WARP.

icon_on=""    # nf-md-cloud_check
icon_off=""   # nf-md-cloud_off_outline
icon_wait="" # nf-md-cloud_sync

json() {
  printf '{"text":"%s","class":"%s","tooltip":"%s","alt":"%s"}\n' \
    "$1" "$2" "$3" "$2"
}

if ! command -v warp-cli >/dev/null 2>&1; then
  json "$icon_off  WARP" "missing" "warp-cli not installed"
  exit 0
fi

status_line=$(warp-cli status 2>/dev/null | grep -i 'status update' | head -1)
state=$(printf '%s' "$status_line" | sed -E 's/.*Status update:\s*//I' | tr -d '\r')

case "$state" in
  Connected)
    tooltip="WARP connected\r${status_line}\r\rLeft-click: disconnect\rRight-click: status"
    json "$icon_on  WARP" "connected" "$tooltip"
    ;;
  Connecting|"Connecting…"|"Connecting...")
    json "$icon_wait  WARP" "connecting" "Connecting to WARP…"
    ;;
  Disconnecting)
    json "$icon_wait  WARP" "connecting" "Disconnecting from WARP…"
    ;;
  Disconnected|"")
    json "$icon_off  WARP" "disconnected" "WARP disconnected\r\rLeft-click: connect"
    ;;
  *)
    json "$icon_off  WARP" "disconnected" "WARP: ${state:-unknown}\r\rLeft-click: connect"
    ;;
esac
