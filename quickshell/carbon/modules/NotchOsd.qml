import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../Singletons"

/**
 * Floating Volume & Brightness Notch OSD:
 * A sleek pill-shaped HUD that slides down from behind the Notch/Pill bar
 * with Apple VisionOS frosted gradient rim, dynamic icons, and responsive spring animations.
 */
Item {
    id: root

    property string kind: "volume" // "volume" | "brightness"
    property real value: 0.0
    property bool muted: false
    property bool active: false

    implicitWidth: 220
    implicitHeight: 38
    width: implicitWidth
    height: implicitHeight

    // Hide timer: automatically closes 1.6s after last change
    Timer {
        id: hideTimer
        interval: 1600
        onTriggered: root.active = false
    }

    function trigger(newKind, newVal, isMuted) {
        root.kind = newKind
        root.value = Math.max(0, Math.min(1.0, newVal))
        root.muted = isMuted || false
        root.active = true
        hideTimer.restart()
    }

    /* ── Audio Sink Monitoring via Pipewire ────────────────────────────────── */
    readonly property var sink: Pipewire.defaultAudioSink
    property real lastVolume: -1
    property bool lastMuted: false

    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumeChanged() {
            if (!root.sink || !root.sink.audio) return
            const v = root.sink.audio.volume
            if (root.lastVolume >= 0 && Math.abs(v - root.lastVolume) > 0.005) {
                root.trigger("volume", v, root.sink.audio.muted)
            }
            root.lastVolume = v
        }
        function onMutedChanged() {
            if (!root.sink || !root.sink.audio) return
            const m = root.sink.audio.muted
            if (root.lastVolume >= 0 && m !== root.lastMuted) {
                root.trigger("volume", root.sink.audio.volume, m)
            }
            root.lastMuted = m
        }
    }

    /* ── Brightness Monitoring via /sys/class/backlight ────────────────────── */
    property int lastBrightnessPct: -1

    Process {
        id: brightPoller
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4 | tr -d '%'; exec udevadm monitor --subsystem-match=backlight --udev | while read -r line; do case \"$line\" in *change*) brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4 | tr -d '%';; esac; done"]
        running: false
        stdout: SplitParser {
            onRead: line => {
                const pct = parseInt(line.trim(), 10)
                if (isNaN(pct)) return
                if (root.lastBrightnessPct >= 0 && Math.abs(pct - root.lastBrightnessPct) >= 1) {
                    root.trigger("brightness", pct / 100.0, false)
                }
                root.lastBrightnessPct = pct
            }
        }
    }

    /* ── Visual Capsule Body with VisionOS Specular Rim ───────────────────── */
    visible: opacity > 0.001
    opacity: root.active ? 1.0 : 0.0
    scale: root.active ? 1.0 : 0.85

    transform: Translate {
        y: root.active ? 0 : -28
        Behavior on y {
            NumberAnimation {
                duration: root.active ? 340 : 220
                easing.type: root.active ? Easing.OutBack : Easing.InQuad
                easing.overshoot: 1.25
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.active ? 200 : 240
            easing.type: Easing.OutQuad
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: root.active ? 340 : 200
            easing.type: root.active ? Easing.OutBack : Easing.InQuad
            easing.overshoot: 1.25
        }
    }

    Rectangle {
        id: capsuleRim
        anchors.fill: parent
        radius: 19

        // VisionOS Specular Rim
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.55) }
            GradientStop { position: 0.35; color: Qt.alpha(Theme.accent, 0.45) }
            GradientStop { position: 0.70; color: Qt.rgba(1.0, 1.0, 1.0, 0.18) }
            GradientStop { position: 1.0; color: Qt.rgba(0.0, 0.0, 0.0, 0.40) }
        }

        // Translucent Frosted Glass Inner Body
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1.4
            radius: parent.radius - 1.4
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(0.10, 0.11, 0.16, 0.78) }
                GradientStop { position: 0.5; color: Qt.rgba(0.07, 0.08, 0.11, 0.86) }
                GradientStop { position: 1.0; color: Qt.rgba(0.05, 0.06, 0.08, 0.94) }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                // Dynamic Icon
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    font.family: Theme.fontIcon
                    font.pixelSize: 16
                    color: {
                        if (root.kind === "volume" && root.muted) return Theme.err ? Theme.err : "#f38ba8"
                        return Theme.accent ? Theme.accent : "#00F0FF"
                    }
                    text: {
                        if (root.kind === "brightness") {
                            return "light_mode"
                        } else {
                            if (root.muted || root.value <= 0.01) return "volume_off"
                            if (root.value < 0.50) return "volume_down"
                            return "volume_up"
                        }
                    }
                }

                // Smooth Progress Track
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 5
                    radius: 2.5
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
                    clip: true

                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        width: Math.max(0, Math.min(parent.width, parent.width * (root.muted ? 0 : root.value)))
                        radius: 2.5

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.muted ? (Theme.err ? Theme.err : "#f38ba8") : (Theme.accent ? Theme.accent : "#00F0FF") }
                            GradientStop { position: 1.0; color: root.muted ? (Theme.err ? Theme.err : "#f38ba8") : Qt.tint(Theme.accent ? Theme.accent : "#00F0FF", "#FFFFFF") }
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                // Percentage Text
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.Bold
                    color: root.muted ? (Theme.err ? Theme.err : "#f38ba8") : Theme.fg
                    text: root.muted ? "MUTED" : Math.round(root.value * 100) + "%"
                }
            }
        }
    }
}
