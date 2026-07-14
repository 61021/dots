#!/usr/bin/env bash
# Toggle hyprsunset blue-light filter (1000K = no blue).

TEMP=3000

if pgrep -x hyprsunset >/dev/null 2>&1; then
  pkill -x hyprsunset
else
  setsid -f hyprsunset --temperature "$TEMP" >/dev/null 2>&1
fi
