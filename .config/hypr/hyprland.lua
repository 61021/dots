-- ─────────────────────────────────────────────────────────────
-- Hyprland config (Lua), ported from hyprland.conf on 2026-07-29
-- (hyprlang .conf support is deprecated, removed in Hyprland 0.57)
--
-- API stubs for the LSP: /usr/share/hypr/stubs/hl.meta.lua
-- Docs: https://wiki.hypr.land/Configuring/Start/
-- Old config kept alongside for rollback: hyprland.conf
-- ─────────────────────────────────────────────────────────────

------------------
---- MONITORS ----
------------------

-- Layout is managed by ~/.config/hypr/scripts/apply-monitor-profile.sh via
-- `hyprctl eval 'hl.monitor(...)'` (do not run nwg-displays; it writes the
-- old monitors.conf). Static fallback only: the profile script overrides
-- these on startup and every hotplug. Keeps eDP-1 at the right scale/rate
-- if the watcher ever dies.
hl.monitor({ output = "eDP-1", mode = "2880x1800@120", position = "0x0", scale = 2.0 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.0 })


---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "kitty"
local menu     = "~/.local/bin/kw-sound -v .55 -g 300 completion-rotation & rofi -show drun -show-icons -matching fuzzy -theme $HOME/.config/rofi/minimal.rasi"


-------------------
---- AUTOSTART ----
-------------------

-- Polkit agent starts via its enabled systemd user unit (graphical-session.target)

-- hl.exec_cmd runs through `sh -c` and only fires once at startup
-- (`hyprland.start` is not re-emitted on config reloads).
hl.on("hyprland.start", function()
    -- Wallpaper daemon (awww)
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sleep 1 && ~/stuff/constants/scripts/wallpaper/restore-wallpaper.sh")

    -- Idle daemon (lock / dpms / suspend per ~/.config/hypr/hypridle.conf)
    hl.exec_cmd("hypridle")

    -- Night-light daemon: starts neutral (6500K); the sidebar eye button toggles 3000K via IPC
    hl.exec_cmd("hyprsunset -t 6500")

    -- Charger plug/unplug sound
    hl.exec_cmd("~/stuff/constants/scripts/battery/charge-sound.sh")

    -- Low battery notifications
    hl.exec_cmd("~/stuff/constants/scripts/battery/low-bat-notification.sh")

    -- Cliphist (text + images), via a hook that skips password-manager copies
    hl.exec_cmd("wl-paste --type text --watch ~/.config/hypr/scripts/cliphist-store.sh")
    hl.exec_cmd("wl-paste --type image --watch ~/.config/hypr/scripts/cliphist-store.sh")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")

    -- Startup chime (kw-sound routes all UI event sounds; Ocean theme w/ freedesktop fallback)
    hl.exec_cmd("sleep 2 && ~/.local/bin/kw-sound desktop-login service-login")

    -- Snappy Switcher (Alt+Tab window switcher)
    -- small delay so the Hyprland IPC socket is ready before the daemon connects
    hl.exec_cmd("sleep 2 && snappy-switcher --daemon")

    -- Monitor profile watcher: applies the right layout on startup and on every
    -- monitor add/remove. Also starts the eww daemon and bar via kw-bar-launch.sh.
    hl.exec_cmd("~/.config/hypr/scripts/monitor-watch.py")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

local runtimeDir = os.getenv("XDG_RUNTIME_DIR")
if runtimeDir then
    hl.env("SSH_AUTH_SOCK", runtimeDir .. "/ssh-agent.socket")
end

-- XDG Desktop Portal
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- QT
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- Mozilla
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- VA-API: pin the Meteor Lake media driver (intel-media-driver) for HW video decode
hl.env("LIBVA_DRIVER_NAME", "iHD")

-- Set the cursor theme + size for xcursor / hyprcursor
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")

-- Ozone
hl.env("OZONE_PLATFORM", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")

-- XWayland
-- hl.config({ xwayland = { force_zero_scaling = true } })  -- disabled; breaks XWayland apps on HiDPI


---------------------
---- PERMISSIONS ----
---------------------

-- Permission changes require a Hyprland restart; they are not applied on reload.
hl.permission({ binary = "/usr/(s?bin|local/bin)/hyprlock",   type = "screencopy", mode = "allow" })
hl.permission({ binary = "/usr/(s?bin|local/bin)/hyprpicker", type = "screencopy", mode = "allow" })
hl.permission({ binary = "/usr/(s?bin|local/bin)/grim",       type = "screencopy", mode = "allow" })


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Border colors live in ~/stuff/constants/colors/hypr.lua
-- (tokens defined in ~/stuff/constants/colors/palette.md)
local colorsOk, colors = pcall(require, "/home/khaled/stuff/constants/colors/hypr.lua")
if not colorsOk or type(colors) ~= "table" then
    colors = { active_border = "rgba(ffffff50)", inactive_border = "rgba(ffffff00)" }
end

hl.config({
    general = {
        gaps_in     = 6,
        gaps_out    = 10,
        border_size = 1,
        col = {
            active_border   = colors.active_border,
            inactive_border = colors.inactive_border,
        },
        resize_on_border = true,
        allow_tearing    = false,
        layout           = "master",
        snap = { enabled = true },  -- inlined from HyprMod (hyprland-gui.conf)
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 0.9,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },

        blur = {
            enabled = false,
            size    = 2,
            passes  = 1,

            vibrancy = 0.1696,
        },
    },

    animations = { enabled = true },

    master = {
        new_status = "slave",
    },

    misc = {
        force_default_wallpaper = 0,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true, -- If true disables the random hyprland logo / anime girl background. :(

        -- Window swallowing: hide terminal when it spawns a GUI child
        enable_swallow = true,
        swallow_regex  = "^(kitty)$",

        -- VRR where the display supports it (eDP): small power win, no-op on the fixed-rate externals
        vrr = 1,

        -- Inlined from HyprMod (hyprland-gui.conf) on 2026-07-29: HyprMod
        -- writes hyprlang and can't manage a Lua config; edit these here.
        animate_mouse_windowdragging = true,
        disable_splash_rendering     = true,
        -- false = attention requests mark the workspace urgent (red pill in
        -- the bar) instead of stealing focus. Flipped from true on 2026-07-14
        -- for the bar's urgent-workspace indicator.
        focus_on_activate = false,
    },

    ecosystem = {  -- inlined from HyprMod (hyprland-gui.conf)
        enforce_permissions = true,
        no_donation_nag     = true,
    },
})

-- Animation curves (same set as the old .conf; speed unit is unchanged: 1 = 100ms)
hl.curve("linear",        { type = "bezier", points = { {0, 0},      {1, 1}       } })
hl.curve("md3_standard",  { type = "bezier", points = { {0.2, 0},    {0, 1}       } })
hl.curve("md3_decel",     { type = "bezier", points = { {0.05, 0.7}, {0.1, 1}     } })
hl.curve("md3_accel",     { type = "bezier", points = { {0.3, 0},    {0.8, 0.15}  } })
hl.curve("overshot",      { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.1}   } })
hl.curve("crazyshot",     { type = "bezier", points = { {0.1, 1.5},  {0.76, 0.92} } })
hl.curve("hyprnostretch", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.0}   } })
hl.curve("fluent_decel",  { type = "bezier", points = { {0.1, 1},    {0, 1}       } })
hl.curve("easeInOutCirc", { type = "bezier", points = { {0.85, 0},   {0.15, 1}    } })
hl.curve("easeOutCirc",   { type = "bezier", points = { {0, 0.55},   {0.45, 1}    } })
hl.curve("easeOutExpo",   { type = "bezier", points = { {0.16, 1},   {0.3, 1}     } })

