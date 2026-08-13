#!/usr/bin/env sh
# Gamemode toggle: strip animations/blur/shadows/gaps for performance.
# Runtime tweaks go through `hyprctl eval`/`repl`: the Lua config manager
# rejects `hyprctl keyword`/`getoption`-style paths.
HYPRGAMEMODE=$(hyprctl repl 'hl.get_config("animations.enabled")' 2>/dev/null)
if [ "$HYPRGAMEMODE" = "true" ]; then
    hyprctl eval '
        hl.config({
            animations = { enabled = false },
            decoration = {
                shadow = { enabled = false },
                blur = { enabled = false },
                fullscreen_opacity = 1,
                rounding = 0,
            },
            general = {
                gaps_in = 0,
                gaps_out = 0,
                border_size = 1,
            },
        })
        hl.animation({ leaf = "borderangle", enabled = false })
    ' >/dev/null
    hyprctl notify 1 5000 "rgb(40a02b)" "Gamemode [ON]"
    exit
else
    hyprctl notify 1 5000 "rgb(d20f39)" "Gamemode [OFF]"
    hyprctl reload
    exit 0
fi
