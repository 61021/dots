#!/usr/bin/env bash
# Toggle the kw-sidebar.
set -euo pipefail

if [ "${1:-}" = "close" ] || eww active-windows 2>/dev/null | grep -q '^kw-sidebar'; then
  eww close kw-sidebar >/dev/null 2>&1 || true
else
  eww open --screen 0 kw-sidebar
fi
