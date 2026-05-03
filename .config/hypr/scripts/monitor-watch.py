#!/usr/bin/env python3
"""Re-apply the monitor profile whenever Hyprland adds/removes a monitor."""
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

SCRIPT = Path.home() / ".config/hypr/scripts/apply-monitor-profile.sh"
EVENTS = ("monitoradded", "monitorremoved", "monitoraddedv2", "monitorremovedv2")
DEBOUNCE_SECONDS = 2.0  # ignore events fired during/just after our own apply

last_apply_done = 0.0


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def apply():
    global last_apply_done
    log("applying monitor profile")
    r = subprocess.run([str(SCRIPT)], capture_output=True, text=True)
    if r.returncode != 0:
        log(f"apply failed (exit {r.returncode}): {r.stderr.strip()}")
    elif r.stderr.strip():
        log(f"apply stderr: {r.stderr.strip()}")
    last_apply_done = time.monotonic()


def main():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not sig or not runtime:
        sys.exit("HYPRLAND_INSTANCE_SIGNATURE / XDG_RUNTIME_DIR not set")

    sock_path = f"{runtime}/hypr/{sig}/.socket2.sock"

    apply()  # initial layout

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock_path)
    buf = b""
    while True:
        chunk = s.recv(4096)
        if not chunk:
            break
        buf += chunk
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            event = line.decode("utf-8", "replace").split(">>", 1)[0]
            if event in EVENTS:
                if time.monotonic() - last_apply_done < DEBOUNCE_SECONDS:
                    log(f"ignoring {event} (debounce)")
                    continue
                log(f"event: {event}")
                apply()


if __name__ == "__main__":
    main()
