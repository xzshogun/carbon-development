#!/usr/bin/env python3
"""
carbon-bluetooth.py

Robust BlueZ D-Bus event-driven backend for Carbon's Monochrome Orbit Bluetooth Picker.
- Native GIO / GLib implementation (no external python-dbus dependency required)
- Manages adapter discovery (strictly active only while picker is open)
- Emits real-time JSON events to stdout for devices, live battery, and adapter status
- Computes stable angles via MAC hash and RSSI-modulated outer orbital radii
- Implements BlueZ Agent for passkey confirmation pairing (no external dialogs)
- Prunes stale discovered devices (>30s without update)
- Handles connect, disconnect, pair, forget, power_on via stdin commands
- Optional auto-switch default audio output on headset connect via PipeWire/wpctl
"""

import sys
import os
import time
import json
import threading
import signal
import subprocess
from gi.repository import Gio, GLib

BLUEZ_SERVICE = "org.bluez"
ADAPTER_IFACE = "org.bluez.Adapter1"
DEVICE_IFACE = "org.bluez.Device1"
BATTERY_IFACE = "org.bluez.Battery1"
AGENT_MGR_IFACE = "org.bluez.AgentManager1"
AGENT_IFACE = "org.bluez.Agent1"
AGENT_PATH = "/carbon/bluez/agent"

STALE_TIMEOUT_SEC = 30.0

def emit_event(event_dict):
    try:
        line = json.dumps(event_dict)
        sys.stdout.write(line + "\n")
        sys.stdout.flush()
    except Exception:
        pass

def mac_to_angle(mac):
    """Stable hash of device MAC address to angle (0..359.9 degrees)."""
    h = 0
    clean = str(mac).replace(":", "").upper()
    for ch in clean:
        h = ((h << 5) - h + ord(ch)) & 0xffffffff
    return round((h % 3600) / 10.0, 1)

def resolve_device_type(icon_str, class_int, name_str):
    """Map BlueZ Icon and Class to standard types: headphones, speaker, phone, watch, keyboard, mouse, gamepad, generic."""
    ic = str(icon_str or "").lower()
    nm = str(name_str or "").lower()
    cl = int(class_int or 0)

    if any(k in ic for k in ["headset", "headphone"]):
        return "headphones"
    if any(k in ic for k in ["audio-card", "speaker", "audio-speakers"]):
        return "speaker"
    if any(k in ic for k in ["phone", "smartphone", "cellular"]):
        return "phone"
    if "watch" in ic:
        return "watch"
    if "keyboard" in ic:
        return "keyboard"
    if any(k in ic for k in ["mouse", "touchpad"]):
        return "mouse"
    if any(k in ic for k in ["gaming", "gamepad", "joystick"]):
        return "gamepad"

    major = (cl >> 8) & 0x1F
    minor = (cl >> 2) & 0x3F

    if major == 0x04:
        if minor in (0x01, 0x02, 0x06):
            return "headphones"
        if minor in (0x04, 0x05, 0x07, 0x08):
            return "speaker"
        return "headphones"
    elif major == 0x05:
        if cl & 0x0040:
            return "keyboard"
        if cl & 0x0080:
            return "mouse"
        if cl & 0x0004 or minor == 0x04:
            return "gamepad"
        return "keyboard"
    elif major == 0x02:
        return "phone"
    elif major == 0x07:
        return "watch"

    if any(k in nm for k in ["buds", "ear", "headphone", "headset", "airpod", "rockerz", "airdopes", "tune", "wh-", "wf-"]):
        return "headphones"
    if any(k in nm for k in ["speaker", "soundbar", "boom", "flip", "charge", "clip", "go"]):
        return "speaker"
    if any(k in nm for k in ["mouse", "trackpad"]):
        return "mouse"
    if any(k in nm for k in ["keyboard", "keychron"]):
        return "keyboard"
    if any(k in nm for k in ["watch", "band", "fit"]):
        return "watch"
    if any(k in nm for k in ["controller", "gamepad", "xbox", "dualsense", "dualshock"]):
        return "gamepad"
    if any(k in nm for k in ["phone", "galaxy", "iphone", "pixel", "oneplus", "redmi", "xiaomi"]):
        return "phone"

    return "generic"

