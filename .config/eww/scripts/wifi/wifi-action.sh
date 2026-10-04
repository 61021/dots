#!/usr/bin/env bash
# Actions for the kw-wifi panel. Panel data is event-driven (nm-listen.py
# reacts to the NetworkManager signals every action here triggers), so nothing
# refreshes by hand. Called from yuck onclick handlers, always backgrounded
# there: eww kills handler commands after its 200ms default timeout.
# Saved networks are addressed by profile UUID: profile names are not SSIDs.
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
uuids() { nmcli -t -f UUID connection show 2>/dev/null | sort; }
# A failed connect must never leave a profile behind: secretless profiles make
# NetworkManager summon agent password popups later.
drop_new_profiles() { # <uuid list from before the attempt>
  comm -13 <(printf '%s\n' "$1") <(uuids) | while read -r u; do
    [ -n "$u" ] && nmcli connection delete uuid "$u" >/dev/null 2>&1
  done
}

case "${1:-}" in
  row-click)
    # row-click <ssid> <saved> <sec> <eap> <uuid>
    ssid="$2" saved="$3" sec="$4" eap="$5" uuid="${6:-}"
    if [ "$saved" = "true" ] && [ -n "$uuid" ]; then
      exec "$0" connect-saved "$ssid" "$uuid"
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
    # toggle-radio <on|off>: the switch flips at once, the daemon confirms.
    want="${2:-}"
    case "$want" in on|off) ;; *) exit 1 ;; esac
    eww update kw-wifi-radio="$want" 2>/dev/null
    nmcli radio wifi "$want"
    sleep 0.6
    eww update kw-wifi-radio='' 2>/dev/null
    ;;
  rescan)
    signal_net USR1
    ;;
  connect-saved)
    # connect-saved <ssid> <uuid>
    eww update kw-wifi-busy="$2" kw-wifi-error='' 2>/dev/null
    if nmcli -w 15 connection up uuid "$3" >/dev/null 2>&1; then
      "$KW" -v .75 outcome-success
      clear_state
    else
      # no `device wifi connect` fallback: on a secured network it creates a
      # secretless autoconnect profile and summons the nm-applet password popup
      fail "Could not connect to $2. Right-click it to forget, then retry."
    fi
    ;;
  connect-open)
    eww update kw-wifi-busy="$2" kw-wifi-error='' 2>/dev/null
    before="$(uuids)"
    if nmcli -w 15 device wifi connect "$2" >/dev/null 2>&1; then
      "$KW" -v .75 outcome-success
      clear_state
    else
      drop_new_profiles "$before"
      fail "Could not connect to $2."
    fi
    ;;
  connect-pass)
    # connect-pass <ssid>, password on stdin: the yuck handler feeds it through
    # a quoted heredoc, so quotes and $ in passwords reach nmcli untouched.
    IFS= read -r pass || true
    [ -n "$pass" ] || { eww update kw-wifi-error="Enter the password." 2>/dev/null; exit 0; }
    eww update kw-wifi-busy="$2" kw-wifi-error='' 2>/dev/null
    before="$(uuids)"
    if nmcli -w 20 device wifi connect "$2" password "$pass" >/dev/null 2>&1; then
      "$KW" -v .75 outcome-success
      clear_state
    else
      drop_new_profiles "$before"
      fail "Wrong password. Try again."
    fi
    ;;
  disconnect)
    # disconnect <active connection uuid>
    nmcli connection down uuid "${2:-}" >/dev/null 2>&1 \
      || nmcli device disconnect "$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')" >/dev/null 2>&1
    ;;
  forget)
    # forget <ssid> <saved> <uuid>...: the first right-click arms the row for
    # 3s, a second one deletes every saved profile for that SSID.
    shift
    ssid=$1 saved=$2
    shift 2
    [ "$saved" = true ] || exit 0
    if [ "$(eww get kw-wifi-forget 2>/dev/null)" = "$ssid" ]; then
      eww update kw-wifi-forget='' 2>/dev/null
      for u in "$@"; do nmcli connection delete uuid "$u" >/dev/null 2>&1; done
    else
      eww update "kw-wifi-forget=$ssid" 2>/dev/null
      (
        sleep 3
        [ "$(eww get kw-wifi-forget 2>/dev/null)" = "$ssid" ] && eww update kw-wifi-forget='' 2>/dev/null
      ) &
    fi
    ;;
  settings)
    ~/.config/eww/scripts/kw-wifi.sh close
    setsid -f nm-connection-editor >/dev/null 2>&1
    ;;
esac
