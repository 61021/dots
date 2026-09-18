#!/usr/bin/env python3
"""Network state for the bar chip and the kw-wifi panel, straight from libnm.

Event-driven on NetworkManager's D-Bus signals: no polling, no nmcli, and no
scan unless the panel asked for one. Two outputs so a strength tick can never
rebuild the row widgets:

  stdout (deflisten `net`)     hot state, one JSON line per real change
  `eww update net-list=...`    the row lists, only when their content changes

SIGUSR1  panel opened / rescan clicked: scan now, then every 15s while open
SIGUSR2  panel closed: stop the periodic scans
PID file: $XDG_RUNTIME_DIR/kw-net.pid
"""
import json
import os
import signal
import subprocess
import sys

import gi

gi.require_version("NM", "1.0")
from gi.repository import GLib, NM  # noqa: E402

try:
    gi.require_version("GLibUnix", "2.0")
    from gi.repository import GLibUnix  # noqa: E402

    def on_signal(signum, cb):
        GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signum, cb)
except (ValueError, ImportError):

    def on_signal(signum, cb):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signum, cb)


ICONS = os.path.expanduser("~/.config/eww/icons")
PID_FILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "kw-net.pid")
SEC_FLAGS = getattr(NM, "80211ApSecurityFlags")
AP_FLAGS = getattr(NM, "80211ApFlags")
EAP = int(SEC_FLAGS.KEY_MGMT_802_1X)
PRIVACY = int(AP_FLAGS.PRIVACY)
CONNECTING = {
    int(NM.DeviceState.PREPARE),
    int(NM.DeviceState.CONFIG),
    int(NM.DeviceState.NEED_AUTH),
    int(NM.DeviceState.IP_CONFIG),
    int(NM.DeviceState.IP_CHECK),
    int(NM.DeviceState.SECONDARIES),
}
DEBOUNCE_MS = 120
LIST_THROTTLE_MS = 500
SCAN_PERIOD_S = 15
SCAN_TIMEOUT_S = 8
PANEL_OPEN_CAP_S = 600


def level(strength):
    if strength >= 75:
        return "wifi-high"
    if strength >= 50:
        return "wifi-medium"
    if strength >= 25:
        return "wifi-low"
    return "wifi-none"


def band(freq):
    if freq >= 5925:
        return "6 GHz"
    if freq >= 4900:
        return "5 GHz"
    return "2.4 GHz"


def ssid_of(ap):
    raw = ap.get_ssid()
    if raw is None:
        return ""
    return NM.utils_ssid_to_utf8(raw.get_data()) or ""


def ssid_of_connection(con):
    wireless = con.get_setting_wireless() if con else None
    raw = wireless.get_ssid() if wireless else None
    if raw is None:
        return ""
    return NM.utils_ssid_to_utf8(raw.get_data()) or ""


def secured(ap):
    return bool(int(ap.get_flags()) & PRIVACY or int(ap.get_wpa_flags()) or int(ap.get_rsn_flags()))


