#!/usr/bin/env bash
# Toggle the laptop's internal display based on lid state.
# - On close: disable the panel only if an external monitor is connected;
#   otherwise leave it on so we don't end up with no displays.
# - On open : re-enable the panel.
#
# Internal panel description (from `hyprctl monitors all`):
INTERNAL='desc:Samsung Display Corp. 0x419D'
INTERNAL_MODE='2880x1800@120, 0x0, 2.0'

action="${1:-}"

count_monitors() {
    hyprctl monitors -j | jq 'length'
}

case "$action" in
    close)
        # Only blank the laptop screen if there is at least one external monitor.
        if (( $(count_monitors) > 1 )); then
            hyprctl keyword monitor "$INTERNAL, disable"
        fi
        ;;
    open)
        hyprctl keyword monitor "$INTERNAL, $INTERNAL_MODE"
        ;;
    *)
        echo "usage: $0 {open|close}" >&2
        exit 2
        ;;
esac
