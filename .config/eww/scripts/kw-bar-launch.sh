#!/usr/bin/env bash
# Open the bar on the laptop screen.
set -e

for _ in $(seq 1 20); do
  eww ping >/dev/null 2>&1 && break
  sleep 0.1
done

eww close bar >/dev/null 2>&1 || true
eww open --screen 0 bar
