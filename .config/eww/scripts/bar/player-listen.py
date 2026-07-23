#!/usr/bin/env python3
"""Now-playing for the bar's `deflisten`, with an infinite marquee.

Emits {"status", "title", "artist", "label", "display"}; `display` is a
fixed-width window that slides through long titles while Playing (paused
/ short titles / no player = no ticking, purely event-driven).
"""

import hashlib
import json
import os
import select
import subprocess
import sys
import time

WINDOW = 22  # chars visible in the bar label (monospace)
SEP = "  \u2022  "  # gap between end and restart of the loop
TICK = 0.35  # marquee step seconds

EMPTY = {"status": "", "title": "", "artist": "", "label": "", "art": "", "display": ""}


def pctl(*args: str) -> str:
    try:
        return subprocess.run(
            ["playerctl", *args], capture_output=True, text=True, timeout=3
        ).stdout.strip()
    except Exception:
        return ""


def art_path(url: str) -> str:
    """Resolve mpris artUrl to a local file (downloads http(s) once per URL)."""
    if not url:
        return ""
    if url.startswith("file://"):
        path = url[len("file://") :]
        return path if os.path.isfile(path) else ""
    if url.startswith(("http://", "https://")):
        dest = f"/tmp/kw-art-{hashlib.md5(url.encode()).hexdigest()[:16]}"
        if not os.path.isfile(dest):
            try:
                subprocess.run(
                    ["curl", "-fsSL", "-m", "4", "-o", dest, url],
                    capture_output=True, timeout=6, check=True,
                )
            except Exception:
                return ""
        return dest
    return ""


def state() -> dict:
    status = pctl("status")
    if status not in ("Playing", "Paused"):
        return dict(EMPTY)
    title = pctl("metadata", "title")
    artist = pctl("metadata", "artist")
    label = f"{artist} \u2014 {title}" if artist else title
    art = art_path(pctl("metadata", "mpris:artUrl"))
    return {"status": status, "title": title, "artist": artist, "label": label, "art": art}


def display(cur: dict, offset: int) -> str:
    text = cur["label"]
    if len(text) <= WINDOW:
        return text
    loop = text + SEP
    doubled = loop + loop
    return doubled[offset % len(loop) : offset % len(loop) + WINDOW]


def scrolling(cur: dict) -> bool:
    return cur["status"] == "Playing" and len(cur["label"]) > WINDOW


def emit(cur: dict, offset: int) -> None:
    out = dict(cur)
    out["display"] = display(cur, offset) if cur["status"] else ""
    sys.stdout.write(json.dumps(out, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def main() -> None:
    proc = subprocess.Popen(
        ["playerctl", "--follow", "metadata", "--format", "{{status}}|{{title}}"],
        stdout=subprocess.PIPE,
        text=True,
    )
    cur = state()
    offset = 0
    emit(cur, offset)

    while True:
        timeout = TICK if scrolling(cur) else None
        ready, _, _ = select.select([proc.stdout], [], [], timeout)
        if ready:
            if not proc.stdout.readline():
                return  # playerctl went away
            # Coalesce bursts (track changes fire several updates).
            end = time.monotonic() + 0.2
            while select.select([proc.stdout], [], [], max(0, end - time.monotonic()))[0]:
                if not proc.stdout.readline():
                    return
            cur = state()
            offset = 0
        else:
            offset += 1
        emit(cur, offset)


if __name__ == "__main__":
    main()
