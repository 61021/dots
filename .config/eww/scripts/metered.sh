#!/usr/bin/env bash
# Metered state of the active physical connection, as {"class","tooltip"} JSON.
# `toggle` flips connection.metered yes/no and reapplies, which fires the
# 80-kw-metered-downloads dispatcher (stops/starts the download stack).
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
    json disconnected "Metered: no connection"
    return
  fi
  m=$(nmcli -g GENERAL.METERED device show "$dev" 2>/dev/null)
  case "$m" in
    yes*) json connected "Metered: on ($conn)\nDownloads paused\n\nClick: mark unmetered" ;;
    *)    json disconnected "Metered: off ($conn)\n\nClick: mark metered" ;;
  esac
}

case "${1:-status}" in
  toggle)
    [ -z "$line" ] && exit 0
    case "$(nmcli -g GENERAL.METERED device show "$dev" 2>/dev/null)" in
      yes*) want=no ;;
      *)    want=yes ;;
    esac
    nmcli connection modify "$conn" connection.metered "$want" \
      && nmcli device reapply "$dev" >/dev/null 2>&1
    eww update "metered=$(status)" 2>/dev/null
    ;;
  *) status ;;
esac