def compute_orbit_radius(paired, rssi, base_inner=66, base_outer=112):
    if paired:
        return base_inner
    if rssi is None:
        return base_outer
    clamped = max(-100, min(-35, int(rssi)))
    norm = (clamped - (-100)) / ((-35) - (-100))
    return round(base_outer - (norm * 22))

def set_default_pipewire_sink(mac):
    clean_mac = str(mac).replace(":", "_").upper()
    try:
        p = subprocess.run(["pactl", "list", "short", "sinks"], capture_output=True, text=True, timeout=2)
        for line in p.stdout.splitlines():
            parts = line.split()
            if len(parts) >= 2 and clean_mac in parts[1].upper():
                sink_name = parts[1]
                subprocess.run(["pactl", "set-default-sink", sink_name], check=False, timeout=2)
                emit_event({"type": "info", "message": f"default audio output set to {sink_name}"})
                return True
    except Exception:
        pass
    return False

AGENT_INTROSPECTION = """
<node>
  <interface name="org.bluez.Agent1">
    <method name="Release"/>
    <method name="RequestConfirmation">
      <arg type="o" name="device" direction="in"/>
      <arg type="u" name="passkey" direction="in"/>
    </method>
    <method name="RequestPasskey">
      <arg type="o" name="device" direction="in"/>
      <arg type="u" name="passkey" direction="out"/>
    </method>
    <method name="DisplayPasskey">
      <arg type="o" name="device" direction="in"/>
      <arg type="u" name="passkey" direction="in"/>
      <arg type="q" name="entered" direction="in"/>
    </method>
    <method name="RequestPinCode">
      <arg type="o" name="device" direction="in"/>
      <arg type="s" name="pincode" direction="out"/>
    </method>
    <method name="DisplayPinCode">
      <arg type="o" name="device" direction="in"/>
      <arg type="s" name="pincode" direction="in"/>
    </method>
    <method name="RequestAuthorization">
      <arg type="o" name="device" direction="in"/>
    </method>
    <method name="AuthorizeService">
      <arg type="o" name="device" direction="in"/>
      <arg type="s" name="uuid" direction="in"/>
    </method>
    <method name="Cancel"/>
  </interface>
</node>
"""

