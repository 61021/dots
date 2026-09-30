#!/usr/bin/env bash
# Searchable keybind cheat sheet (ALT+/). Reads the LIVE binds from Hyprland,
# so it always matches hyprland.lua; every hl.bind there carries a
# `description`, and a bind without one shows up here as a gap.
set -euo pipefail

hyprctl binds -j | python3 -c '
import html, json, re, sys

MODS = [(4, "CTRL"), (8, "ALT"), (1, "SHIFT"), (64, "SUPER")]
KEYS = {
    "mouse_down": "Scroll down", "mouse_up": "Scroll up",
    "mouse:272": "Left drag", "mouse:273": "Right drag",
    "Return": "Enter", "slash": "/", "Print": "PrtSc",
}

def key_name(key):
    if key.startswith("XF86MonBrightness"):
        return "Brightness key"
    if key.startswith("XF86Audio"):
        return "Media key"
    return KEYS.get(key, key)

rows, seen = [], set()
for b in json.load(sys.stdin):
    mods = [name for bit, name in MODS if b["modmask"] & bit]
    desc = b["description"] if b.get("has_description") else "(no description)"
    rows.append((mods, key_name(b["key"]), desc))

# Collapse the per-number workspace binds into one line per action.
out, groups = [], {}
for mods, key, desc in rows:
    m = re.fullmatch(r"(.* workspace) (\d+)", desc)
    group = (tuple(mods), m.group(1)) if m else None
    if group in groups:
        entry = out[groups[group]]
        entry[1].append(key)
        entry[4].append(m.group(2))
        continue
    if group:
        groups[group] = len(out)
    out.append((mods, [key], desc, group, [m.group(2)] if m else []))

lines = []
for mods, keys, desc, group, nums in out:
    if group:
        keys, desc = [f"{keys[0]}-{keys[-1]}"], f"{group[1]} {nums[0]}-{nums[-1]}"
    combo = " + ".join(mods + keys)
    if (combo, desc) in seen:
        continue
    seen.add((combo, desc))
    lines.append((combo, desc))

width = max(len(c) for c, _ in lines)
for combo, desc in lines:
    print(f"<span font=\"JetBrainsMono Nerd Font 10\" foreground=\"#89ddff\">{html.escape(combo.ljust(width))}</span>   {html.escape(desc)}")
' | rofi -dmenu -i -markup-rows -no-custom -p "Keys" \
      -theme "$HOME/.config/rofi/minimal.rasi" \
      -theme-str 'window { width: 640px; } listview { lines: 14; } entry { placeholder: "Search keybinds"; }' \
      >/dev/null || true
