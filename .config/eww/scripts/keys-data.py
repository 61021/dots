#!/usr/bin/env python3
"""Keys sheet data: the LIVE Hyprland binds, grouped into four columns.

Every hl.bind carries a description; this maps descriptions to groups and
short labels, folds the per-key families (workspace numbers, H/J/K/L) into
one row each, and puts anything it does not know under "More" so a new bind
still shows up.
"""
import json
import re
import subprocess

MODS = [(4, "Ctrl"), (8, "Alt"), (1, "Shift"), (64, "Super")]
KEYS = {"slash": "/", "mouse:272": "Drag", "mouse:273": "Right drag"}

# (pattern on the description, row label, key cap that replaces the family)
FAMILIES = [
    (r"Go to workspace \d+", "Go to workspace", "1-0"),
    (r"Move window to workspace \d+", "Move window there", "1-0"),
    (r"Focus (left|down|up|right)", "Focus a neighbour", "HJKL"),
    (r"Move window (left|down|up|right)", "Move window", "HJKL"),
    (r"Make window (narrower|taller|shorter|wider)", "Resize window", "HJKL"),
    (r"(Next|Previous) workspace", "Next or previous", "Scroll"),
]
LABELS = {
    "Open terminal": "Terminal",
    "Move window to scratchpad": "Move to scratchpad",
    "Screenshot a region to file": "Region to file",
    "Screenshot a region to clipboard": "Region to clipboard",
    "Drag to move window": "Move with the mouse",
    "Drag to resize window": "Resize with the mouse",
}
COLUMNS = [
    ("Open", ["App launcher", "Terminal", "Control center", "Calendar", "Wi-Fi panel",
              "Clipboard history", "Pick wallpaper", "Pick a color", "Show keybinds"]),
    ("Windows", ["Close window", "Maximize window", "Float or tile window", "Swap with master",
                 "Next window", "Previous window", "Focus a neighbour", "Move window", "Resize window",
                 "Move with the mouse", "Resize with the mouse"]),
    ("Workspaces", ["Go to workspace", "Move window there", "Next or previous",
                    "Show or hide scratchpad", "Move to scratchpad"]),
    ("Screen", ["Screenshot the screen", "Screenshot a window", "Region to file", "Region to clipboard",
                "Lock screen", "Game mode", "TV mode on or off", "Download mode on or off", "Reload Hyprland config"]),
]


def main() -> None:
    binds = json.loads(subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True).stdout or "[]")
    rows: dict[str, list[str]] = {}
    for b in binds:
        key = b["key"]
        if key.startswith("XF86"):
            continue  # the keys print their own job
        desc = b["description"] if b.get("has_description") else "(no description)"
        caps = [name for bit, name in MODS if b["modmask"] & bit]
        for pattern, label, cap in FAMILIES:
            if re.fullmatch(pattern, desc):
                desc, key = label, cap
                break
        else:
            desc = LABELS.get(desc, desc)
            key = KEYS.get(key, key)
        rows.setdefault(desc, caps + [key])

    columns = []
    for title, wanted in COLUMNS:
        found = [{"desc": d, "keys": rows.pop(d)} for d in wanted if d in rows]
        columns.append({"groups": [{"title": title, "rows": found}]})
    if rows:
        more = [{"desc": d, "keys": k} for d, k in rows.items()]
        columns[2]["groups"].append({"title": "More", "rows": more})
    print(json.dumps(columns))


if __name__ == "__main__":
    main()
