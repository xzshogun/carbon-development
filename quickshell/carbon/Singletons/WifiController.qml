pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "."

Singleton {
    id: root

    readonly property bool supported: true
    readonly property bool readOnly: false
    property bool available: true
    property bool enabled: true
    property bool busy: false
    property bool scanning: false

    property string currentSsid: ""
    property int currentSignal: 0
    property string currentSecurity: ""
    property string infoMessage: ""
    property string errorMessage: ""
    readonly property string unsupportedReason: ""

    readonly property string statusText: {
        if (!root.available) return "Unavailable";
        if (!root.enabled) return "Off";
        if (root.busy) return "Working...";
        if (root.currentSsid.length > 0) return root.currentSsid;
        if (root.scanning) return "Scanning...";
        return "Disconnected";
    }

    property var networks: []
    property var savedConnections: []

    function clearMessages() {
        root.infoMessage = "";
        root.errorMessage = "";
    }

    function refreshState() {
        if (!stateProc.running)
            stateProc.running = true;
    }

    function refreshNetworks(rescan) {
        if (rescan && !rescanProc.running) {
            root.scanning = true;
            rescanProc.running = true;
        } else if (!networksProc.running) {
            root.scanning = true;
            networksProc.running = true;
        }
    }

    function setEnabled(nextEnabled) {
        root.busy = true;
        clearMessages();
        var cmd = nextEnabled ? "nmcli radio wifi on" : "nmcli radio wifi off";
        var p = simpleProcComponent.createObject(root, {
            "cmd": cmd,
            "onFinishedCallback": function(success) {
                root.busy = false;
                root.enabled = nextEnabled;
                root.refreshState();
                if (nextEnabled) root.refreshNetworks(true);
            }
        });
        if (p) p.start();
    }

    function disconnectCurrent() {
        if (root.currentSsid.length === 0) return;
        root.busy = true;
        clearMessages();
        var cmd = "nmcli dev disconnect wlan0 2>/dev/null || nmcli con down id \"" + root.currentSsid + "\" 2>/dev/null";
        var p = simpleProcComponent.createObject(root, {
            "cmd": cmd,
            "onFinishedCallback": function(success) {
                root.busy = false;
                root.currentSsid = "";
                root.refreshState();
            }
        });
        if (p) p.start();
    }

    function connectToNetwork(ssid, password) {
        if (!ssid || ssid.length === 0) return;
        root.busy = true;
        clearMessages();
        var cmd = "";
        if (password && password.length > 0) {
            cmd = "nmcli dev wifi connect \"" + ssid + "\" password \"" + password.replace(/"/g, '\\"') + "\"";
        } else {
            cmd = "nmcli dev wifi connect \"" + ssid + "\" 2>/dev/null || nmcli con up id \"" + ssid + "\"";
        }

        var p = simpleProcComponent.createObject(root, {
            "cmd": cmd,
            "onFinishedCallback": function(success, stdoutText, stderrText) {
                root.busy = false;
                if (success) {
                    root.infoMessage = "Connected to " + ssid;
                    root.currentSsid = ssid;
                    root.refreshState();
                    root.refreshNetworks(false);
                } else {
                    root.errorMessage = stderrText && stderrText.length > 0 ? stderrText.trim() : "Failed to connect to " + ssid;
                    root.refreshState();
                }
            }
        });
        if (p) p.start();
    }

    Process {
        id: stateProc
        command: ["bash", "-c", "echo '===RADIO==='; nmcli radio wifi 2>/dev/null; echo '===DEV==='; nmcli -t -f TYPE,STATE,CONNECTION dev 2>/dev/null | grep '^wifi:'"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text && text.length > 0) {
                    root.parseState(text);
                }
            }
        }
    }

    Process {
        id: rescanProc
        command: ["nmcli", "dev", "wifi", "rescan"]
        onExited: {
            networksProc.running = false;
            networksProc.running = true;
        }
    }

    Process {
        id: networksProc
        command: ["bash", "-c", "echo '===SAVED==='; nmcli -t -f NAME,TYPE con show 2>/dev/null | grep -E ':802-11-wireless|:wifi'; echo '===WIFI==='; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY,BSSID dev wifi list 2>/dev/null"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text && text.length > 0) {
                    root.parseNetworks(text);
                }
            }
        }
        onExited: {
            root.scanning = false;
        }
    }

    function parseState(raw) {
        var lines = raw.split("\n");
        var section = "";
        var radioOn = true;
        var activeConn = "";
        var hasWifiDev = false;

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "===RADIO===") {
                section = "radio";
                continue;
            } else if (line === "===DEV===") {
                section = "dev";
                continue;
            }

            if (section === "radio" && line.length > 0) {
                radioOn = (line === "enabled");
            } else if (section === "dev" && line.length > 0) {
                hasWifiDev = true;
                var parts = line.split(":");
                if (parts.length >= 3 && parts[1] === "connected") {
                    activeConn = parts.slice(2).join(":");
                }
            }
        }

        root.available = hasWifiDev;
        root.enabled = radioOn;
        if (activeConn.length > 0) {
            root.currentSsid = activeConn;
        } else if (!root.busy) {
            root.currentSsid = "";
        }
    }

    function parseNetworks(raw) {
        var lines = raw.split("\n");
        var section = "";
        var savedMap = {};
        var netList = [];
        var seenSsids = {};

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "===SAVED===") {
                section = "saved";
                continue;
            } else if (line === "===WIFI===") {
                section = "wifi";
                continue;
            }

            if (section === "saved" && line.length > 0) {
                var colonIdx = line.indexOf(":");
                if (colonIdx > 0) {
                    var sName = line.substring(0, colonIdx).trim();
                    savedMap[sName] = true;
                }
            } else if (section === "wifi" && line.length > 0) {
                var cleanLine = line.replace(/\\:/g, "__COLON__");
                var parts = cleanLine.split(":");
                if (parts.length >= 5) {
                    var inUse = parts[0].trim() === "*";
                    var ssid = parts[1].replace(/__COLON__/g, ":").trim();
                    var sig = parseInt(parts[2]) || 0;
                    var sec = parts[3].trim();
                    var bssid = parts[4].replace(/__COLON__/g, ":").trim();

                    if (ssid.length === 0 || ssid === "--")
                        continue;

                    var isSaved = !!savedMap[ssid];
                    var isSecured = (sec.length > 0 && sec !== "--");

                    if (inUse) {
                        root.currentSsid = ssid;
                        root.currentSignal = sig;
                        root.currentSecurity = sec;
                    }

                    if (seenSsids[ssid]) {
                        var existing = seenSsids[ssid];
                        if (inUse) existing.connected = true;
                        if (sig > existing.signal) existing.signal = sig;
                        continue;
                    }

                    var item = {
                        "ssid": ssid,
                        "bssid": bssid,
                        "signal": sig,
                        "secure": isSecured,
                        "security": sec,
                        "type": isSecured ? (sec.toLowerCase().indexOf("wpa") !== -1 ? "wpa-psk" : "secured") : "open",
                        "savedConnection": isSaved,
                        "connected": inUse
                    };
                    seenSsids[ssid] = item;
                    netList.push(item);
                }
            }
        }

        netList.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.savedConnection !== b.savedConnection) return a.savedConnection ? -1 : 1;
            return b.signal - a.signal;
        });

        root.networks = netList;
        root.savedConnections = Object.keys(savedMap);
    }

    Component {
        id: simpleProcComponent
        Process {
            id: p
            property string cmd: ""
            property var onFinishedCallback: null
            property string outText: ""
            property string errText: ""

            command: ["bash", "-c", cmd]
            stdout: StdioCollector {
                onTextChanged: { if (text) p.outText += text; }
            }
            stderr: StdioCollector {
                onTextChanged: { if (text) p.errText += text; }
            }
            onExited: (code, status) => {
                if (p.onFinishedCallback) {
                    p.onFinishedCallback(code === 0, p.outText, p.errText);
                }
                p.destroy();
            }
            function start() { p.running = true; }
        }
    }

    Timer {
        interval: 4000
        repeat: true
        running: true
        onTriggered: {
            root.refreshState();
        }
    }

    Component.onCompleted: {
        root.refreshState();
        root.refreshNetworks(false);
    }
}
