#!/usr/bin/env bash
# Away mode: leave the laptop working (Claude sessions, downloads) with the lid
# shut, at home or in the car. Screen off and locked, sleep and lid-suspend
# blocked, keyboard light, Bluetooth and toasts off, TLP's battery profile
# (quiet platform profile, no turbo, Wi-Fi power save) even on AC, which also
# keeps a closed lid cooler. Everything but the lock is restored on exit.
# A watcher suspends the laptop once nothing is left to run: downloads done and
# imported (or nothing came in for STALL_LIMIT) and no Claude session working
# for IDLE minutes; or at BATTERY_MIN% on battery, before UPower's 2% action.
#
# usage: away-mode.sh on|off|toggle|get|detail
# Exit with the sidebar tile or ALT+SHIFT+D (binds still fire under dpms off).
# Screen-off and hypridle mechanics are the same as tv-mode.sh: read its header.
set -uo pipefail

DIR=${XDG_RUNTIME_DIR:-/tmp}/away-mode
KBD=asus::kbd_backlight
QBIT=http://localhost:8080/api/v2
INTERVAL=${AWAY_MODE_INTERVAL:-60}
STALL_LIMIT=${AWAY_MODE_STALL_LIMIT:-7200}
IDLE=${AWAY_MODE_IDLE:-15}
CPU_MIN=${AWAY_MODE_CPU_MIN:-5}
BATTERY_MIN=${AWAY_MODE_BATTERY_MIN:-10}
POWER=${AWAY_MODE_POWER:-/sys/class/power_supply}
PROJECTS=${AWAY_MODE_PROJECTS:-$HOME/.claude/projects}
LOCK=${AWAY_MODE_LOCK:-$HOME/.local/bin/kw-lock}
mkdir -p "$DIR"

is_on() { [ -f "$DIR/on" ]; }
on_battery() { grep -q 0 "$POWER"/AC*/online; }
battery() { cat "$POWER"/BAT*/capacity; }

# Sessions whose transcript (or a subagent's or workflow's) was written in the last IDLE minutes.
claude_sessions() {
    find "$PROJECTS" -name '*.jsonl' -mmin "-$IDLE" -printf '%P\n' 2>/dev/null \
        | awk -F/ '{ sub(/\.jsonl$/, "", $2); print $1 "/" $2 }' | sort -u | wc -l
}

# CPU seconds of everything running under a claude process (tool commands,
# background builds), the claude processes themselves left out.
claude_cpu() {
    ps -eo pid=,ppid=,comm=,times= | awk '
        { pp[$1] = $2; c[$1] = $3; t[$1] = $4 }
        END {
            for (i in pp) if (c[i] != "claude")
                for (a = pp[i]; a > 1; a = pp[a]) if (c[a] == "claude") { s += t[i]; break }
            print s + 0
        }'
}

# Working = a transcript moved recently, or a session's command (a background
# build the transcript stays quiet through) used CPU_MIN seconds since the last check.
claude_busy() {
    local now prev
    now=$(claude_cpu)
    prev=$(cat "$DIR/cpu" 2>/dev/null || echo "$now")
    echo "$now" > "$DIR/cpu"
    [ "$(claude_sessions)" -gt 0 ] || [ $((now - prev)) -ge "$CPU_MIN" ]
}

# "2 downloading, 8 queued, ~31h for all": the ETA is everything left over the current speed.
progress() {
    curl -s -m 3 "$QBIT/torrents/info?filter=downloading" \
        | jq -r 'if length == 0 then "" else
                   (map(select(.state == "queuedDL")) | length) as $q
                   | (map(.dlspeed) | add) as $speed
                   | "\(length - $q) downloading"
                     + (if $q > 0 then ", \($q) queued" else "" end)
                     + (if $speed > 0 then ", ~\(map(.amount_left) | add / $speed / 3600 | ceil)h for all" else "" end)
                   end' 2>/dev/null
}

# "2 Claude sessions working, 1 downloading, 3 queued": what keeps it awake right now.
summary() {
    local n p
    n=$(claude_sessions) p=$(progress)
    [ "$n" -eq 1 ] && n="1 Claude session working" || { [ "$n" -gt 1 ] && n="$n Claude sessions working" || n=; }
    [ -n "$n" ] && [ -n "$p" ] && echo "$n, $p" || echo "$n$p"
}

# Finished torrents Radarr/Sonarr haven't imported yet (a copy can take minutes).
importing() {
    local app port key
    for app in radarr:7878 sonarr:8989; do
        port=${app#*:} app=${app%:*}
        key=$(grep -oP '(?<=<ApiKey>)[^<]+' "/var/lib/$app/config.xml" 2>/dev/null) || continue
        curl -s -m 5 -H "X-Api-Key: $key" "localhost:$port/api/v3/queue?pageSize=200" \
            | jq -e '[.records[] | select(.trackedDownloadState == "importPending" or .trackedDownloadState == "importing"
                     or (.status == "completed" and .trackedDownloadState == "downloading"))] | length > 0' >/dev/null && return 0
    done
    return 1
}

# done | flowing | stalled | unknown. qBittorrent stopped (data saver on the hotspot) counts as done.
queue_state() {
    systemctl is-active -q qbittorrent-nox || { echo done; return; }
    local t
    t=$(curl -sf -m 5 "$QBIT/torrents/info?filter=downloading") || { echo unknown; return; }
    importing && { echo flowing; return; }
    jq -r 'if length == 0 then "done" elif (map(.dlspeed) | add) > 0 then "flowing" else "stalled" end' <<< "$t"
}

