#!/usr/bin/env bash
# Actions for the kw-wifi panel. Every action ends by refreshing the panel data.
# Called from yuck onclick handlers (always backgrounded with `&` there — eww
# kills handler commands after its 200ms default timeout otherwise).
set -u
DIR="$HOME/.config/eww/scripts/wifi"
KW="$HOME/.local/bin/kw-sound"

refresh() {
  data="$("$DIR/wifi-data.py" 2>/dev/null)" || data=""
  case "$data" in
    '{'*) eww update "kw-wifi=$data" 2>/dev/null || true ;;
  esac
}
clear_state() {
  eww update kw-wifi-prompt='' kw-wifi-error='' kw-wifi-busy='' 2>/dev/null || true
  eww close kw-wifi-pw 2>/dev/null || true
}
cursor_screen() {
  hyprctl -j cursorpos 2>/dev/null | jq -r --argjson mons "$(hyprctl -j monitors)" \
    '. as $c | [$mons | to_entries[] | select(.value.x <= $c.x and $c.x < (.value.x + .value.width) and .value.y <= $c.y and $c.y < (.value.y + .value.height))][0].key // 0'
}

case "${1:-}" in
  row-click)
    # row-click <ssid> <saved> <sec> <eap>  — decide what clicking a row does
    ssid="$2" saved="$3" sec="$4" eap="$5"
    if [ "$saved" = "true" ]; then
      exec "$0" connect-saved "$ssid"
    elif [ "$eap" = "true" ]; then
      exec "$0" settings # 802.1X needs identity+cert config, not just a password
    elif [ "$sec" = "true" ]; then
      eww update kw-wifi-prompt="$ssid" kw-wifi-error='' 2>/dev/null
      eww open --screen "$(cursor_screen)" kw-wifi-pw 2>/dev/null || true
      exit 0
    else
      exec "$0" connect-open "$ssid"
    fi
    ;;
  toggle-radio)
    if [ "$(nmcli radio wifi)" = "enabled" ]; then nmcli radio wifi off; else nmcli radio wifi on; fi
    ;;
  rescan)
    nmcli device wifi rescan 2>/dev/null
    sleep 2
    ;;
  connect-saved)
    eww update kw-wifi-busy="$2" 2>/dev/null
    if nmcli -w 15 connection up id "$2" >/dev/null 2>&1; then
      "$KW" -v .75 outcome-success
      clear_state
    else
      # no `device wifi connect` fallback here: on a secured network it creates
      # a secretless autoconnect profile and summons the nm-applet password popup
      "$KW" -v .75 outcome-failure
      eww update kw-wifi-busy='' kw-wifi-error='Connect failed — forget & retry' 2>/dev/null
    fi
    ;;
  connect-open)
    eww update kw-wifi-busy="$2" 2>/dev/null
    if nmcli -w 15 device wifi connect "$2" >/dev/null 2>&1; then
      "$KW" -v .75 outcome-success
      clear_state
    else
      # a failed attempt leaves a broken profile behind — drop it so retry is clean
      nmcli connection delete id "$2" >/dev/null 2>&1
      "$KW" -v .75 outcome-failure
      eww update kw-wifi-busy='' kw-wifi-error='Connect failed' 2>/dev/null
    fi
    ;;
  connect-pass)
    eww update kw-wifi-busy="$2" 2>/dev/null
    if nmcli -w 20 device wifi connect "$2" password "$3" >/dev/null 2>&1; then
      "$KW" -v .75 outcome-success
      clear_state
    else
      # a failed attempt leaves a broken profile behind — drop it so retry is clean
      nmcli connection delete id "$2" >/dev/null 2>&1
      "$KW" -v .75 outcome-failure
      eww update kw-wifi-busy='' kw-wifi-error='Wrong password — try again' 2>/dev/null
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
    eww close kw-wifi 2>/dev/null
    setsid -f nm-connection-editor >/dev/null 2>&1
    ;;
esac
refresh
