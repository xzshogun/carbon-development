pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

/**
 * HudService: Centralized state manager for the Dynamic Island Morphing HUD.
 * Detects volume, brightness, track change, and battery status events,
 * maintaining a unified state machine with auto-dismiss timers.
 */
Singleton {
    id: root

    property bool active: false
    property string mode: "volume" // "volume" | "brightness" | "track" | "battery"
    property real value: 0.0        // 0.0 to 1.0
    property string text: ""        // e.g. "65%", "MUTED"
    property string title: ""       // e.g. "Do I Wanna Know?"
    property string subText: ""     // e.g. "Arctic Monkeys"
    property bool muted: false
    property string icon: ""
    property string artUrl: ""

    // Auto-dismiss timer
    Timer {
        id: hideTimer
        interval: 2200
        onTriggered: root.active = false
    }

    function trigger(newMode, newVal, newText, newTitle, newSubText, isMuted, newIcon, newArt, timeoutMs) {
        root.mode = newMode
        root.value = Math.max(0, Math.min(1.0, newVal || 0.0))
        root.text = newText || ""
        root.title = newTitle || ""
        root.subText = newSubText || ""
        root.muted = isMuted || false
        root.icon = newIcon || ""
        root.artUrl = newArt || ""
        root.active = true

        hideTimer.interval = timeoutMs || 2200
        hideTimer.restart()
    }

    function dismiss() {
        hideTimer.stop()
        root.active = false
    }

    /* ── 1. Audio Sink (Pipewire) Monitoring ─────────────────────────── */
    readonly property var sink: Pipewire.defaultAudioSink
    property real lastVolume: -1
    property bool lastMuted: false

    function getVolumeIcon(vol, isMuted) {
        if (isMuted || vol <= 0.01) return "volume_off"
        if (vol < 0.35) return "volume_mute"
        if (vol < 0.70) return "volume_down"
        return "volume_up"
    }

    Connections {
        target: root.enabled && root.sink ? root.sink.audio : null
        function onVolumeChanged() {
            if (!root.sink || !root.sink.audio) return
            const v = root.sink.audio.volume
            const m = root.sink.audio.muted
            if (root.lastVolume >= 0 && Math.abs(v - root.lastVolume) > 0.005) {
                root.trigger(
                    "volume",
                    v,
                    m ? "MUTED" : Math.round(v * 100) + "%",
                    "Volume",
                    "",
                    m,
                    root.getVolumeIcon(v, m),
                    "",
                    2200
                )
            }
            root.lastVolume = v
        }
        function onMutedChanged() {
            if (!root.sink || !root.sink.audio) return
            const v = root.sink.audio.volume
            const m = root.sink.audio.muted
            if (root.lastVolume >= 0 && m !== root.lastMuted) {
                root.trigger(
                    "volume",
                    v,
                    m ? "MUTED" : Math.round(v * 100) + "%",
                    "Volume",
                    "",
                    m,
                    root.getVolumeIcon(v, m),
                    "",
                    2200
                )
            }
            root.lastMuted = m
        }
    }

    /* ── 2. Brightness Monitoring ─────────────────────────────────────── */
    property bool enabled: false
    property int lastBrightnessPct: -1

    Process {
        id: brightPoller
        command: [
            "sh", "-c",
            "brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4 | tr -d '%'; " +
            "exec udevadm monitor --subsystem-match=backlight --udev 2>/dev/null | while read -r line; do " +
            "  case \"$line\" in *change*) brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4 | tr -d '%';; esac; " +
            "done"
        ]
        running: root.enabled
        stdout: SplitParser {
            onRead: line => {
                const pct = parseInt(line.trim(), 10)
                if (isNaN(pct)) return
                if (root.lastBrightnessPct >= 0 && Math.abs(pct - root.lastBrightnessPct) >= 1) {
                    root.trigger(
                        "brightness",
                        pct / 100.0,
                        pct + "%",
                        "Brightness",
                        "",
                        false,
                        "light_mode",
                        "",
                        2200
                    )
                }
                root.lastBrightnessPct = pct
            }
        }
    }

    /* ── 3. MPRIS Track Change Monitoring ─────────────────────────────── */
    readonly property var players: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
    property var activePlayer: null
    property string lastTrackTitle: ""

    function resolveActivePlayer() {
        if (!root.players || root.players.length === 0) return null
        for (let i = 0; i < root.players.length; i++) {
            if (root.players[i].playbackState === MprisPlaybackState.Playing)
                return root.players[i]
        }
        for (let i = 0; i < root.players.length; i++) {
            if (root.players[i].playbackState === MprisPlaybackState.Paused
                && (root.players[i].trackTitle || "").length > 0)
                return root.players[i]
        }
        return root.players[0]
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.enabled
        triggeredOnStart: true
        onTriggered: {
            root.activePlayer = root.resolveActivePlayer()
            if (root.activePlayer) {
                const title = (root.activePlayer.trackTitle || "").trim()
                const artist = (root.activePlayer.trackArtist || "").trim()
                const art = (root.activePlayer.trackArtUrl || "").trim()
                const isPlaying = root.activePlayer.playbackState === MprisPlaybackState.Playing

                if (title.length > 0 && title !== root.lastTrackTitle && isPlaying && root.lastTrackTitle !== "") {
                    root.trigger(
                        "track",
                        1.0,
                        "Now Playing",
                        title,
                        artist,
                        false,
                        "music_note",
                        art,
                        3400
                    )
                }
                root.lastTrackTitle = title
            }
        }
    }

    /* ── 4. UPower Battery / Charging Monitoring ─────────────────────── */
    readonly property var displayDevice: UPower.displayDevice
    property bool lastCharging: false
    property bool initialBatterySeen: false

    Connections {
        target: root.enabled && root.displayDevice ? root.displayDevice : null
        function onStateChanged() {
            if (!root.displayDevice) return
            const st = root.displayDevice.state
            const ch = (st === UPowerDeviceState.Charging)
            const pct = Math.round((root.displayDevice.percentage || 0) * 100)
            if (root.initialBatterySeen && ch !== root.lastCharging) {
                root.trigger(
                    "battery",
                    (root.displayDevice.percentage || 0),
                    pct + "%",
                    ch ? "Charger Connected" : "On Battery Power",
                    ch ? "Charging in progress" : (pct + "% remaining"),
                    false,
                    ch ? "battery_charging_full" : "battery_full",
                    "",
                    2800
                )
            }
            root.lastCharging = ch
            root.initialBatterySeen = true
        }
    }
}
