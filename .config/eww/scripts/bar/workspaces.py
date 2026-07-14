#!/usr/bin/env python3
"""Streams Hyprland workspace state as JSON for the bar's `deflisten`.

One compact array per line, e.g.:
  [{"id": 2, "active": true, "icons": ["/usr/share/.../kitty.svg", ...]}, ...]

Only occupied workspaces (plus the active one) are included; each window
contributes one resolved app-icon path, so icon count == window count.
Special workspaces (negative ids) are excluded.
"""

import configparser
import glob
import json
import os
import select
import socket
import sys

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk  # noqa: E402

RUNTIME = os.path.join(
    os.environ["XDG_RUNTIME_DIR"], "hypr", os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
)
FALLBACK_ICON = "application-x-executable"
RELEVANT = (
    "workspace",
    "createworkspace",
    "destroyworkspace",
    "moveworkspace",
    "renameworkspace",
    "openwindow",
    "closewindow",
    "movewindow",
    "focusedmon",
)

icon_theme = Gtk.IconTheme.get_default()
_icon_cache: dict[str, str] = {}
_desktop_index: dict[str, str] | None = None  # lowercase key -> Icon= value
_urgent_addrs: set[str] = set()  # hex window addresses (no 0x) awaiting attention


def hypr_request(cmd: str) -> object:
    """One-shot JSON request over Hyprland's command socket."""
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(os.path.join(RUNTIME, ".socket.sock"))
        s.sendall(cmd.encode())
        chunks = []
        while data := s.recv(65536):
            chunks.append(data)
    return json.loads(b"".join(chunks))


def desktop_index() -> dict[str, str]:
    """Map desktop-file basenames and StartupWMClass values to icon names."""
    global _desktop_index
    if _desktop_index is not None:
        return _desktop_index
    index: dict[str, str] = {}
    data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    data_dirs.insert(0, os.path.expanduser("~/.local/share"))
    for d in data_dirs:
        for path in glob.glob(os.path.join(d, "applications", "*.desktop")):
            cp = configparser.RawConfigParser(interpolation=None, strict=False)
            try:
                cp.read(path, encoding="utf-8")
                entry = cp["Desktop Entry"]
            except Exception:
                continue
            icon = entry.get("Icon")
            if not icon:
                continue
            basename = os.path.basename(path)[: -len(".desktop")].lower()
            index.setdefault(basename, icon)
            wm_class = entry.get("StartupWMClass")
            if wm_class:
                index.setdefault(wm_class.lower(), icon)
    _desktop_index = index
    return index


def resolve_icon(cls: str) -> str:
    """Resolve a window class to an icon file path (cached)."""
    if cls in _icon_cache:
        return _icon_cache[cls]

    candidates = []
    from_desktop = desktop_index().get(cls.lower())
    if from_desktop:
        candidates.append(from_desktop)
    candidates += [cls, cls.lower(), FALLBACK_ICON]

    path = ""
    for name in candidates:
        if os.path.isabs(name) and os.path.isfile(name):
            path = name
            break
        info = icon_theme.lookup_icon(name, 32, 0)
        if info:
            path = info.get_filename()
            break

    _icon_cache[cls] = path
    return path


def emit() -> None:
    workspaces = [w for w in hypr_request("j/workspaces") if w["id"] > 0]
    active_id = hypr_request("j/activeworkspace")["id"]

    icons_by_ws: dict[int, list[str]] = {}
    urgent_ws: set[int] = set()
    live_addrs: set[str] = set()
    clients = hypr_request("j/clients")
    for client in clients:
        ws_id = client["workspace"]["id"]
        addr = client.get("address", "").removeprefix("0x")
        live_addrs.add(addr)
        if ws_id <= 0 or not client.get("mapped", True):
            continue
        cls = client.get("class") or client.get("initialClass") or ""
        icons_by_ws.setdefault(ws_id, []).append(resolve_icon(cls))
        if addr in _urgent_addrs:
            urgent_ws.add(ws_id)

    # Urgency is resolved by visiting the workspace (or the window dying).
    _urgent_addrs.intersection_update(live_addrs)
    if active_id in urgent_ws:
        for client in clients:
            if client["workspace"]["id"] == active_id:
                _urgent_addrs.discard(client.get("address", "").removeprefix("0x"))
        urgent_ws.discard(active_id)

    out = [
        {
            "id": w["id"],
            "active": w["id"] == active_id,
            "urgent": w["id"] in urgent_ws,
            "icons": sorted(icons_by_ws.get(w["id"], [])),
        }
        for w in sorted(workspaces, key=lambda w: w["id"])
        if w["id"] == active_id or icons_by_ws.get(w["id"])
    ]
    sys.stdout.write(json.dumps(out, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def process(lines: bytes) -> bool:
    """Digest raw event lines; return whether a re-emit is warranted."""
    dirty = False
    for line in lines.split(b"\n"):
        name, _, payload = line.partition(b">>")
        event = name.decode(errors="replace").removesuffix("v2")
        if event == "urgent":
            _urgent_addrs.add(payload.decode(errors="replace").strip().removeprefix("0x"))
            dirty = True
        elif event in RELEVANT:
            dirty = True
    return dirty


def main() -> None:
    emit()
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(os.path.join(RUNTIME, ".socket2.sock"))
        buf = b""
        while True:
            data = s.recv(4096)
            if not data:
                return  # Hyprland went away
            buf += data
            lines, _, buf = buf.rpartition(b"\n")
            if not process(lines):
                continue
            # Coalesce event bursts into a single fresh emit, still
            # digesting every drained line (urgent events matter).
            while select.select([s], [], [], 0.05)[0]:
                data = s.recv(4096)
                if not data:
                    return
                buf += data
                lines, _, buf = buf.rpartition(b"\n")
                process(lines)
            emit()


if __name__ == "__main__":
    main()
