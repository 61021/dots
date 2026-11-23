#!/usr/bin/env bash
# Download mode: leave the laptop downloading with as little else running as
# possible. Screen off and kept off, sleep and lid-suspend blocked, keyboard
# light, Bluetooth and toasts off, TLP's battery profile (quiet platform
# profile, no turbo, Wi-Fi power save) even on AC. Everything is restored on exit.
# A watcher suspends the laptop once the queue is done and imported, or after
# STALL_LIMIT with nothing coming in (dead torrents would otherwise keep it up all night).
#
# usage: download-mode.sh on|off|toggle|get|detail
# Exit with the sidebar tile or ALT+SHIFT+D (binds still fire under dpms off).
# Screen-off and hypridle mechanics are the same as tv-mode.sh: read its header.
set -uo pipefail

DIR=${XDG_RUNTIME_DIR:-/tmp}/download-mode
KBD=asus::kbd_backlight
QBIT=http://localhost:8080/api/v2
INTERVAL=${DOWNLOAD_MODE_INTERVAL:-60}
STALL_LIMIT=${DOWNLOAD_MODE_STALL_LIMIT:-7200}
mkdir -p "$DIR"

is_on() { [ -f "$DIR/on" ]; }

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

# done | flowing | stalled | unknown
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
    local done_checks=0 last_flow state reason
    last_flow=$(date +%s)
    while sleep "$INTERVAL" && is_on; do
        state=$(queue_state)
        case $state in
            flowing) last_flow=$(date +%s); done_checks=0 ;;
            done) done_checks=$((done_checks + 1)) ;;
            *) done_checks=0 ;;
        esac
        if [ "$done_checks" -ge 3 ]; then
            reason="Downloads finished"
        elif [ "$state" = stalled ] && [ $(( $(date +%s) - last_flow )) -ge "$STALL_LIMIT" ]; then
            reason="Nothing came in for 2 hours, so it gave up"
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

notify() { notify-send -a download-mode -i "$HOME/.config/dunst/icons/download-simple.svg" "$@"; }

on() {
    is_on && return
    [ -f "${XDG_RUNTIME_DIR:-/tmp}/tv-mode/state" ] && ~/.config/eww/scripts/tv-mode.sh off

    systemd-inhibit --what=idle:sleep:handle-lid-switch --who=download-mode \
        --why="Downloading with the screen off" --mode=block sleep infinity >/dev/null 2>&1 &
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

    if ! systemctl is-active -q qbittorrent-nox; then
        notify -u critical "Download mode on, but nothing is downloading" \
            "qBittorrent is stopped: data saver or the network guard. Screen off anyway; ALT+SHIFT+D wakes it."
    else
        p=$(progress)
        bat=$(cat /sys/class/power_supply/BAT*/capacity)
        if grep -q 0 /sys/class/power_supply/AC*/online; then
            notify -u critical "Download mode on, but on battery ($bat%)" "${p:+$p. }Plug in or it dies mid-download. ALT+SHIFT+D wakes it."
        else
            notify "Download mode on" "${p:+$p. }Suspends when they finish; ALT+SHIFT+D wakes it."
        fi
    fi
    # Long enough to read the toast, then pause toasts so the screen stays dark.
    sleep 3
    [ "$(dunstctl is-paused)" = true ] && touch "$DIR/dnd-was-on" || dunstctl set-paused true
    hyprctl dispatch 'hl.dsp.dpms({ action = "off" })' >/dev/null 2>&1
}

# off quiet: the watcher's exit before suspend, screen left dark and no toast.
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
    rm -f "$DIR"/{inhibit.pid,watch.pid,tlp,bt,kbd,dnd-was-on}
    [ "${1:-}" = quiet ] && return
    left=$(progress)
    notify "Download mode off" "${left:-All downloads finished.}"
}

case "${1:-get}" in
    on) on ;;
    off) off ;;
    watch) watch ;;
    toggle) if is_on; then off; else on; fi ;;
    get) is_on && echo connected || echo disconnected ;;
    detail) is_on && progress | cut -d, -f1 ;;
    *) echo "usage: $0 on|off|toggle|get|detail" >&2; exit 2 ;;
esac
