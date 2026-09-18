#!/usr/bin/env bash
# Actions for the kw-wifi panel. Panel data is event-driven (nm-listen.py
# reacts to the NetworkManager signals every action here triggers), so nothing
# refreshes by hand. Called from yuck onclick handlers, always backgrounded
# there: eww kills handler commands after its 200ms default timeout.
set -u
KW="$HOME/.local/bin/kw-sound"
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/kw-net.pid"

signal_net() { kill "-$1" "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null || true; }
clear_state() {
  eww update kw-wifi-prompt='' kw-wifi-error='' kw-wifi-busy='' 2>/dev/null || true
  eww close kw-wifi-pw 2>/dev/null || true
}
fail() { # <message>
  "$KW" -v .75 outcome-failure
  eww update kw-wifi-busy='' kw-wifi-error="$1" 2>/dev/null || true
}
focused_screen() {
  hyprctl -j monitors 2>/dev/null | jq -r '[to_entries[] | select(.value.focused)][0].key // 0'
}

case "${1:-}" in
  row-click)
    # row-click <ssid> <saved> <sec> <eap>
    ssid="$2" saved="$3" sec="$4" eap="$5"
    if [ "$saved" = "true" ]; then
      exec "$0" connect-saved "$ssid"
    elif [ "$eap" = "true" ]; then
      exec "$0" settings # 802.1X needs identity + certs, not just a password
    elif [ "$sec" = "true" ]; then
      eww update kw-wifi-prompt="$ssid" kw-wifi-error='' 2>/dev/null
      eww open --screen "$(focused_screen)" kw-wifi-pw 2>/dev/null || true
    else
      exec "$0" connect-open "$ssid"
    fi
    ;;
  toggle-radio)
    if [ "$(nmcli radio wifi)" = "enabled" ]; then nmcli radio wifi off; else nmcli radio wifi on; fi
    ;;
  rescan)
    signal_net USR1
    ;;
  connect-saved)
    eww update kw-wifi-busy="$2" kw-wifi-error='' 2>/dev/null
    if nmcli -w 15 connection up id "$2" >/dev/null 2>&1; then
      "$KW" -v .75 outcome-success
      clear_state
    else
      # no `device wifi connect` fallback: on a secured network it creates a
      # secretless autoconnect profile and summons the nm-applet password popup
      fail "Could not connect to $2. Forget it and retry."
    fi
    ;;
  connect-open)
    eww update kw-wifi-busy="$2" kw-wifi-error='' 2>/dev/null
    if nmcli -w 15 device wifi connect "$2" >/dev/null 2>&1; then
      "$KW" -v .75 outcome-success
      clear_state
    else
      nmcli connection delete id "$2" >/dev/null 2>&1 # never leave a broken profile behind
      fail "Could not connect to $2."
    fi
    ;;
  connect-pass)
    eww update kw-wifi-busy="$2" kw-wifi-error='' 2>/dev/null
    if nmcli -w 20 device wifi connect "$2" password "$3" >/dev/null 2>&1; then
      "$KW" -v .75 outcome-success
      clear_state
    else
      nmcli connection delete id "$2" >/dev/null 2>&1
      fail "Wrong password for $2. Try again."
    fi
    ;;
  disconnect)
    nmcli connection down id "$2" >/dev/null 2>&1 \
      || nmcli device disconnect "$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')" >/dev/null 2>&1
    ;;
  forget)
    nmcli connection delete id "$2" >/dev/null 2>&1
    ;;
  settings)
    ~/.config/eww/scripts/kw-wifi.sh close
    setsid -f nm-connection-editor >/dev/null 2>&1
    ;;
esac
