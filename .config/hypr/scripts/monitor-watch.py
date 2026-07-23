#!/usr/bin/env python3
"""Re-apply the monitor profile whenever Hyprland adds/removes a monitor."""
import json
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


def monitor_set():
    """Sorted connected-monitor names, or None if hyprctl is unavailable."""
    try:
        out = subprocess.run(
            ["hyprctl", "-j", "monitors"], capture_output=True, text=True, timeout=5
        ).stdout
        return ",".join(sorted(m["name"] for m in json.loads(out)))
    except Exception:
        return None


def settle(quiet=2.0, poll=0.5, timeout=20.0):
    """Block until the monitor set has been unchanged for `quiet` seconds.

    Docks bring monitors up one at a time; applying (and relaunching the
    bar) mid-shuffle leaves eww with a wedged invisible surface.
    """
    last = monitor_set()
    stable_since = time.monotonic()
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        time.sleep(poll)
        cur = monitor_set()
        if cur != last:
            last = cur
            stable_since = time.monotonic()
        elif time.monotonic() - stable_since >= quiet:
            return
    log(f"settle timed out after {timeout}s; applying anyway")


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
                log(f"event: {event}; waiting for topology to settle")
                settle()
                apply()


if __name__ == "__main__":
    main()
