-- ─────────────────────────────────────────────────────────────
-- Window, layer & workspace rules (required from hyprland.lua)
-- Docs: https://wiki.hypr.land/Configuring/Basics/Window-Rules/
--
-- All rules are named: named rules are updated in-place on reload
-- instead of duplicated, and can be toggled via their handles.
-- ─────────────────────────────────────────────────────────────

-- ── "Smart gaps": no gaps/border when only one tiled window ─
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
hl.window_rule({
    name  = "smart-gaps-wtv1-border",
    match = { float = false, workspace = "w[tv1]" },
    border_size = 0,
})
-- hl.window_rule({
--     name  = "smart-gaps-wtv1-rounding",
--     match = { float = false, workspace = "w[tv1]" },
--     rounding = 0,
-- })
hl.window_rule({
    name  = "smart-gaps-f1-border",
    match = { float = false, workspace = "f[1]" },
    border_size = 0,
})
hl.window_rule({
    name  = "smart-gaps-f1-rounding",
    match = { float = false, workspace = "f[1]" },
    rounding = 0,
})

-- Ignore maximize requests from apps (recommended)
hl.window_rule({
    name  = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix focus issue with empty XWayland windows
hl.window_rule({
    name  = "xwayland-empty-no-focus",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- ── Floating helpers ─────────────────────────────────────────
hl.window_rule({ name = "float-pavucontrol", match = { class = "^(pavucontrol)$" },          float = true })
hl.window_rule({ name = "float-blueman",     match = { class = "^(blueman-manager)$" },      float = true })
hl.window_rule({ name = "float-nm-editor",   match = { class = "^(nm-connection-editor)$" }, float = true })
hl.window_rule({ name = "float-qalculate",   match = { class = "^(qalculate-gtk)$" },        float = true })

hl.window_rule({
    name   = "float-nwg-look",
    match  = { class = "^(nwg-look)$" },
    float  = true,
    size   = {700, 600},
    center = true,
})

-- Generic floating kitty (used by bar buttons, e.g. nmtui)
hl.window_rule({
    name   = "float-dotfiles-floating",
    match  = { class = "^(dotfiles-floating)$" },
    float  = true,
    size   = {720, 520},
    center = true,
})

-- feh: float at its own --geometry size (set in .config/feh/themes)
hl.window_rule({
    name   = "float-feh",
    match  = { class = "^(feh)$" },
    float  = true,
    center = true,
})

-- ── Picture-in-Picture ───────────────────────────────────────
-- (was `move 69.5% 4%`; percentages are now monitor expressions)
hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
    pin   = true,
    move  = {"monitor_w * 0.695", "monitor_h * 0.04"},
})

-- ── File pickers (xdg-desktop-portal-gtk) ────────────────────
hl.window_rule({
    name   = "float-portal-gtk",
    match  = { class = "^(xdg-desktop-portal-gtk)$" },
    float  = true,
    center = true,
})

-- ── eww sidebar: slide in from the left edge ─────────────────
hl.layer_rule({
    name      = "kw-sidebar-anim",
    match     = { namespace = "^kw-sidebar$" },
    animation = "slide left",
})
-- Click-outside-dismiss backdrop (below bar + wifi panel in the fg layer;
-- the sidebar itself is overlay-stacked, so it's above this regardless).
hl.layer_rule({
    name    = "kw-sidebar-bg",
    match   = { namespace = "^kw-sidebar-bg$" },
    order   = 2,
    no_anim = true,  -- was `animation none`
})

-- ── eww bar + calendar popover ───────────────────────────────
-- Same layer (top). Hyprland renders higher `order` FIRST (= below),
-- so order 1 puts the calendar underneath the bar and its slide-up
-- close animation disappears behind the clock instead of over it.
hl.layer_rule({
    name      = "kw-calendar",
    match     = { namespace = "^kw-calendar$" },
    order     = 1,
    animation = "slide top",
})

-- ── eww wifi panel: same popover treatment as the calendar ───
-- mac-style: quick subtle scale+fade, not the calendar's slide
hl.layer_rule({
    name      = "kw-wifi",
    match     = { namespace = "^kw-wifi$" },
    order     = 1,
    animation = "popin 95%",
})
-- Invisible click-outside-dismiss backdrop: below the panel (higher order
-- renders lower in the same layer), no animation on an invisible surface.
hl.layer_rule({
    name    = "kw-wifi-bg",
    match   = { namespace = "^kw-wifi-bg$" },
    order   = 2,
    no_anim = true,
})
-- Password dialog: default order 0 = renders above the panel; quick popin.
hl.layer_rule({
    name      = "kw-wifi-pw",
    match     = { namespace = "^kw-wifi-pw$" },
    animation = "popin 90%",
})
