#!/usr/bin/env bash
# Brightness helpers
set -eu
case "${1:-get}" in
  get)
    if command -v brightnessctl >/dev/null 2>&1; then
      brightnessctl -m 2>/dev/null | awk -F, '{gsub("%","",$4); print $4+0}'
    else
      echo 0
    fi
    ;;
  set)
    pct="${2:-50}"
    brightnessctl set "${pct}%" >/dev/null
    ;;
esac
