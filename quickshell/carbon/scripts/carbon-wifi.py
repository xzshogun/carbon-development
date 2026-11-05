#!/usr/bin/env python3
"""
carbon-wifi.py

Secure event-driven Wi-Fi connection manager for Carbon Shell.
- Reads JSON requests from stdin:
    {"action": "connect", "ssid": "...", "password": "...", "saved": bool}
    {"action": "disconnect", "ssid": "..."}
    {"action": "forget", "ssid": "..."}
    {"action": "launch_editor"}
    {"action": "verify", "ssid": "..."}
    {"action": "stop"}
- Secure credential handling:
    NEVER places password in CLI arguments (/proc/<pid>/cmdline).
    Password is fed via stdin directly to nmcli --ask.
- Post-connection verification:
    Validates against `nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status`.
- Error mapping & bad profile cleanup:
    Auth failure / secrets required -> "wrong_password", deletes newly created bad profile.
    Timeout (20s) -> "no_response", deletes newly created bad profile if not saved.
    Network not found -> "network_not_found".
- Emits JSON responses to stdout.
"""

import sys
import os
import json
import time
import subprocess
import threading

def emit_event(data):
    try:
        sys.stdout.write(json.dumps(data) + "\n")
        sys.stdout.flush()
    except Exception:
        pass

def is_wifi_connected(target_ssid):
    try:
        res = subprocess.run(
            ['nmcli', '-t', '-f', 'DEVICE,TYPE,STATE,CONNECTION', 'dev', 'status'],
            capture_output=True, text=True, timeout=5
        )
        for line in res.stdout.splitlines():
            parts = line.strip().split(':')
            if len(parts) >= 4 and parts[1] == 'wifi' and parts[2] == 'connected':
                if parts[3] == target_ssid:
                    return True
    except Exception:
        pass
    return False

def handle_connect(ssid, password=None, is_saved=False):
    if not ssid:
        emit_event({"event": "result", "action": "connect", "status": "error", "error": "network_not_found", "ssid": ""})
        return

    # Check if already connected
    if is_wifi_connected(ssid):
        emit_event({"event": "result", "action": "connect", "status": "success", "ssid": ssid})
        return

    stdout_str = ""
    stderr_str = ""
    ret_code = 0

    try:
        if is_saved and (not password or len(password) == 0):
            # Saved network: nmcli connection up id "<SSID>"
            proc = subprocess.run(
                ['nmcli', '-w', '20', 'connection', 'up', 'id', ssid],
                capture_output=True, text=True, timeout=22
            )
            ret_code = proc.returncode
            stdout_str = proc.stdout
            stderr_str = proc.stderr
        elif not password or len(password) == 0:
            # Open network: nmcli dev wifi connect "<SSID>"
            proc = subprocess.run(
                ['nmcli', '-w', '20', 'dev', 'wifi', 'connect', ssid],
                capture_output=True, text=True, timeout=22
            )
            ret_code = proc.returncode
            stdout_str = proc.stdout
            stderr_str = proc.stderr
        else:
            # Secured & new: feed password via stdin to nmcli --ask
            proc = subprocess.Popen(
                ['nmcli', '-w', '20', '--ask', 'dev', 'wifi', 'connect', ssid],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            stdout_str, stderr_str = proc.communicate(input=password + "\n", timeout=22)
            ret_code = proc.returncode

    except subprocess.TimeoutExpired:
        ret_code = 3
        stderr_str = "Timeout 20 sec expired"
    except Exception as e:
        ret_code = -1
        stderr_str = str(e)

    # Verification: check device status regardless of exit code
    time.sleep(0.5)
    if is_wifi_connected(ssid):
        emit_event({"event": "result", "action": "connect", "status": "success", "ssid": ssid})
        return

    # Map error
    out_all = (stdout_str + "\n" + stderr_str).strip()
    err_type = "failed"

    if "Secrets were required, but not provided" in out_all:
        err_type = "wrong_password"
    elif stdout_str.count("Password (") >= 2 or ("Passwords or encryption keys are required" in stdout_str and ret_code != 0):
        err_type = "wrong_password"
    elif "No network with SSID" in out_all or "not found" in stderr_str.lower():
        err_type = "network_not_found"
    elif "timeout" in out_all.lower() or ret_code == 3:
        err_type = "no_response"
    elif "802-11-wireless-security" in out_all or "auth" in out_all.lower() or "secret" in out_all.lower():
        err_type = "wrong_password"

    # Delete newly created bad profile if not saved
    if not is_saved:
        try:
            subprocess.run(['nmcli', 'connection', 'delete', 'id', ssid], capture_output=True, timeout=5)
        except Exception:
            pass

    emit_event({
        "event": "result",
        "action": "connect",
        "status": "error",
        "error": err_type,
        "detail": out_all,
        "ssid": ssid
    })

def handle_disconnect(ssid):
    try:
        subprocess.run(['nmcli', 'connection', 'down', 'id', ssid], capture_output=True, text=True, timeout=10)
    except Exception:
        pass
    emit_event({"event": "result", "action": "disconnect", "status": "success", "ssid": ssid})

def handle_forget(ssid):
    try:
        subprocess.run(['nmcli', 'connection', 'delete', 'id', ssid], capture_output=True, text=True, timeout=10)
    except Exception:
        pass
    emit_event({"event": "result", "action": "forget", "status": "success", "ssid": ssid})

def handle_launch_editor():
    try:
        subprocess.Popen(['nm-connection-editor'])
        emit_event({"event": "result", "action": "launch_editor", "status": "success"})
    except Exception as e:
        emit_event({"event": "result", "action": "launch_editor", "status": "error", "detail": str(e)})

def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            cmd = json.loads(line)
        except Exception:
            continue

        action = cmd.get("action", "")
        if action == "stop":
            break
        elif action == "connect":
            ssid = cmd.get("ssid", "")
            password = cmd.get("password", "")
            saved = bool(cmd.get("saved", False))
            threading.Thread(target=handle_connect, args=(ssid, password, saved), daemon=True).start()
        elif action == "disconnect":
            ssid = cmd.get("ssid", "")
            threading.Thread(target=handle_disconnect, args=(ssid,), daemon=True).start()
        elif action == "forget":
            ssid = cmd.get("ssid", "")
            threading.Thread(target=handle_forget, args=(ssid,), daemon=True).start()
        elif action == "launch_editor":
            threading.Thread(target=handle_launch_editor, daemon=True).start()
        elif action == "verify":
            ssid = cmd.get("ssid", "")
            conn = is_wifi_connected(ssid)
            emit_event({"event": "verify", "ssid": ssid, "connected": conn})

if __name__ == "__main__":
    main()
