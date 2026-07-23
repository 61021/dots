#!/usr/bin/env bash
# TV mode — keep the laptop awake to feed the TV's Jellyfin without
# letting the battery finish charging.
#
# usage:
#   tv-mode.sh on       enter TV mode
#   tv-mode.sh off      leave TV mode
#   tv-mode.sh toggle   toggle
#   tv-mode.sh get      print "connected" / "disconnected" (for eww)
#   tv-mode.sh status   human readable status

set -euo pipefail

# First battery, whatever its index (BAT0/BAT1/...)
set -- /sys/class/power_supply/BAT*
BAT_DIR="$1"
THRESH_FILE="$BAT_DIR/charge_control_end_threshold"
CAP_FILE="$BAT_DIR/capacity"

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/tv-mode"
STATE_FILE="$STATE_DIR/state"          # "on" or absent
SAVED_THRESH="$STATE_DIR/saved_threshold"
INHIBIT_PID="$STATE_DIR/inhibit.pid"

# Defaults
DEFAULT_RESTORE_THRESHOLD=80
# Floor for the "stop charging" threshold so we don't run the battery dry
# while you're streaming.
TV_MIN_THRESHOLD=50

mkdir -p "$STATE_DIR"

write_threshold() {
    local val="$1"
    # The sysfs file is root-owned; the sudoers drop-in at
    # /etc/sudoers.d/tv-mode-charge allows this exact command without password.
    echo "$val" | sudo -n tee "$THRESH_FILE" >/dev/null
}

current_threshold() {
    cat "$THRESH_FILE" 2>/dev/null || echo "$DEFAULT_RESTORE_THRESHOLD"
}

current_capacity() {
    cat "$CAP_FILE" 2>/dev/null || echo 100
}

pause_hypridle() {
    # Stops the process; on resume it continues with its idle-notify
    # subscriptions intact, and Hyprland resets the idle timer on any input.
    pkill -STOP -x hypridle 2>/dev/null || true
}

resume_hypridle() {
    pkill -CONT -x hypridle 2>/dev/null || true
}

start_inhibitor() {
    # Block systemd's idle/sleep/handle-lid actions for good measure.
    # The inhibitor lives as long as this background sleep does.
    systemd-inhibit \
        --what=idle:sleep:handle-lid-switch \
        --who="tv-mode" \
        --why="Streaming to TV via Jellyfin" \
        --mode=block \
        sleep infinity >/dev/null 2>&1 &
    echo $! > "$INHIBIT_PID"
    disown 2>/dev/null || true
}

stop_inhibitor() {
    if [[ -f "$INHIBIT_PID" ]]; then
        local pid
        pid=$(cat "$INHIBIT_PID" 2>/dev/null || true)
        [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null || true
        rm -f "$INHIBIT_PID"
    fi
    # Belt: kill any stray inhibitors we own.
    pkill -f 'systemd-inhibit .* --who=tv-mode' 2>/dev/null || true
}

notify() {
    command -v notify-send >/dev/null 2>&1 && \
        notify-send -a "TV mode" -i video-display "$1" "${2:-}" || true
}

tv_on() {
    # Save the current threshold so we can restore it later.
    current_threshold > "$SAVED_THRESH"

    # Pick a threshold just below the current charge so charging halts now.
    local cap target
    cap=$(current_capacity)
    target=$(( cap - 2 ))
    (( target < TV_MIN_THRESHOLD )) && target=$TV_MIN_THRESHOLD
    (( target > 95 )) && target=95

    if ! write_threshold "$target"; then
        notify "TV mode failed" "Could not set charge threshold. Install sudoers rule."
        exit 1
    fi

    pause_hypridle
    start_inhibitor

    # Turn the laptop screen off so it draws less than the charger supplies
    # to the TV-bound HDMI output. Any keypress / touchpad wakes it.
    hyprctl dispatch dpms off >/dev/null 2>&1 || true

    echo on > "$STATE_FILE"
    notify "TV mode ON" "Charge stops at ${target}%. Screen off, idle / suspend disabled."
}

tv_off() {
    local restore
    restore=$(cat "$SAVED_THRESH" 2>/dev/null || echo "$DEFAULT_RESTORE_THRESHOLD")
    write_threshold "$restore" || true

    resume_hypridle
    stop_inhibitor
    hyprctl dispatch dpms on >/dev/null 2>&1 || true

    rm -f "$STATE_FILE"
    notify "TV mode OFF" "Charge threshold restored to ${restore}%."
}

is_on() {
    [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "on" ]]
}

case "${1:-status}" in
    on)      tv_on ;;
    off)     tv_off ;;
    toggle)  if is_on; then tv_off; else tv_on; fi ;;
    get)     if is_on; then echo connected; else echo disconnected; fi ;;
    status)
        if is_on; then
            echo "TV mode: ON (threshold=$(current_threshold)%, capacity=$(current_capacity)%)"
        else
            echo "TV mode: off (threshold=$(current_threshold)%)"
        fi ;;
    *) echo "usage: $0 {on|off|toggle|get|status}" >&2; exit 2 ;;
esac
