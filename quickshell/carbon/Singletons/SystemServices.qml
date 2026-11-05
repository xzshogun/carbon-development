pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "."

Singleton {
    id: root

    property var cavaLevels: [0, 0, 0, 0, 0]
    property int cavaActiveClients: 0
    readonly property string cavaConfPath: (Quickshell.env("HOME") || "") + "/.config/hypr/cava-island.conf"

    signal brightnessSnapshotReady(real value, string errorString)
    signal brightnessSetFinished(real value, bool success, string errorString)
    signal volumeSnapshotReady(real value, bool muted, string errorString)
    signal volumeSetFinished(real value, bool success, string errorString)
    signal systemStatsReady(real cpuUsage, real ramUsage, string errorString)
    signal tlpStateReady(bool available, string profile, string output, string errorString)
    signal tlpSetFinished(bool success, int exitCode, string output, string errorString)
    signal hyprlandSnapshotReady(string requestId, string subject, string payloadJson, string errorString)
    signal wallpaperThumbnailFinished(string sourcePath, string finishedCachePath, bool cacheAvailable, bool updated, string errorString)

    property bool cavaShouldRun: false

    Timer {
        id: cavaStopGraceTimer
        interval: 2500
        repeat: false
        onTriggered: {
            if (root.cavaActiveClients <= 0) {
                root.cavaShouldRun = false;
            }
        }
    }

    onCavaActiveClientsChanged: {
        if (root.cavaActiveClients > 0) {
            cavaStopGraceTimer.stop();
            root.cavaShouldRun = true;
        } else {
            cavaStopGraceTimer.restart();
        }
    }

    function setCavaClientActive(clientIdOrActive, active) {
        if (typeof clientIdOrActive === "boolean") {
            if (clientIdOrActive) root.cavaActiveClients = Math.max(1, root.cavaActiveClients + 1);
            else root.cavaActiveClients = Math.max(0, root.cavaActiveClients - 1);
        } else {
            if (active) root.cavaActiveClients = Math.max(1, root.cavaActiveClients + 1);
            else root.cavaActiveClients = Math.max(0, root.cavaActiveClients - 1);
        }
    }

    Process {
        id: cavaProc
        command: ["cava", "-p", root.cavaConfPath]
        running: root.cavaShouldRun
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var trimmed = line.trim();
                if (trimmed.length === 0) return;
                var parts = trimmed.split(";");
                if (parts.length >= 4) {
                    var arr = [];
                    for (var i = 0; i < Math.min(5, parts.length); i++) {
                        var val = parseFloat(parts[i]) || 0;
                        arr.push(Math.max(0.0, Math.min(1.0, val / 100.0)));
                    }
                    while (arr.length < 5) arr.push(0.0);
                    root.cavaLevels = arr;
                }
            }
        }
    }

    // --- Brightness ---
    function requestBrightness() {
        brightnessProc.running = false;
        brightnessProc.running = true;
    }

    Process {
        id: brightnessProc
        command: ["bash", "-c", "brightnessctl -m 2>/dev/null | head -n1 | cut -d',' -f4 | tr -d '%' || echo '100'"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text && text.trim().length > 0) {
                    var val = parseFloat(text.trim()) / 100.0;
                    root.brightnessSnapshotReady(isNaN(val) ? 1.0 : val, "");
                }
            }
        }
    }

    function setBrightness(value) {
        var pct = Math.round(Math.max(0, Math.min(1, value)) * 100);
        var p = setBrightnessComponent.createObject(root, { "targetVal": value, "pct": pct });
        if (p) p.start();
    }

    Component {
        id: setBrightnessComponent
        Process {
            id: proc
            property real targetVal: 1.0
            property int pct: 100
            command: ["brightnessctl", "set", pct + "%"]
            onExited: (code, status) => {
                root.brightnessSetFinished(targetVal, code === 0, code === 0 ? "" : "Failed to set brightness");
                proc.destroy();
            }
            function start() { proc.running = true; }
        }
    }

    // --- Volume ---
    function requestVolume() {
        if (typeof SysBackend !== "undefined" && SysBackend && SysBackend.currentVolume >= 0) {
            root.volumeSnapshotReady(SysBackend.currentVolume, SysBackend.isMuted, "");
        }
        volumeProc.running = false;
        volumeProc.running = true;
    }

    Process {
        id: volumeProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo 'Volume: 0.50'"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text && text.trim().length > 0) {
                    var t = text.trim();
                    var isMuted = t.indexOf("[MUTED]") !== -1;
                    var match = t.match(/([0-9]+(\.[0-9]+)?)/);
                    var val = match ? parseFloat(match[1]) : 0.5;
                    if (val > 1.0) val = val / 100.0;
                    root.volumeSnapshotReady(val, isMuted, "");
                }
            }
        }
    }

    function setVolume(value) {
        var clamped = Math.max(0, Math.min(1.5, value));
        if (typeof SysBackend !== "undefined" && SysBackend && SysBackend.sink && SysBackend.sink.audio) {
            try {
                SysBackend.sink.audio.muted = false;
                SysBackend.sink.audio.volume = clamped;
            } catch (e) {}
        }
        var p = setVolumeComponent.createObject(root, { "targetVal": clamped });
        if (p) p.start();
    }

    Component {
        id: setVolumeComponent
        Process {
            id: proc
            property real targetVal: 0.5
            command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", targetVal.toFixed(2)]
            onExited: (code, status) => {
                root.volumeSetFinished(targetVal, code === 0, code === 0 ? "" : "Failed to set volume");
                proc.destroy();
            }
            function start() { proc.running = true; }
        }
    }

    // --- System Stats (CPU / RAM) ---
    function requestSystemStats() {
        statsProc.running = false;
        statsProc.running = true;
    }

    Process {
        id: statsProc
        command: ["bash", "-c", "python3 -c \"import psutil; print(f'{psutil.cpu_percent()/100.0:.2f} {psutil.virtual_memory().percent/100.0:.2f}')\" 2>/dev/null || awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf \\\"0.05 %.2f\\\\n\\\", (t-a)/t}' /proc/meminfo"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text && text.trim().length > 0) {
                    var parts = text.trim().split(/\s+/);
                    if (parts.length >= 2) {
                        var cpu = parseFloat(parts[0]);
                        var ram = parseFloat(parts[1]);
                        root.systemStatsReady(isNaN(cpu) ? 0.0 : cpu, isNaN(ram) ? 0.0 : ram, "");
                    }
                }
            }
        }
    }

    // --- Power Profiles / TLP ---
    function requestTlpState() {
        tlpStateProc.running = false;
        tlpStateProc.running = true;
    }

    Process {
        id: tlpStateProc
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || echo 'balanced'"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text && text.trim().length > 0) {
                    var profile = text.trim();
                    root.tlpStateReady(true, profile, profile, "");
                }
            }
        }
    }

    function cancelTlpApply() {
        // no-op or cancel active setter
    }

    function setTlpMode(mode, sudoPassword, ask) {
        var p = setTlpComponent.createObject(root, { "mode": mode });
        if (p) p.start();
    }

    Component {
        id: setTlpComponent
        Process {
            id: proc
            property string mode: "balanced"
            command: ["powerprofilesctl", "set", mode]
            onExited: (code, status) => {
                root.tlpSetFinished(code === 0, code, mode, code === 0 ? "" : "Failed to set power profile");
                proc.destroy();
            }
            function start() { proc.running = true; }
        }
    }

    // --- Hyprland Snapshots ---
    function requestHyprlandSnapshot(requestId, subject) {
        var p = hyprSnapshotComponent.createObject(root, {
            "requestId": requestId,
            "subject": subject
        });
        if (p) p.start();
    }

    Component {
        id: hyprSnapshotComponent
        Process {
            id: proc
            property string requestId: ""
            property string subject: ""
            property string outputData: ""
            command: ["hyprctl", "-j", subject]
            stdout: SplitParser {
                onRead: (chunk) => { proc.outputData += chunk + "\n"; }
            }
            onExited: (code, status) => {
                root.hyprlandSnapshotReady(requestId, subject, code === 0 ? outputData : "[]", code === 0 ? "" : "hyprctl exited with " + code);
                proc.destroy();
            }
            function start() {
                proc.running = true;
            }
        }
    }

    // --- Wallpaper Thumbnails ---
    function generateWallpaperThumbnail(sourcePath, cachePath, cacheDir, targetWidth, targetHeight, quality) {
        var p = thumbnailComponent.createObject(root, {
            "sourcePath": sourcePath,
            "cachePath": cachePath,
            "cacheDir": cacheDir,
            "targetWidth": targetWidth,
            "targetHeight": targetHeight,
            "quality": quality
        });
        if (p) p.start();
    }

    Component {
        id: thumbnailComponent
        Process {
            id: thumbProc
            property string sourcePath: ""
            property string cachePath: ""
            property string cacheDir: ""
            property int targetWidth: 640
            property int targetHeight: 360
            property int quality: 80

            command: [
                "bash", "-c",
                "mkdir -p \"$1\"\n" +
                "magick \"$2\" -auto-orient -resize \"${3}x${4}^\" -gravity center -extent \"${3}x${4}\" -quality \"$5\" \"$6\" 2>/dev/null || cp -f \"$2\" \"$6\" 2>/dev/null\n",
                "thumb-worker",
                cacheDir,
                sourcePath,
                String(targetWidth),
                String(targetHeight),
                String(quality),
                cachePath
            ]

            onExited: (code, status) => {
                root.wallpaperThumbnailFinished(sourcePath, cachePath, code === 0, code === 0, code === 0 ? "" : "Failed thumbnail generation");
                thumbProc.destroy();
            }

            function start() {
                thumbProc.running = true;
            }
        }
    }
}
