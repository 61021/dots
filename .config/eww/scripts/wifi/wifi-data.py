#!/usr/bin/env python3
"""Wi-Fi panel data: nmcli scan -> single-line JSON for the `kw-wifi` eww var.

Emits: {radio, conn{ssid,signal,icon,sec}, known[], others[]}
- conn is always a full object (empty ssid when disconnected) so eww attr
  bindings never touch a missing key.
- Signals are quantized to steps of 5 so refreshes don't churn the row list.
"""
import json
import re
import subprocess


def run(args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=10).stdout
    except Exception:
        return ""


def split_terse(line):
    # nmcli -t escapes ':' and '\' inside fields
    parts = re.split(r"(?<!\\):", line)
    return [p.replace("\\:", ":").replace("\\\\", "\\") for p in parts]


def icon(sig):
    if sig >= 75:
        return "wifi-high"
    if sig >= 50:
        return "wifi-medium"
    if sig >= 25:
        return "wifi-low"
    return "wifi-none"


radio = run(["nmcli", "radio", "wifi"]).strip() == "enabled"

saved = set()
for line in run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]).splitlines():
    f = split_terse(line)
    if len(f) == 2 and f[1] == "802-11-wireless":
        saved.add(f[0])

conn = {"ssid": "", "signal": 0, "icon": "wifi-none", "sec": False}
best = {}
for line in run(
    ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
).splitlines():
    f = split_terse(line)
    if len(f) < 4 or not f[1]:
        continue  # skip hidden SSIDs
    active, ssid, sig_s, sec_s = f[0], f[1], f[2], f[3]
    try:
        sig = int(sig_s) // 5 * 5
    except ValueError:
        sig = 0
    sec = bool(sec_s and sec_s != "--")
    if active == "yes":
        conn = {"ssid": ssid, "signal": sig, "icon": icon(sig), "sec": sec}
        continue
    cur = best.get(ssid)
    if cur is None or sig > cur["signal"]:
        best[ssid] = {
            "ssid": ssid,
            "signal": sig,
            "icon": icon(sig),
            "sec": sec,
            "eap": "802.1X" in sec_s,
            "saved": ssid in saved,
        }

nets = [n for n in sorted(best.values(), key=lambda n: -n["signal"]) if n["ssid"] != conn["ssid"]]
known = [n for n in nets if n["saved"]][:8]
others = [n for n in nets if not n["saved"]][:12]

print(json.dumps({"radio": radio, "conn": conn, "known": known, "others": others}))
