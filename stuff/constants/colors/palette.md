# Palette — single source of truth

# Edit this when changing colors, then mirror values into the per-tool files.

| token         | hex / value              | usage                             |
| ------------- | ------------------------ | --------------------------------- |
| `bg-0`        | `#000000`                | main surface (bar, sidebar, rofi) |
| `bg-1`        | `#0a0a0a`                | raised: inputs, icon buttons      |
| `bg-2`        | `#141414`                | hover state on raised surfaces    |
| `fg-0`        | `#e5e7eb`                | primary text                      |
| `fg-1`        | `#6b7280`                | muted/secondary text              |
| `fg-hi`       | `#f8fafc`                | high-contrast text (clock, brand) |
| `border-soft` | `rgba(255,255,255,0.08)` | subtle separators                 |
| `border-hard` | `rgba(255,255,255,0.20)` | visible borders                   |
| `accent`      | `#89ddff`                | focus / active hint (cyan)        |
| `success`     | `#4ade80`                | "connected"/on state              |
| `warning`     | `#facc15`                | "connecting"/pending              |
| `error`       | `#ef4444`                | destructive / errors              |

## Files to update when changing a value

- `~/stuff/constants/colors/hypr.conf` (Hyprland border colors)
- `~/stuff/constants/colors/rofi.rasi` (Rofi palette)
- `~/stuff/constants/colors/eww.scss` (eww SCSS variables)
