#!/usr/bin/env bash
# Click-to-toggle kw-calendar.
set -euo pipefail
flag=/tmp/kw-calendar.open

if [ -f "$flag" ]; then
  rm -f "$flag"
  eww close kw-calendar 2>/dev/null || true
else
  eww open --screen 0 kw-calendar
  touch "$flag"
fi