# Runs detached for as long as the mode is on.
watch() {
    echo $$ > "$DIR/watch.pid"
    local done_checks=0 last_flow state reason busy
    last_flow=$(date +%s)
    claude_cpu > "$DIR/cpu"
    while sleep "$INTERVAL" && is_on; do
        state=$(queue_state)
        case $state in
            flowing) last_flow=$(date +%s); done_checks=0 ;;
            done) done_checks=$((done_checks + 1)) ;;
            *) done_checks=0 ;;
        esac
        claude_busy && busy=1 || busy=
        if on_battery && [ "$(battery)" -le "$BATTERY_MIN" ]; then
            reason="Battery at $(battery)%"
        elif [ -n "$busy" ]; then
            continue
        elif [ "$done_checks" -ge 3 ]; then
            reason="Nothing left to run"
        elif [ "$state" = stalled ] && [ $(( $(date +%s) - last_flow )) -ge "$STALL_LIMIT" ]; then
            reason="Claude is idle and no download moved for 2 hours"
        else
            continue
        fi
        rm -f "$DIR/watch.pid"
        off quiet
        notify "$reason, suspended at $(date +%H:%M)" "$(progress)"
        systemctl suspend
        return
    done
}

notify() { notify-send -a away-mode -i "$HOME/.config/dunst/icons/door-open.svg" "$@"; }

on() {
    is_on && return
    [ -f "${XDG_RUNTIME_DIR:-/tmp}/tv-mode/state" ] && ~/.config/eww/scripts/tv-mode.sh off

    systemd-inhibit --what=idle:sleep:handle-lid-switch --who=away-mode \
        --why="Working with the lid shut" --mode=block sleep infinity >/dev/null 2>&1 &
    echo $! > "$DIR/inhibit.pid"
    disown
    pkill -x hypridle

    brightnessctl -d "$KBD" g > "$DIR/kbd" 2>/dev/null && brightnessctl -qd "$KBD" set 0
    # Per-device, so a half-blocked pair (asus-bluetooth + hci0) comes back as it was.
    rfkill -n -o ID,TYPE,SOFT | awk '$2 == "bluetooth" && $3 == "unblocked" { print $1 }' > "$DIR/bt"
    rfkill block bluetooth
    sudo -n /usr/sbin/tlp bat >/dev/null 2>&1 && touch "$DIR/tlp"
    touch "$DIR/on"
    setsid -f "$0" watch >/dev/null 2>&1

    local s bat
    s=$(summary)
    bat=$(on_battery && echo " On battery ($(battery)%), suspends at $BATTERY_MIN%." || true)
    if [ -z "$s" ]; then
        notify -u critical "Away mode on, but nothing is running" "It suspends in about 3 minutes. ALT+SHIFT+D wakes it."
    else
        notify "Away mode on" "$s. Close the lid; it suspends once they finish.$bat"
    fi
    # Long enough to read the toast, then lock, pause toasts and go dark.
    sleep 3
    setsid -f "$LOCK" >/dev/null 2>&1
    [ "$(dunstctl is-paused)" = true ] && touch "$DIR/dnd-was-on" || dunstctl set-paused true
    hyprctl dispatch 'hl.dsp.dpms({ action = "off" })' >/dev/null 2>&1
}

# off quiet: the watcher's exit before suspend, screen left dark and no toast.
# The lock stays: the way back in is the password.
off() {
    is_on || return
    rm -f "$DIR/on"
    [ -f "$DIR/watch.pid" ] && kill "$(cat "$DIR/watch.pid")" 2>/dev/null
    [ "${1:-}" = quiet ] || hyprctl dispatch 'hl.dsp.dpms({ action = "on" })' >/dev/null 2>&1
    [ -f "$DIR/inhibit.pid" ] && kill "$(cat "$DIR/inhibit.pid")" 2>/dev/null
    [ -f "$DIR/tlp" ] && sudo -n /usr/sbin/tlp start >/dev/null 2>&1
    [ -f "$DIR/bt" ] && xargs -r -n1 rfkill unblock < "$DIR/bt"
    [ -s "$DIR/kbd" ] && brightnessctl -qd "$KBD" set "$(cat "$DIR/kbd")"
    [ -f "$DIR/dnd-was-on" ] || dunstctl set-paused false
    pgrep -x hypridle >/dev/null || setsid -f hypridle >/dev/null 2>&1
    rm -f "$DIR"/{inhibit.pid,watch.pid,tlp,bt,kbd,dnd-was-on,cpu}
    [ "${1:-}" = quiet ] && return
    local left
    left=$(summary)
    notify "Away mode off" "${left:+Still running: $left}${left:-Nothing was left running.}"
}

case "${1:-get}" in
    on) on ;;
    off) off ;;
    watch) watch ;;
    toggle) if is_on; then off; else on; fi ;;
    get) is_on && echo connected || echo disconnected ;;
    detail) is_on && summary | cut -d, -f1 | sed 's/ Claude session.* working/ working/' ;;
    *) echo "usage: $0 on|off|toggle|get|detail" >&2; exit 2 ;;
esac
