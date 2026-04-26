#!/usr/bin/env bash
# Toggle Cloudflare WARP connection.

if ! command -v warp-cli >/dev/null 2>&1; then
  notify-send -u critical "WARP" "warp-cli not installed"
  exit 1
fi

state=$(warp-cli status 2>/dev/null | grep -i 'status update' | sed -E 's/.*Status update:\s*//I' | tr -d '\r')

case "$state" in
  Connected)
    warp-cli disconnect >/dev/null 2>&1
    ;;
  *)
    warp-cli connect >/dev/null 2>&1
    ;;
esac

# Refresh waybar immediately.
pkill -RTMIN+9 waybar 2>/dev/null
