#!/usr/bin/env bash
# Download mode: leave the laptop downloading with as little else running as
# possible. Screen off and kept off, sleep and lid-suspend blocked, keyboard
# light, Bluetooth and toasts off, TLP's battery profile (quiet platform
# profile, no turbo, Wi-Fi power save) even on AC. Everything is restored on exit.
#
# usage: download-mode.sh on|off|toggle|get|detail
# Exit with the sidebar tile or ALT+SHIFT+D (binds still fire under dpms off).
# Screen-off and hypridle mechanics are the same as tv-mode.sh: read its header.
set -uo pipefail

DIR=${XDG_RUNTIME_DIR:-/tmp}/download-mode
KBD=asus::kbd_backlight
QBIT=http://localhost:8080/api/v2
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

    if ! systemctl is-active -q qbittorrent-nox; then
        notify -u critical "Download mode on, but nothing is downloading" \
            "qBittorrent is stopped: data saver or the network guard. Screen off anyway; ALT+SHIFT+D wakes it."
    else
        p=$(progress)
        bat=$(cat /sys/class/power_supply/BAT*/capacity)
        if grep -q 0 /sys/class/power_supply/AC*/online; then
            notify -u critical "Download mode on, but on battery ($bat%)" "${p:+$p. }Plug in or it dies mid-download. ALT+SHIFT+D wakes it."
        else
            notify "Download mode on" "${p:+$p. }Screen off in 3 s; ALT+SHIFT+D wakes it."
        fi
    fi
    # Long enough to read the toast, then pause toasts so the screen stays dark.
    sleep 3
    [ "$(dunstctl is-paused)" = true ] && touch "$DIR/dnd-was-on" || dunstctl set-paused true
    hyprctl dispatch 'hl.dsp.dpms({ action = "off" })' >/dev/null 2>&1
}

off() {
    is_on || return
    rm -f "$DIR/on"
    hyprctl dispatch 'hl.dsp.dpms({ action = "on" })' >/dev/null 2>&1
    [ -f "$DIR/inhibit.pid" ] && kill "$(cat "$DIR/inhibit.pid")" 2>/dev/null
    [ -f "$DIR/tlp" ] && sudo -n /usr/sbin/tlp start >/dev/null 2>&1
    [ -f "$DIR/bt" ] && xargs -r -n1 rfkill unblock < "$DIR/bt"
    [ -s "$DIR/kbd" ] && brightnessctl -qd "$KBD" set "$(cat "$DIR/kbd")"
    [ -f "$DIR/dnd-was-on" ] || dunstctl set-paused false
    pgrep -x hypridle >/dev/null || setsid -f hypridle >/dev/null 2>&1
    rm -f "$DIR"/{inhibit.pid,tlp,bt,kbd,dnd-was-on}
    left=$(progress)
    notify "Download mode off" "${left:-All downloads finished.}"
}

case "${1:-get}" in
    on) on ;;
    off) off ;;
    toggle) if is_on; then off; else on; fi ;;
    get) is_on && echo connected || echo disconnected ;;
    detail) is_on && progress | cut -d, -f1 ;;
    *) echo "usage: $0 on|off|toggle|get|detail" >&2; exit 2 ;;
esac
