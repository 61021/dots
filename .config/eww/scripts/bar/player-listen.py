#!/usr/bin/env python3
"""Now-playing for the sidebar media card's `deflisten`.

Emits {"status", "title", "artist", "art"} on every player change; purely
event-driven, nothing ticks.
"""

import glob
import hashlib
import json
import os
import select
import subprocess
import sys
import time

EMPTY = {"status": "", "title": "", "artist": "", "art": ""}


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
    art = art_path(pctl("metadata", "mpris:artUrl"))
    return {"status": status, "title": title, "artist": artist, "art": art}


def emit(cur: dict) -> None:
    sys.stdout.write(json.dumps(cur, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def prune_art(max_age_days: int = 7) -> None:
    """Drop cached album art older than max_age_days so /tmp/kw-art-* stays bounded."""
    cutoff = time.time() - max_age_days * 86400
    for f in glob.glob("/tmp/kw-art-*"):
        try:
            if os.path.getmtime(f) < cutoff:
                os.unlink(f)
        except OSError:
            pass


def main() -> None:
    prune_art()
    proc = subprocess.Popen(
        ["playerctl", "--follow", "metadata", "--format", "{{status}}|{{title}}"],
        stdout=subprocess.PIPE,
        text=True,
    )
    cur = state()
    emit(cur)

    while True:
        if not proc.stdout.readline():
            return  # playerctl went away
        # Coalesce bursts (track changes fire several updates).
        end = time.monotonic() + 0.2
        while select.select([proc.stdout], [], [], max(0, end - time.monotonic()))[0]:
            if not proc.stdout.readline():
                return
        new = state()
        if new != cur:
            cur = new
            emit(cur)


if __name__ == "__main__":
    main()
