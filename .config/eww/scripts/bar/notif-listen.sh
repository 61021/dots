#!/usr/bin/env bash
# Streams notification state for the bar's `deflisten`.
# Emits on any org.freedesktop.Notifications / dunst control-command traffic.
set -u

emit() { ~/.config/eww/scripts/notifications.sh; }

emit
dbus-monitor --profile \
  "interface='org.freedesktop.Notifications'" \
  "interface='org.dunstproject.cmd0'" 2>/dev/null |
while IFS= read -r _; do
  # Coalesce bursts (a notification is several dbus messages).
  while IFS= read -r -t 0.1 _; do :; done
  emit
done