class CarbonBluetoothManager:
    def __init__(self):
        self.bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.loop = GLib.MainLoop()
        self.devices = {}
        self.path_to_mac = {}
        self.mac_to_path = {}
        self.adapter_path = None
        self.agent_reg_id = None
        self.agent_registered = False

        self.passkey_event = threading.Event()
        self.passkey_confirmed = False

        self.lock = threading.Lock()
        self.is_scanning = False
        self.auto_switch_audio = False

        GLib.timeout_add_seconds(3, self.prune_stale_devices)

    def get_mac_for_path(self, path):
        return self.path_to_mac.get(str(path), "")

    def wait_for_passkey_response(self, timeout=35.0):
        self.passkey_event.clear()
        self.passkey_confirmed = False
        self.passkey_event.wait(timeout=timeout)
        return self.passkey_confirmed

    def resolve_passkey(self, confirmed):
        self.passkey_confirmed = confirmed
        self.passkey_event.set()

    def handle_agent_method_call(self, connection, sender, object_path, interface_name, method_name, parameters, invocation, user_data=None):
        if method_name == "RequestConfirmation":
            device_path, passkey = parameters.unpack()
            mac = self.get_mac_for_path(device_path)
            dev_name = self.devices.get(device_path, {}).get("name", mac)
            emit_event({
                "type": "passkey_request",
                "mac": mac,
                "name": dev_name,
                "passkey": f"{int(passkey):06d}"
            })
            confirmed = self.wait_for_passkey_response()
            if confirmed:
                invocation.return_value(None)
            else:
                invocation.return_dbus_error("org.bluez.Error.Rejected", "Passkey pairing rejected by user")
        elif method_name == "RequestPasskey":
            invocation.return_value(GLib.Variant('(u)', (0,)))
        elif method_name == "DisplayPasskey":
            params = parameters.unpack()
            device_path = params[0]
            passkey = params[1]
            mac = self.get_mac_for_path(device_path)
            dev_name = self.devices.get(device_path, {}).get("name", mac)
            emit_event({
                "type": "passkey_request",
                "mac": mac,
                "name": dev_name,
                "passkey": f"{int(passkey):06d}"
            })
            invocation.return_value(None)
        elif method_name == "RequestPinCode":
            invocation.return_value(GLib.Variant('(s)', ("0000",)))
        elif method_name == "Cancel":
            emit_event({"type": "passkey_cancelled"})
            invocation.return_value(None)
        else:
            invocation.return_value(None)

    def setup(self):
        # Register Agent object
        try:
            node_info = Gio.DBusNodeInfo.new_for_xml(AGENT_INTROSPECTION)
            interface_info = node_info.interfaces[0]
            self.agent_reg_id = self.bus.register_object(
                AGENT_PATH,
                interface_info,
                self.handle_agent_method_call,
                None,
                None
            )
            self.bus.call_sync(
                BLUEZ_SERVICE,
                "/org/bluez",
                AGENT_MGR_IFACE,
                "RegisterAgent",
                GLib.Variant("(os)", (AGENT_PATH, "KeyboardDisplay")),
                None,
                Gio.DBusCallFlags.NONE,
                -1,
                None
            )
            self.bus.call_sync(
                BLUEZ_SERVICE,
                "/org/bluez",
                AGENT_MGR_IFACE,
                "RequestDefaultAgent",
                GLib.Variant("(o)", (AGENT_PATH,)),
                None,
                Gio.DBusCallFlags.NONE,
                -1,
                None
            )
            self.agent_registered = True
        except Exception:
            pass

        # Subscribe to D-Bus signals
        self.bus.signal_subscribe(
            BLUEZ_SERVICE,
            "org.freedesktop.DBus.ObjectManager",
            "InterfacesAdded",
            None,
            None,
            Gio.DBusSignalFlags.NONE,
            self.on_interfaces_added_cb,
            None
        )
        self.bus.signal_subscribe(
            BLUEZ_SERVICE,
            "org.freedesktop.DBus.ObjectManager",
            "InterfacesRemoved",
            None,
            None,
            Gio.DBusSignalFlags.NONE,
            self.on_interfaces_removed_cb,
            None
        )
        self.bus.signal_subscribe(
            BLUEZ_SERVICE,
            "org.freedesktop.DBus.Properties",
            "PropertiesChanged",
            None,
            None,
            Gio.DBusSignalFlags.NONE,
            self.on_properties_changed_cb,
            None
        )

        try:
            res = self.bus.call_sync(
                BLUEZ_SERVICE,
                "/",
                "org.freedesktop.DBus.ObjectManager",
                "GetManagedObjects",
                None,
                None,
                Gio.DBusCallFlags.NONE,
                -1,
                None
            )
            objects = res.unpack()[0]
        except Exception:
            emit_event({"type": "adapter_state", "available": False, "powered": False})
            return

        for path, ifaces in objects.items():
            if ADAPTER_IFACE in ifaces:
                self.adapter_path = path
                break

        if not self.adapter_path:
            emit_event({"type": "adapter_state", "available": False, "powered": False})
            return

        powered = False
        try:
            res_p = self.bus.call_sync(
                BLUEZ_SERVICE,
                self.adapter_path,
                "org.freedesktop.DBus.Properties",
                "Get",
                GLib.Variant("(ss)", (ADAPTER_IFACE, "Powered")),
                None,
                Gio.DBusCallFlags.NONE,
                -1,
                None
            )
            powered = bool(res_p.unpack()[0])
        except Exception:
            pass

        emit_event({"type": "adapter_state", "available": True, "powered": powered})

        for path, ifaces in objects.items():
            if DEVICE_IFACE in ifaces:
                self.parse_and_store_device(path, ifaces[DEVICE_IFACE], ifaces.get(BATTERY_IFACE))

        if powered:
            self.start_discovery()

        self.emit_devices()

    def start_discovery(self):
        if not self.adapter_path or self.is_scanning:
            return
        try:
            self.bus.call_sync(
                BLUEZ_SERVICE,
                self.adapter_path,
                ADAPTER_IFACE,
                "StartDiscovery",
                None,
                None,
                Gio.DBusCallFlags.NONE,
                -1,
                None
            )
            self.is_scanning = True
            emit_event({"type": "scan_state", "scanning": True})
        except Exception:
            pass

    def stop_discovery(self):
        if not self.adapter_path or not self.is_scanning:
            return
        try:
            self.bus.call_sync(
                BLUEZ_SERVICE,
                self.adapter_path,
                ADAPTER_IFACE,
                "StopDiscovery",
                None,
                None,
                Gio.DBusCallFlags.NONE,
                -1,
                None
            )
            self.is_scanning = False
            emit_event({"type": "scan_state", "scanning": False})
        except Exception:
            pass

    def parse_and_store_device(self, path, dev_props, bat_props=None):
        path = str(path)
        mac = str(dev_props.get("Address", ""))
        if not mac:
            return

        name = str(dev_props.get("Name", dev_props.get("Alias", mac)))
        paired = bool(dev_props.get("Paired", False))
        connected = bool(dev_props.get("Connected", False))
        icon = str(dev_props.get("Icon", ""))
        dev_class = int(dev_props.get("Class", 0))
        rssi = int(dev_props.get("RSSI")) if "RSSI" in dev_props else None

        battery = -1
        if bat_props and "Percentage" in bat_props:
            battery = int(bat_props["Percentage"])
        elif path in self.devices and self.devices[path].get("battery", -1) >= 0:
            battery = self.devices[path]["battery"]

        dev_type = resolve_device_type(icon, dev_class, name)
        angle = mac_to_angle(mac)
        radius = compute_orbit_radius(paired, rssi)

        with self.lock:
            self.path_to_mac[path] = mac
            self.mac_to_path[mac] = path
            self.devices[path] = {
                "mac": mac,
                "name": name,
                "paired": paired,
                "connected": connected,
                "deviceType": dev_type,
                "battery": battery,
                "rssi": rssi,
                "angleDeg": angle,
                "baseAngle": angle,
                "orbitRadius": radius,
                "orbRadius": 16,
                "lastSeen": time.time()
            }

    def emit_devices(self):
        with self.lock:
            dev_list = [dict(d) for d in self.devices.values()]

        paired = [d for d in dev_list if d.get("paired")]
        unpaired = [d for d in dev_list if not d.get("paired")]

        def relax_group(items, min_sep):
            if len(items) <= 1:
                return
            items.sort(key=lambda x: (x.get("baseAngle", x["angleDeg"]), x["mac"]))
            n = len(items)
            for it in items:
                it["angleDeg"] = it.get("baseAngle", it["angleDeg"])
            eff_sep = min(min_sep, 360.0 / n)
            for _ in range(12):
                for i in range(n):
                    j = (i + 1) % n
                    a1 = items[i]["angleDeg"]
                    a2 = items[j]["angleDeg"]
                    diff = (a2 - a1) % 360.0
                    if 0 < diff < eff_sep:
                        push = (eff_sep - diff) / 2.0
                        items[i]["angleDeg"] = round((a1 - push) % 360.0, 1)
                        items[j]["angleDeg"] = round((a2 + push) % 360.0, 1)

        relax_group(paired, 28.0)
        relax_group(unpaired, 22.0)

        emit_event({"type": "devices", "list": dev_list})

    def prune_stale_devices(self):
        now = time.time()
        removed = False
        with self.lock:
            to_del = []
            for path, dev in self.devices.items():
                if not dev["paired"] and not dev["connected"]:
                    if now - dev["lastSeen"] > STALE_TIMEOUT_SEC:
                        to_del.append(path)
            for path in to_del:
                del self.devices[path]
                removed = True

        if removed:
            self.emit_devices()
        return True

    def on_interfaces_added_cb(self, connection, sender, path, iface, signal, params, user_data=None):
        try:
            obj_path, ifaces = params.unpack()
            obj_path = str(obj_path)
            if DEVICE_IFACE in ifaces:
                self.parse_and_store_device(obj_path, ifaces[DEVICE_IFACE], ifaces.get(BATTERY_IFACE))
                self.emit_devices()
        except Exception:
            pass

    def on_interfaces_removed_cb(self, connection, sender, path, iface, signal, params, user_data=None):
        try:
            obj_path, ifaces = params.unpack()
            obj_path = str(obj_path)
            with self.lock:
                if obj_path in self.devices:
                    mac = self.devices[obj_path]["mac"]
                    del self.devices[obj_path]
                    self.path_to_mac.pop(obj_path, None)
                    self.mac_to_path.pop(mac, None)
                    self.emit_devices()
        except Exception:
            pass

    def on_properties_changed_cb(self, connection, sender, path, iface, signal, params, user_data=None):
        try:
            iface_name, changed, invalidated = params.unpack()
            path = str(path)

            if iface_name == ADAPTER_IFACE:
                if "Powered" in changed:
                    p = bool(changed["Powered"])
                    emit_event({"type": "adapter_state", "available": True, "powered": p})
                    if p:
                        self.start_discovery()
                    else:
                        self.stop_discovery()
                if "Discovering" in changed:
                    d = bool(changed["Discovering"])
                    self.is_scanning = d
                    emit_event({"type": "scan_state", "scanning": d})

            elif iface_name == DEVICE_IFACE:
                with self.lock:
                    if path in self.devices:
                        dev = self.devices[path]
                        dev["lastSeen"] = time.time()
                        if "Connected" in changed:
                            dev["connected"] = bool(changed["Connected"])
                        if "Paired" in changed:
                            dev["paired"] = bool(changed["Paired"])
                            dev["orbitRadius"] = compute_orbit_radius(dev["paired"], dev["rssi"])
                        if "Name" in changed:
                            dev["name"] = str(changed["Name"])
                        if "Icon" in changed:
                            dev["deviceType"] = resolve_device_type(str(changed["Icon"]), 0, dev["name"])
                        if "RSSI" in changed:
                            dev["rssi"] = int(changed["RSSI"])
                            if not dev["paired"]:
                                dev["orbitRadius"] = compute_orbit_radius(False, dev["rssi"])
                self.emit_devices()

            elif iface_name == BATTERY_IFACE:
                with self.lock:
                    if path in self.devices and "Percentage" in changed:
                        self.devices[path]["battery"] = int(changed["Percentage"])
                self.emit_devices()
        except Exception:
            pass

    def execute_action(self, cmd):
        action = cmd.get("action")
        mac = cmd.get("mac")

        if action == "power_on":
            if self.adapter_path:
                try:
                    self.bus.call_sync(
                        BLUEZ_SERVICE,
                        self.adapter_path,
                        "org.freedesktop.DBus.Properties",
                        "Set",
                        GLib.Variant("(ssv)", (ADAPTER_IFACE, "Powered", GLib.Variant("b", True))),
                        None,
                        Gio.DBusCallFlags.NONE,
                        -1,
                        None
                    )
                except Exception:
                    subprocess.run(["bluetoothctl", "power", "on"], check=False, timeout=3)
                self.start_discovery()
            return

        if action == "confirm_passkey":
            self.resolve_passkey(True)
            return

        if action == "cancel_passkey":
            self.resolve_passkey(False)
            return

        if action == "set_auto_switch_audio":
            self.auto_switch_audio = bool(cmd.get("enabled", False))
            return

        if not mac or mac not in self.mac_to_path:
            emit_event({"type": "action_result", "action": action, "mac": mac, "success": False, "error": "device not found"})
            return

        dev_path = self.mac_to_path[mac]

        if action == "connect":
            def do_connect():
                success = False
                err_msg = ""
                try:
                    self.bus.call_sync(
                        BLUEZ_SERVICE,
                        dev_path,
                        DEVICE_IFACE,
                        "Connect",
                        None,
                        None,
                        Gio.DBusCallFlags.NONE,
                        25000,
                        None
                    )
                    success = True
                except Exception as e:
                    p = subprocess.run(["bluetoothctl", "connect", mac], capture_output=True, text=True, timeout=25)
                    if p.returncode == 0 or "successful" in p.stdout.lower():
                        success = True
                    else:
                        err_msg = str(e).split(":")[-1].strip()

                emit_event({"type": "action_result", "action": "connect", "mac": mac, "success": success, "error": err_msg})
                if success and self.auto_switch_audio:
                    with self.lock:
                        d_type = self.devices.get(dev_path, {}).get("deviceType", "")
                    if d_type in ("headphones", "speaker"):
                        threading.Timer(1.5, set_default_pipewire_sink, args=[mac]).start()

            threading.Thread(target=do_connect, daemon=True).start()

        elif action == "disconnect":
            def do_disconnect():
                success = False
                err_msg = ""
                try:
                    self.bus.call_sync(
                        BLUEZ_SERVICE,
                        dev_path,
                        DEVICE_IFACE,
                        "Disconnect",
                        None,
                        None,
                        Gio.DBusCallFlags.NONE,
                        10000,
                        None
                    )
                    success = True
                except Exception as e:
                    p = subprocess.run(["bluetoothctl", "disconnect", mac], capture_output=True, text=True, timeout=10)
                    if p.returncode == 0 or "successful" in p.stdout.lower():
                        success = True
                    else:
                        err_msg = str(e).split(":")[-1].strip()

                emit_event({"type": "action_result", "action": "disconnect", "mac": mac, "success": success, "error": err_msg})

            threading.Thread(target=do_disconnect, daemon=True).start()

        elif action == "pair":
            def do_pair():
                success = False
                err_msg = ""
                try:
                    self.bus.call_sync(
                        BLUEZ_SERVICE,
                        dev_path,
                        "org.freedesktop.DBus.Properties",
                        "Set",
                        GLib.Variant("(ssv)", (DEVICE_IFACE, "Trusted", GLib.Variant("b", True))),
                        None,
                        Gio.DBusCallFlags.NONE,
                        -1,
                        None
                    )
                    self.bus.call_sync(
                        BLUEZ_SERVICE,
                        dev_path,
                        DEVICE_IFACE,
                        "Pair",
                        None,
                        None,
                        Gio.DBusCallFlags.NONE,
                        35000,
                        None
                    )
                    self.bus.call_sync(
                        BLUEZ_SERVICE,
                        dev_path,
                        DEVICE_IFACE,
                        "Connect",
                        None,
                        None,
                        Gio.DBusCallFlags.NONE,
                        25000,
                        None
                    )
                    success = True
                except Exception as e:
                    p = subprocess.run(["bluetoothctl", "pair", mac], capture_output=True, text=True, timeout=35)
                    if p.returncode == 0 or "successful" in p.stdout.lower():
                        subprocess.run(["bluetoothctl", "connect", mac], check=False, timeout=20)
                        success = True
                    else:
                        err_msg = str(e).split(":")[-1].strip()

                emit_event({"type": "action_result", "action": "pair", "mac": mac, "success": success, "error": err_msg})
                if success and self.auto_switch_audio:
                    with self.lock:
                        d_type = self.devices.get(dev_path, {}).get("deviceType", "")
                    if d_type in ("headphones", "speaker"):
                        threading.Timer(1.5, set_default_pipewire_sink, args=[mac]).start()

            threading.Thread(target=do_pair, daemon=True).start()

        elif action == "forget":
            def do_forget():
                success = False
                err_msg = ""
                try:
                    if self.adapter_path:
                        self.bus.call_sync(
                            BLUEZ_SERVICE,
                            self.adapter_path,
                            ADAPTER_IFACE,
                            "RemoveDevice",
                            GLib.Variant("(o)", (dev_path,)),
                            None,
                            Gio.DBusCallFlags.NONE,
                            -1,
                            None
                        )
                        success = True
                except Exception as e:
                    p = subprocess.run(["bluetoothctl", "remove", mac], capture_output=True, text=True, timeout=10)
                    if p.returncode == 0:
                        success = True
                    else:
                        err_msg = str(e).split(":")[-1].strip()

                emit_event({"type": "action_result", "action": "forget", "mac": mac, "success": success, "error": err_msg})

            threading.Thread(target=do_forget, daemon=True).start()

def stdin_reader_thread(manager):
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            cmd = json.loads(line)
            if cmd.get("action") == "stop":
                break
            GLib.idle_add(manager.execute_action, cmd)
        except Exception:
            pass
    GLib.idle_add(manager.loop.quit)

def main():
    manager = CarbonBluetoothManager()

    def handle_exit(*args):
        manager.stop_discovery()
        try:
            if manager.agent_registered:
                manager.bus.call_sync(
                    BLUEZ_SERVICE,
                    "/org/bluez",
                    AGENT_MGR_IFACE,
                    "UnregisterAgent",
                    GLib.Variant("(o)", (AGENT_PATH,)),
                    None,
                    Gio.DBusCallFlags.NONE,
                    -1,
                    None
                )
        except Exception:
            pass
        os._exit(0)

    signal.signal(signal.SIGINT, handle_exit)
    signal.signal(signal.SIGTERM, handle_exit)

    manager.setup()

    t = threading.Thread(target=stdin_reader_thread, args=(manager,), daemon=True)
    t.start()

    try:
        manager.loop.run()
    finally:
        handle_exit()

if __name__ == "__main__":
    main()
