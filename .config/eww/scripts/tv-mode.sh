#!/usr/bin/env bash
# TV mode: turn the laptop into a headless server while the TV streams from
# its Jellyfin: screen off and it STAYS off (stray keys/touchpad don't relight
# it), idle/suspend/lid-suspend blocked so Jellyfin and long-running jobs
# (Claude Code, downloads) keep working, charging halted just below the
# current level so the battery doesn't sit pinned at 100%.
#
# Exit via the sidebar button or SUPER+SHIFT+T (hyprland.conf); Hyprland
# binds still fire while dpms is off.
#
# usage:
#   tv-mode.sh on|off|toggle|get|status
#
# Screen-off mechanics: misc:key_press_enables_dpms and
# misc:mouse_move_enables_dpms are 0 here, so Hyprland itself never wakes
# dpms on input. The only agent that relit the screen (on-resume = dpms on)
# and suspended the box mid-stream (30-min systemctl suspend) was hypridle,
# so TV mode kills it and restarts it on exit. Do NOT go back to SIGSTOP:
# the compositor keeps delivering ext-idle-notify "idled" events to a
# stopped client, and on SIGCONT hypridle replays the whole backlog:
# dim + lock + dpms-off + suspend fire back-to-back.

set -euo pipefail

# Grab the command BEFORE the battery glob: `set --` below replaces the
# positional params, which is exactly the bug that silently no-op'd every
# invocation (case saw a /sys path, hit the usage branch, exit 2).
CMD="${1:-status}"

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

kill_hypridle() {
    pkill -x hypridle 2>/dev/null || true
}

start_hypridle() {
    # Fresh instance, detached so it survives this transient shell. The
    # pgrep guard avoids doubling up with the exec-once one after a session
    # restart mid-TV-mode.
    pgrep -x hypridle >/dev/null 2>&1 || setsid -f hypridle >/dev/null 2>&1 || true
}

start_inhibitor() {
    # Block idle/sleep/lid actions from anything else (logind lid handling,
    # manual systemctl suspend without -i, ...). Lives as long as the sleep.
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
    # Order matters: block suspend before anything could fire it, then take
    # hypridle (the only dpms-on / suspend agent) out of the picture.
    start_inhibitor
    kill_hypridle

    # Battery: stop charging just below the current level. Best effort: a
    # broken sudo rule must not abort TV mode and leave the box suspendable
    # like the old `exit 1` here did.
    local cap target charge_note
    current_threshold > "$SAVED_THRESH"
    cap=$(current_capacity)
    target=$(( cap - 2 ))
    (( target < TV_MIN_THRESHOLD )) && target=$TV_MIN_THRESHOLD
    (( target > 95 )) && target=95
    if write_threshold "$target"; then
        charge_note="Charge stops at ${target}%."
    else
        charge_note="Charge threshold NOT set (check sudoers rule); still charging."
    fi

    echo on > "$STATE_FILE"
    notify "TV mode ON" "${charge_note} Screen off, suspend blocked. SUPER+SHIFT+T to exit."
    hyprctl dispatch 'hl.dsp.dpms({ action = "off" })' >/dev/null 2>&1 || true
}

tv_off() {
    local restore
    restore=$(cat "$SAVED_THRESH" 2>/dev/null || echo "$DEFAULT_RESTORE_THRESHOLD")
    write_threshold "$restore" || true

    stop_inhibitor
    start_hypridle
    hyprctl dispatch 'hl.dsp.dpms({ action = "on" })' >/dev/null 2>&1 || true

    rm -f "$STATE_FILE" "$SAVED_THRESH"
    notify "TV mode OFF" "Charge threshold restored to ${restore}%."
}

is_on() {
    [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "on" ]]
}

case "$CMD" in
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
