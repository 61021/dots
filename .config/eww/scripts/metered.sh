#!/usr/bin/env bash
# Metered state of the active physical connection, as {"class","tooltip"} JSON.
# `toggle` on saves connection.metered yes; off is a runtime-only override.
# Both fire the 80-kw-metered-downloads dispatcher (stops/starts the download stack).
set -u

active() {
  nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>/dev/null \
    | awk -F: '$3=="connected" && $2 ~ /^(ethernet|wifi|gsm|bt)$/ {print; exit}'
}

line=$(active)
dev=${line%%:*}
conn=${line#*:*:*:}

json() {
  printf '{"class":"%s","tooltip":"%s"}\n' "$1" "$2"
}

status() {
  if [ -z "$line" ]; then
    json disconnected "Data saver: no connection"
    return
  fi
  m=$(nmcli -g GENERAL.METERED device show "$dev" 2>/dev/null)
  case "$m" in
    yes*) json connected "Data saver: on ($conn)\nDownloads paused\n\nClick: turn off" ;;
    *)    json disconnected "Data saver: off ($conn)\n\nClick: turn on and pause downloads" ;;
  esac
}

case "${1:-status}" in
  toggle)
    [ -z "$line" ] && exit 0
    case "$(nmcli -g GENERAL.METERED device show "$dev" 2>/dev/null)" in
      yes*) want=no ;;
      *)    want=yes ;;
    esac
    # Off is for this session only: a saved "no" overrides the hotspot's metered hint for good.
    if [ "$want" = yes ]; then
      nmcli connection modify "$conn" connection.metered yes \
        && nmcli device reapply "$dev" >/dev/null 2>&1
    else
      nmcli device modify "$dev" connection.metered no >/dev/null 2>&1
    fi
    eww update "metered=$(status)" 2>/dev/null
    ;;
  *) status ;;
esac
