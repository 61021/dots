#!/usr/bin/env python3
"""Overview strip data: the focused monitor's occupied workspaces as thumbnails.

Each window becomes a tile at its real place and size inside a 208x130
thumbnail, with its app icon; the focused window and the active workspace
are flagged. Prints one JSON object for the kw-ov eww variable.

eww cannot loop inside an overlay, so every workspace carries exactly SLOTS
tiles with ready-made class and style strings; unused ones are "gone".
"""
import glob
import hashlib
import importlib.util
import json
import os
import socket

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
SOCKET = os.path.join(RUNTIME, "hypr", os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""), ".socket.sock")
CACHE = os.path.expanduser("~/.cache/kw-overview")
ICONS = os.path.join(RUNTIME, "kw-overview-icons.json")
TW, TH, PAD = 208, 130, 4
SLOTS = 8
GONE = {"cls": "kw-ov-win gone", "box": "", "ico": ""}


def tile(x: int, y: int, w: int, h: int, icon: str, focused: bool) -> dict[str, str]:
    """One window tile; the 1px border sits inside the given box."""
    return {
        "cls": "kw-ov-win focused" if focused else "kw-ov-win",
        "box": f"margin-left: {x}px; margin-top: {y}px; min-width: {max(w - 2, 10)}px; min-height: {max(h - 2, 10)}px;",
        "ico": f"background-image: url('{icon}');" if icon else "",
    }


def slots(tiles: list[dict[str, str]]) -> list[dict[str, str]]:
    return (tiles + [GONE] * SLOTS)[:SLOTS]


def hypr(cmd: str):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(SOCKET)
        s.sendall(f"j/{cmd}".encode())
        chunks = []
        while data := s.recv(65536):
            chunks.append(data)
    return json.loads(b"".join(chunks) or b"null")


def icons_for(classes: set[str]) -> dict[str, str]:
    """Class -> icon path, cached: the bar's resolver needs GTK and is slow to load."""
    try:
        with open(ICONS) as f:
            cache = json.load(f)
    except (OSError, ValueError):
        cache = {}
    missing = [c for c in classes if c not in cache]
    if missing:
        spec = importlib.util.spec_from_file_location("kw_ws", os.path.expanduser("~/.config/eww/scripts/bar/workspaces.py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        for c in missing:
            cache[c] = mod.resolve_icon(c)
        with open(ICONS, "w") as f:
            json.dump(cache, f)
    return cache


def wall_thumb() -> str:
    """The current wallpaper cropped to the thumbnail's shape, cached per file."""
    src = os.path.realpath(os.path.expanduser("~/.cache/current-wallpaper"))
    try:
        st = os.stat(src)
    except OSError:
        return ""
    key = hashlib.sha1(f"{src}:{st.st_mtime_ns}:{st.st_size}".encode()).hexdigest()[:12]
    out = os.path.join(CACHE, f"wall-{key}.jpg")
    if not os.path.exists(out):
        from PIL import Image

        os.makedirs(CACHE, exist_ok=True)
        for old in glob.glob(os.path.join(CACHE, "wall-*.jpg")):
            os.remove(old)
        w, h = TW * 2, TH * 2
        im = Image.open(src)
        im.draft("RGB", (w * 2, h * 2))
        im = im.convert("RGB")
        ratio = max(w / im.width, h / im.height)
        im = im.resize((round(im.width * ratio), round(im.height * ratio)))
        left, top = (im.width - w) // 2, (im.height - h) // 2
        im.crop((left, top, left + w, top + h)).save(out, quality=84)
    return out


def main() -> None:
    mon = next((m for m in hypr("monitors") if m.get("focused")), None)
    if not mon:
        print(json.dumps({"wall": "", "ws": []}))
        return
    width, height = mon["width"] / mon["scale"], mon["height"] / mon["scale"]
    left, top, right, bottom = mon["reserved"]
    ux, uy = mon["x"] + left, mon["y"] + top
    uw, uh = width - left - right, height - top - bottom
    iw, ih = TW - 2 * PAD, TH - 2 * PAD
    active = mon["activeWorkspace"]["id"]
    focused = (hypr("activewindow") or {}).get("address")
    clients = [c for c in hypr("clients")
               if c.get("mapped") and not c.get("hidden") and c["monitor"] == mon["id"] and c["workspace"]["id"] > 0]
    icons = icons_for({c["class"] for c in clients})

    spaces: dict[int, list] = {active: []}
    for c in sorted(clients, key=lambda c: (c["at"][0], c["at"][1])):
        x0 = min(max((c["at"][0] - ux) / uw, 0), 1)
        y0 = min(max((c["at"][1] - uy) / uh, 0), 1)
        x1 = min(max((c["at"][0] + c["size"][0] - ux) / uw, 0), 1)
        y1 = min(max((c["at"][1] + c["size"][1] - uy) / uh, 0), 1)
        spaces.setdefault(c["workspace"]["id"], []).append(tile(
            PAD + round(x0 * iw), PAD + round(y0 * ih), round((x1 - x0) * iw), round((y1 - y0) * ih),
            icons.get(c["class"], ""), c["address"] == focused,
        ))
    print(json.dumps({
        "wall": wall_thumb(),
        "ws": [{"id": i, "active": i == active, "wins": slots(spaces[i])} for i in sorted(spaces)],
    }))


if __name__ == "__main__":
    main()