class NetWatch:
    def __init__(self):
        self.client = NM.Client.new(None)
        self.loop = GLib.MainLoop()
        self.hooked = set()
        self.pending = None
        self.last_hot = None
        self.last_list = None
        self.list_timer = None
        self.list_last_push = 0.0
        self.scanning = False
        self.scan_timeout = None
        self.scan_timer = None
        self.panel_opened_at = None

        c = self.client
        for sig in (
            "device-added",
            "device-removed",
            "connection-added",
            "connection-removed",
            "active-connection-added",
            "active-connection-removed",
        ):
            c.connect(sig, self.on_topology)
        for prop in ("wireless-enabled", "wireless-hardware-enabled", "primary-connection", "state", "connectivity"):
            c.connect(f"notify::{prop}", self.schedule)
        self.hook_all()

        on_signal(signal.SIGUSR1, self.on_panel_open)
        on_signal(signal.SIGUSR2, self.on_panel_close)
        on_signal(signal.SIGTERM, self.quit)
        on_signal(signal.SIGINT, self.quit)

    # --- wiring -------------------------------------------------------------

    def hook(self, obj, *specs):
        if obj is None or obj in self.hooked:
            return
        self.hooked.add(obj)
        for spec in specs:
            obj.connect(spec, self.schedule)

    def hook_all(self):
        for dev in self.client.get_devices():
            self.hook_device(dev)
        for ac in self.client.get_active_connections():
            self.hook(ac, "state-changed", "notify::state")

    def hook_device(self, dev):
        if isinstance(dev, NM.DeviceWifi):
            if dev not in self.hooked:
                dev.connect("access-point-added", self.on_ap_added)
                dev.connect("access-point-removed", self.schedule)
                dev.connect("notify::last-scan", self.on_last_scan)
            self.hook(dev, "state-changed", "notify::active-access-point", "notify::ip4-config")
            for ap in dev.get_access_points():
                self.hook(ap, "notify::strength")
        else:
            self.hook(dev, "state-changed")

    def on_topology(self, _client, obj):
        if isinstance(obj, NM.Device):
            self.hook_device(obj)
        elif isinstance(obj, NM.ActiveConnection):
            self.hook(obj, "state-changed", "notify::state")
        self.schedule()

    def on_ap_added(self, _dev, ap):
        self.hook(ap, "notify::strength")
        self.schedule()

    def on_last_scan(self, *_):
        self.set_scanning(False)
        self.schedule()

    # --- scanning -----------------------------------------------------------

    def wifi_device(self):
        best = None
        for dev in self.client.get_devices():
            if isinstance(dev, NM.DeviceWifi) and (best is None or int(dev.get_state()) > int(best.get_state())):
                best = dev
        return best

    def set_scanning(self, on):
        if self.scan_timeout is not None:
            GLib.source_remove(self.scan_timeout)
            self.scan_timeout = None
        if on:
            self.scan_timeout = GLib.timeout_add_seconds(SCAN_TIMEOUT_S, self.on_scan_timeout)
        if self.scanning != on:
            self.scanning = on
            self.schedule()

    def on_scan_timeout(self):
        self.scan_timeout = None
        self.scanning = False
        self.schedule()
        return False

    def request_scan(self):
        dev = self.wifi_device()
        if dev is None or not self.client.wireless_get_enabled():
            return
        self.set_scanning(True)
        dev.request_scan_async(None, self.on_scan_requested)

    def on_scan_requested(self, dev, result):
        try:
            dev.request_scan_finish(result)
        except GLib.Error:
            # NM rate-limits explicit scans; the list is fresh enough then.
            self.set_scanning(False)

    def on_panel_open(self, *_):
        self.panel_opened_at = GLib.get_monotonic_time() / 1e6
        self.request_scan()
        if self.scan_timer is None:
            self.scan_timer = GLib.timeout_add_seconds(SCAN_PERIOD_S, self.on_scan_tick)
        return True

    def on_panel_close(self, *_):
        self.panel_opened_at = None
        if self.scan_timer is not None:
            GLib.source_remove(self.scan_timer)
            self.scan_timer = None
        return True

    def on_scan_tick(self):
        now = GLib.get_monotonic_time() / 1e6
        if self.panel_opened_at is None or now - self.panel_opened_at > PANEL_OPEN_CAP_S:
            self.scan_timer = None
            self.panel_opened_at = None
            return False
        self.request_scan()
        return True

    # --- state --------------------------------------------------------------

    def schedule(self, *_):
        if self.pending is None:
            self.pending = GLib.timeout_add(DEBOUNCE_MS, self.flush)

    def flush(self):
        self.pending = None
        try:
            hot, rows = self.compute()
        except Exception as err:  # one bad event must not kill the feed
            print(f"nm-listen: {err!r}", file=sys.stderr, flush=True)
            return False
        if hot != self.last_hot:
            self.last_hot = hot
            print(json.dumps(hot, separators=(",", ":"), ensure_ascii=False), flush=True)
        if rows != self.last_list:
            self.last_list = rows
            self.push_list()
        return False

    def push_list(self):
        now = GLib.get_monotonic_time() / 1000
        wait = LIST_THROTTLE_MS - (now - self.list_last_push)
        if wait > 0:
            if self.list_timer is None:
                self.list_timer = GLib.timeout_add(int(wait), self.on_list_timer)
            return
        self.list_last_push = now
        payload = json.dumps(self.last_list, separators=(",", ":"), ensure_ascii=False)
        subprocess.Popen(
            ["eww", "update", f"net-list={payload}"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def on_list_timer(self):
        self.list_timer = None
        self.push_list()
        return False

    def compute(self):
        c = self.client
        radio = bool(c.wireless_get_enabled() and c.wireless_hardware_get_enabled())
        dev = self.wifi_device()
        dev_state = int(dev.get_state()) if dev else 0
        active_ap = dev.get_active_access_point() if dev else None

        eth_up = any(
            d.get_device_type() == NM.DeviceType.ETHERNET and int(d.get_state()) == int(NM.DeviceState.ACTIVATED)
            for d in c.get_devices()
        )
        primary = c.get_primary_connection()
        primary_type = primary.get_connection_type() if primary else ""

        busy = ""
        if dev is not None and dev_state in CONNECTING:
            ac = dev.get_active_connection()
            busy = ssid_of_connection(ac.get_connection()) if ac else ""
            if not busy and active_ap is not None:
                busy = ssid_of(active_ap)

        conn = {"ssid": "", "signal": 0, "icon": "wifi-none", "sec": False, "band": "", "ip": "", "sub": ""}
        wifi_up = dev is not None and dev_state == int(NM.DeviceState.ACTIVATED) and active_ap is not None
        if wifi_up:
            strength = int(active_ap.get_strength()) // 5 * 5
            ip4 = dev.get_ip4_config()
            addrs = ip4.get_addresses() if ip4 else []
            freq_band = band(int(active_ap.get_frequency()))
            conn = {
                "ssid": ssid_of(active_ap),
                "signal": strength,
                "icon": level(strength),
                "sec": secured(active_ap),
                "band": freq_band,
                "ip": addrs[0].get_address() if addrs else "",
                "sub": f"Connected · {freq_band}",
            }

        if primary_type == "802-3-ethernet" or (eth_up and not wifi_up):
            state = "wired"
        elif wifi_up:
            state = "wifi"
        elif busy:
            state = "connecting"
        elif not radio:
            state = "off"
        else:
            state = "offline"

        if state == "wifi":
            icon, label = conn["icon"], conn["ssid"]
            tip = f"{conn['ssid']} · {conn['signal']}% · {conn['band']}"
            if conn["ip"]:
                tip += f"\n{conn['ip']}"
        elif state == "wired":
            icon, label, tip = "plugs-connected", "Wired", "Wired connection"
        elif state == "connecting":
            icon, label, tip = "wifi-none", busy, f"Connecting to {busy}…"
        elif state == "off":
            icon, label, tip = "wifi-slash", "Wi-Fi off", "Wi-Fi is turned off"
        else:
            icon, label, tip = "wifi-x", "Offline", "No network connection"

        hot = {
            "icon": f"{ICONS}/{icon}.svg",
            "label": label,
            "tip": tip,
            "state": state,
            "radio": radio,
            "conn": conn,
            "busy": busy,
            "scanning": bool(self.scanning),
        }

        saved = set()
        for con in c.get_connections():
            if con.get_connection_type() == "802-11-wireless":
                ssid = ssid_of_connection(con)
                if ssid:
                    saved.add(ssid)

        best = {}
        for ap in dev.get_access_points() if (dev and radio) else []:
            ssid = ssid_of(ap)
            if not ssid or ssid == conn["ssid"]:
                continue
            strength = int(ap.get_strength())
            cur = best.get(ssid)
            if cur is None or strength > cur[0]:
                wpa, rsn = int(ap.get_wpa_flags()), int(ap.get_rsn_flags())
                best[ssid] = (
                    strength,
                    {
                        "ssid": ssid,
                        "icon": level(strength),
                        "sec": secured(ap),
                        "eap": bool((wpa | rsn) & EAP),
                        "saved": ssid in saved,
                    },
                )
        rows = sorted((r for _, r in best.values()), key=lambda r: r["ssid"].casefold())
        lists = {
            "known": [r for r in rows if r["saved"]][:8],
            "others": [r for r in rows if not r["saved"]][:12],
        }
        return hot, lists

    # --- lifecycle ----------------------------------------------------------

    def quit(self, *_):
        self.loop.quit()
        return False

    def run(self):
        with open(PID_FILE, "w") as f:
            f.write(str(os.getpid()))
        try:
            self.flush()
            self.loop.run()
        finally:
            try:
                os.unlink(PID_FILE)
            except OSError:
                pass


if __name__ == "__main__":
    NetWatch().run()
