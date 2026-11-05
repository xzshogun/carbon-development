import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../Singletons"

Item {
    id: root

    implicitWidth: 260
    implicitHeight: 260

    signal toggleCenterDashboard()
    signal openLauncher()
    signal toggleMixer()

    property alias hitBox: systemHitBox

    // Orbital Radii matching the Lock Screen Bohr Model
    property real innerOrbitRadius: 52
    property real outerOrbitRadius: 92

    /* ── Date / Time Logic (ONLY TIME IN CENTER) ── */
    property var currentTime: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.currentTime = new Date()
    }

    readonly property string timeStr: {
        var h = root.currentTime.getHours()
        var m = root.currentTime.getMinutes()
        return (h < 10 ? "0" + h : h) + ":" + (m < 10 ? "0" + m : m)
    }
    readonly property string secStr: {
        var s = root.currentTime.getSeconds()
        return (s < 10 ? "0" + s : s)
    }

    /* ── Audio Pipewire ── */
    readonly property var audioSink: Pipewire.defaultAudioSink
    function stepVolume(delta) {
        if (audioSink && audioSink.audio) {
            audioSink.audio.volume = Math.max(0.0, Math.min(1.0, audioSink.audio.volume + delta))
        }
    }

    /* ── MPRIS Control ── */
    readonly property var mprisPlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    function togglePlayPause() {
        if (mprisPlayer && mprisPlayer.canControl) {
            mprisPlayer.playPause()
        }
    }

    /* ── Hitbox Item for Window Region Mask ── */
    Item {
        id: systemHitBox
        anchors.centerIn: parent
        width: root.outerOrbitRadius * 2 + 50
        height: root.outerOrbitRadius * 2 + 50
    }

    /* ── Smooth Continuous Independent Revolutions (Bohr Atom Dynamics) ───── */
    FrameAnimation {
        running: root.visible && root.opacity > 0.01
        onTriggered: {
            innerOrbitGroup.rotation += frameTime * (360.0 / 5.8)
            outerOrbitGroup.rotation -= frameTime * (360.0 / 9.4)
        }
    }

    /* ── Main Atom Container Centered at (130, 130) ───────────────────────── */
    Item {
        id: container
        anchors.centerIn: parent
        width: 1
        height: 1


        // Central Clock Core Item (Static porcelain disc with glowing time)
        Item {
            id: centerTimeNode
            anchors.centerIn: parent
            width: 72
            height: 72

            // Static ambient background glow
            Rectangle {
                id: centerGlow
                anchors.centerIn: parent
                width: 66
                height: 66
                radius: 33
                color: Theme.accent ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20) : Qt.rgba(0, 0.94, 1, 0.20)
                opacity: 0.25
            }

            // Dark Porcelain Glass Disc
            Rectangle {
                id: centerDisc
                anchors.centerIn: parent
                width: 64
                height: 64
                radius: 32
                color: Theme.isDark ? "#0e1015" : "#f5f7fa"
                border.color: centerMouse.containsMouse ? Theme.accent : Theme.outline
                border.width: centerMouse.containsMouse ? 1.8 : 1.2

                scale: centerMouse.containsMouse ? 1.06 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                }
                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }

                // Subtle inner radial tint
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.accent
                    opacity: centerMouse.containsMouse ? 0.12 : 0.04
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                // ONLY TIME DISPLAY (No seconds)
                Text {
                    anchors.centerIn: parent
                    text: root.timeStr
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(16)
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                // Interactive Mouse Area on Center Time
                MouseArea {
                    id: centerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.ArrowCursor
                    acceptedButtons: Qt.RightButton | Qt.MiddleButton

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            root.togglePlayPause()
                        } else if (mouse.button === Qt.MiddleButton) {
                            root.openLauncher()
                        }
                    }

                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) {
                            root.stepVolume(0.04)
                        } else if (wheel.angleDelta.y < 0) {
                            root.stepVolume(-0.04)
                        }
                    }
                }
            }
        }

        // Component template for an authentic Lock Screen Valence Dot (Smooth & Static sizing)
        component ValenceDot: Item {
            id: vDot
            property real haloSize: 30
            property real coreSize: 18
            property real innerSize: 6

            width: haloSize + 4
            height: haloSize + 4

            // Glowing outer halo
            Rectangle {
                anchors.centerIn: parent
                width: vDot.haloSize
                height: vDot.haloSize
                radius: width / 2
                color: Theme.accent ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40) : Qt.rgba(0, 0.94, 1, 0.40)
            }

            // Vibrant core dot
            Rectangle {
                anchors.centerIn: parent
                width: vDot.coreSize
                height: vDot.coreSize
                radius: width / 2
                color: "#FFFFFF"
                border.width: 2.0
                border.color: Theme.accent ? Theme.accent : "#00F0FF"

                // Inner bright neon center dot
                Rectangle {
                    anchors.centerIn: parent
                    width: vDot.innerSize
                    height: vDot.innerSize
                    radius: width / 2
                    color: Theme.accent ? Theme.accent : "#00F0FF"
                }
            }
        }

        /* ── Layer 1 Orbit Group: 2 Inner Atoms (Clockwise, 5.8s) ────────── */
        Item {
            id: innerOrbitGroup
            anchors.centerIn: parent
            width: 1
            height: 1
            rotation: 0

            // 1. Inner Top Dot: (0, -innerOrbitRadius)
            ValenceDot {
                id: innerDotTop
                haloSize: 26
                coreSize: 15
                innerSize: 5
                x: -width / 2
                y: -root.innerOrbitRadius - height / 2
            }

            // 2. Inner Bottom Dot: (0, +innerOrbitRadius)
            ValenceDot {
                id: innerDotBottom
                haloSize: 26
                coreSize: 15
                innerSize: 5
                x: -width / 2
                y: root.innerOrbitRadius - height / 2
            }
        }

        /* ── Layer 2 Orbit Group: 4 Outer Atoms (Counter-Clockwise, 9.4s) ─── */
        Item {
            id: outerOrbitGroup
            anchors.centerIn: parent
            width: 1
            height: 1
            rotation: 0

            // 3. Outer Top Dot: (0, -outerOrbitRadius)
            ValenceDot {
                id: dotTop
                haloSize: 30
                coreSize: 18
                innerSize: 6
                x: -width / 2
                y: -root.outerOrbitRadius - height / 2
            }

            // 4. Outer Bottom Dot: (0, +outerOrbitRadius)
            ValenceDot {
                id: dotBottom
                haloSize: 30
                coreSize: 18
                innerSize: 6
                x: -width / 2
                y: root.outerOrbitRadius - height / 2
            }

            // 5. Outer Left Dot: (-outerOrbitRadius, 0)
            ValenceDot {
                id: dotLeft
                haloSize: 30
                coreSize: 18
                innerSize: 6
                x: -root.outerOrbitRadius - width / 2
                y: -height / 2
            }

            // 6. Outer Right Dot: (+outerOrbitRadius, 0)
            ValenceDot {
                id: dotRight
                haloSize: 30
                coreSize: 18
                innerSize: 6
                x: root.outerOrbitRadius - width / 2
                y: -height / 2
            }
        }
    }
}