hl.animation({ leaf = "windows",          enabled = true, speed = 3,   bezier = "md3_decel",   style = "popin 60%" })
hl.animation({ leaf = "border",           enabled = true, speed = 10,  bezier = "default" })
hl.animation({ leaf = "fade",             enabled = true, speed = 2.5, bezier = "md3_decel" })
hl.animation({ leaf = "layers",           enabled = true, speed = 2,   bezier = "md3_decel",   style = "slide" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 3.5, bezier = "easeOutExpo", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3,   bezier = "md3_decel",   style = "slidevert" })


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us, ara",
        kb_options = "grp:caps_select",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        repeat_rate = 50,  -- inlined from HyprMod (hyprland-gui.conf)

        touchpad = {
            natural_scroll = false,
            disable_while_typing = false, -- keep touchpad usable while keys are held (kb+touchpad gaming)
        },
    },
})

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/
hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })


---------------------
---- KEYBINDINGS ----
---------------------

-- See https://wiki.hypr.land/Configuring/Basics/Binds/
local mainMod = "ALT"

hl.bind("CTRL + SHIFT + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("hyprpicker -anqdl"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard-picker.sh"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("~/.local/bin/kw-sound -v .7 trash-empty & cliphist wipe"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("~/stuff/constants/scripts/wallpaper/pick-wallpaper.sh"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("~/.config/eww/scripts/kw-wifi.sh"))
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("~/.config/hypr/scripts/gamemode.sh"))
hl.bind(mainMod .. " + G", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))  -- was `fullscreen, 1`
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.layout("swapwithmaster"))
hl.bind("SUPER + L", hl.dsp.exec_cmd("~/.local/bin/kw-lock"))
-- TV mode toggle; also the way OUT while the screen is off (binds still fire under dpms off)
hl.bind(mainMod .. " + T",
    hl.dsp.exec_cmd("~/.config/eww/scripts/tv-mode.sh toggle; ~/.config/eww/scripts/kw-refresh.sh tv"),
    { locked = true })

-- Focus / move / resize with mainMod + H/J/K/L
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), { repeating = true })

-- Reload Hyprland config
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind("CTRL + SHIFT + Space", hl.dsp.exec_cmd(menu))
hl.bind("CTRL + F12", hl.dsp.exec_cmd("hyprshot -m region -o ~/stuff/screenshots --notify"))
-- clipboard-only has no notification, so the shutter plays from the bind; the --notify ones get it via dunst
hl.bind("CTRL + SHIFT + F12", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only && ~/.local/bin/kw-sound camera-shutter"))
hl.bind("Print",         hl.dsp.exec_cmd("hyprshot -m output -o ~/stuff/screenshots --notify"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("hyprshot -m window -o ~/stuff/screenshots --notify"))

-- Snappy Switcher (Alt+Tab)
hl.bind("ALT + Tab", hl.dsp.exec_cmd("snappy-switcher next"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd("snappy-switcher prev"))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,            hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,    hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",          hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S",  hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && ~/.local/bin/kw-sound -u audio-volume-change"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && ~/.local/bin/kw-sound -u audio-volume-change"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && ~/.local/bin/kw-sound -u audio-volume-change"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && ~/.local/bin/kw-sound -u audio-volume-change"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl set 10+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl set 10-"), { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Window/workspace/layer rules live in their own file.
require("windowrules")
