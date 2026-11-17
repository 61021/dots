# Palette: single source of truth

# Edit this when changing colors, then mirror values into the per-tool files.

| token         | hex / value              | usage                             |
| ------------- | ------------------------ | --------------------------------- |
| `bg-0`        | `#000000`                | main surface (bar, sidebar, rofi) |
| `bg-1`        | `#171717`                | raised: cards, inputs, icon buttons (neutral-900)|
| `bg-2`        | `#262626`                | hover state on raised surfaces (neutral-800)|
| `fg-0`        | `#e5e5e5`                | primary text (neutral-200)        |
| `fg-1`        | `#a1a1a1`                | muted/secondary text (neutral-400)|
| `fg-hi`       | `#fafafa`                | high-contrast text (neutral-50)   |
| `border-soft` | `rgba(255,255,255,0.08)` | subtle separators                 |
| `border-hard` | `rgba(255,255,255,0.20)` | visible borders                   |
| `accent`      | `#fafafa`                | focus / active hint (mono: neutral-50)|
| `success`     | `#00d492`                | "connected"/on state (emerald-400)|
| `warning`     | `#ffd230`                | "connecting"/pending (amber-300)  |
| `error`       | `#ff6467`                | destructive / errors (red-400)    |

## Files to update when changing a value

- `~/stuff/constants/colors/hypr.lua` (Hyprland border colors)
- `~/stuff/constants/colors/rofi.rasi` (Rofi palette)
- `~/stuff/constants/colors/eww.scss` (eww SCSS variables)
- `~/.config/eww/icons/*.svg` and `~/.config/rofi/icons/*.svg` (colours are baked into the files: fg-0, accent, success, error)
- `~/.config/gtk-3.0/gtk.css`, `~/.config/gtk-4.0/gtk.css`, `~/.config/kitty/kitty.conf`, `~/.config/dunst/dunstrc`, `~/.config/hypr/hyprlock.conf`

Values are Tailwind v4 steps (named in the usage column); bg-0 stays pure black for the OLED panel.
