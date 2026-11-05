import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "../Singletons"

Item {
    id: root

    implicitWidth: 720
    implicitHeight: 46

    signal openLauncher()
    signal toggleCenterDashboard()
    signal openCenterDashboard()
    signal toggleControls()
    signal openMixer()
    signal toggleMixer()
    signal openWifi()
    signal toggleWifi()
    signal openBattery()
    signal toggleBattery()
    signal openPower()

    /* ── Time Logic ── */
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

    /* ── Hyprland Workspaces ── */
    property int activeWs: 1
    function switchWorkspace(id) {
        root.activeWs = id
        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(id)])
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name
            if (n === "workspace" || n === "workspacev2") {
                const parts = event.data.split(",")
                const id = parseInt(parts[0], 10)
                if (!isNaN(id) && id > 0) root.activeWs = id
            }
        }
    }
    Process {
        id: wsInitProc
        command: ["hyprctl", "activeworkspace", "-j"]
        running: false
        stdout: StdioCollector {
            id: wsInitOut
            waitForEnd: true
        }
        onExited: {
            try {
                var d = JSON.parse(wsInitOut.text)
                if (d && d.id) root.activeWs = d.id
            } catch(e) {}
        }
    }
    Component.onCompleted: wsInitProc.running = true

    /* ── Media Tracking ── */
    readonly property var mprisPlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property bool isPlaying: mprisPlayer && mprisPlayer.playbackState === MprisPlaybackState.Playing
    readonly property string trackTitle: mprisPlayer ? (mprisPlayer.trackTitle || "") : ""

    function togglePlayPause() {
        if (mprisPlayer && mprisPlayer.canControl) mprisPlayer.playPause()
    }

    /* ── Audio Pipewire ── */
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property real volume: audioSink && audioSink.audio ? audioSink.audio.volume : 0.0
    readonly property int volumePct: Math.round(root.volume * 100)
    function stepVolume(delta) {
        if (audioSink && audioSink.audio) {
            audioSink.audio.volume = Math.max(0.0, Math.min(1.0, audioSink.audio.volume + delta))
        }
    }

    /* ── Battery / Power ── */
    readonly property var batDevice: UPower.displayDevice
    readonly property int batteryPct: batDevice ? Math.round(batDevice.percentage * 100) : 100
    readonly property bool isCharging: batDevice ? batDevice.state === UPowerDeviceState.Charging : false

    /* ── Crystalline Light Shimmer Sweeper (Refraction Sweep) ── */
    property real shimmerPos: 0.0
    NumberAnimation on shimmerPos {
        from: -0.2
        to: 1.2
        duration: 3400
        loops: Animation.Infinite
        easing.type: Easing.InOutQuad
        running: root.visible && root.opacity > 0.01
    }

    /* ── Tri-Shard Cluster Row ── */
    Row {
        anchors.centerIn: parent
        spacing: 6

        /* ═════════════════════════════════════════════════════════════════════
           SHARD 1: LEFT NEURAL PRISM (Launcher & Diamond Workspaces)
           ═════════════════════════════════════════════════════════════════════ */
        Item {
            id: leftShard
            width: 210
            height: 38
            anchors.verticalCenter: parent.verticalCenter

            // Angled Chamfered Facet Background
            Shape {
                id: leftShardShape
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    strokeColor: leftShardMouse.containsMouse ? Theme.accent : Theme.outline
                    strokeWidth: 1.3
                    fillColor: Theme.isDark ? "#101217" : "#f4f6fa"

                    // Polygon: Chamfer top-left (8px), straight top, angle cut right (14px), straight bottom, angle cut left
                    startX: 12; startY: 0
                    PathLine { x: leftShard.width - 12; y: 0 }
                    PathLine { x: leftShard.width; y: leftShard.height / 2 }
                    PathLine { x: leftShard.width - 12; y: leftShard.height }
                    PathLine { x: 12; y: leftShard.height }
                    PathLine { x: 0; y: leftShard.height - 12 }
                    PathLine { x: 0; y: 12 }
                    PathLine { x: 12; y: 0 }
                }
            }

            // Interior Elements
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 16
                spacing: 6

                // App Launcher Crystal Emblem
                Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    rotation: 45
                    color: launcherBtnMouse.containsMouse ? Theme.accent : (Theme.isDark ? "#1b1e28" : "#ffffff")
                    border.color: Theme.accent
                    border.width: 1

                    scale: launcherBtnMouse.containsMouse ? 1.15 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    Text {
                        anchors.centerIn: parent
                        rotation: -45
                        text: "⌘"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.Bold
                        color: launcherBtnMouse.containsMouse ? Theme.accentFg : Theme.fg
                    }

                    MouseArea {
                        id: launcherBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openLauncher()
                    }
                }

                Rectangle {
                    width: 1
                    height: 14
                    color: Theme.outline
                    opacity: 0.35
                    Layout.leftMargin: 2
                }

                // Crystalline Diamond Workspaces (1 - 4)
                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: [1, 2, 3, 4]

                        Item {
                            width: 22
                            height: 22

                            readonly property bool isCurrent: root.activeWs === modelData

                            Rectangle {
                                id: wsDiamond
                                anchors.centerIn: parent
                                width: isCurrent ? 16 : 13
                                height: isCurrent ? 16 : 13
                                rotation: 45
                                color: isCurrent ? Theme.accent : (wsMouse.containsMouse ? Theme.bgHover : "transparent")
                                border.color: isCurrent ? Theme.accent : (wsMouse.containsMouse ? Theme.accent : Theme.outline)
                                border.width: isCurrent ? 1.5 : 1.0

                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    rotation: -45
                                    text: modelData
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: isCurrent ? 9 : 8
                                    font.weight: Font.Bold
                                    color: isCurrent ? Theme.accentFg : Theme.fgDim
                                }
                            }

                            MouseArea {
                                id: wsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchWorkspace(modelData)
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: leftShardMouse
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
            }
        }

        /* ═════════════════════════════════════════════════════════════════════
           SHARD 2: CENTER TACHYON PRISM (The Core Kinetic Shard)
           ═════════════════════════════════════════════════════════════════════ */
        Item {
            id: centerShard
            width: 250
            height: 42
            anchors.verticalCenter: parent.verticalCenter

            // 3D Origami Kinetic Perspective Rotation
            transform: Rotation {
                id: origamiRot
                origin.x: centerShard.width / 2
                origin.y: 0
                axis { x: 1; y: 0; z: 0 }
                angle: centerMouseArea.pressed ? 12 : (centerMouseArea.containsMouse ? -4 : 0)
                Behavior on angle {
                    NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                }
            }

            scale: centerMouseArea.containsMouse ? 1.04 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 200; easing.type: Easing.OutBack }
            }

            // Hexagonal Diamond Cut Facet Shape
            Shape {
                id: centerShardShape
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    strokeColor: centerMouseArea.containsMouse ? Theme.accent : Theme.outline
                    strokeWidth: 1.5
                    fillColor: Theme.isDark ? "#0d0f14" : "#ffffff"

                    // Hexagonal chamfer: cut 14px in on each top/bottom corner
                    startX: 16; startY: 0
                    PathLine { x: centerShard.width - 16; y: 0 }
                    PathLine { x: centerShard.width; y: centerShard.height / 2 }
                    PathLine { x: centerShard.width - 16; y: centerShard.height }
                    PathLine { x: 16; y: centerShard.height }
                    PathLine { x: 0; y: centerShard.height / 2 }
                    PathLine { x: 16; y: 0 }
                }

                // Ambient Crease Seam (Kinetic Origami Crease Line)
                ShapePath {
                    strokeColor: Theme.accent
                    strokeWidth: 1.0
                    fillColor: "transparent"
                    startX: centerShard.width / 2; startY: 0
                    PathLine { x: centerShard.width / 2; y: centerShard.height }
                }
            }

            // Refraction Light Ray Shimmer (Animated light sweep across the crystal face)
            Rectangle {
                width: 30
                height: parent.height
                x: parent.width * root.shimmerPos - width / 2
                rotation: 20
                color: Theme.accent
                opacity: 0.08
                visible: centerMouseArea.containsMouse
            }

            // Interior Clock & Song Spectrum
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 8

                // Digital Time Readout
                Text {
                    text: root.timeStr
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(15)
                    font.weight: Font.Bold
                    color: Theme.fg
                    Layout.alignment: Qt.AlignVCenter
                }

                // Origami Center Diamond Divider
                Rectangle {
                    width: 6
                    height: 6
                    rotation: 45
                    color: Theme.accent
                    Layout.alignment: Qt.AlignVCenter
                }

                // Song Title or Kinetic Shard Subtitle
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.isPlaying ? ("♫ " + root.trackTitle) : "SHARD · KINETIC"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(10)
                    font.weight: Font.Bold
                    color: root.isPlaying ? Theme.accent : Theme.fgDim
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Interactive Click & Scroll
            MouseArea {
                id: centerMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        root.togglePlayPause()
                    } else {
                        root.toggleCenterDashboard()
                    }
                }

                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) root.stepVolume(0.04)
                    else if (wheel.angleDelta.y < 0) root.stepVolume(-0.04)
                }
            }
        }

        /* ═════════════════════════════════════════════════════════════════════
           SHARD 3: RIGHT RESONANCE PRISM (Telemetry, Audio, Battery & Power)
           ═════════════════════════════════════════════════════════════════════ */
        Item {
            id: rightShard
            width: 220
            height: 38
            anchors.verticalCenter: parent.verticalCenter

            // Angled Chamfered Facet Background
            Shape {
                id: rightShardShape
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    strokeColor: rightShardMouse.containsMouse ? Theme.accent : Theme.outline
                    strokeWidth: 1.3
                    fillColor: Theme.isDark ? "#101217" : "#f4f6fa"

                    // Symmetrical mirrored polygon
                    startX: 0; startY: rightShard.height / 2
                    PathLine { x: 12; y: 0 }
                    PathLine { x: rightShard.width - 12; y: 0 }
                    PathLine { x: rightShard.width; y: 12 }
                    PathLine { x: rightShard.width; y: rightShard.height - 12 }
                    PathLine { x: rightShard.width - 12; y: rightShard.height }
                    PathLine { x: 12; y: rightShard.height }
                    PathLine { x: 0; y: rightShard.height / 2 }
                }
            }

            // Interior Telemetry Controls
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 14
                spacing: 8

                // Volume Node
                Row {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 4
                        rotation: 45
                        color: volMouse.containsMouse ? Theme.accent : (Theme.isDark ? "#1b1e28" : "#ffffff")
                        border.color: Theme.outline
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            rotation: -45
                            text: root.volume === 0 ? "volume_off" : (root.volume > 0.5 ? "volume_up" : "volume_down")
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 12
                            color: volMouse.containsMouse ? Theme.accentFg : Theme.fg
                        }

                        MouseArea {
                            id: volMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openMixer()
                        }
                    }

                    Text {
                        text: root.volumePct + "%"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.Bold
                        color: Theme.fgDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    width: 1
                    height: 14
                    color: Theme.outline
                    opacity: 0.35
                }

                // Battery Node
                Row {
                    spacing: 3
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: root.isCharging ? "bolt" : (root.batteryPct > 80 ? "battery_full" : (root.batteryPct > 30 ? "battery_std" : "battery_alert"))
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 14
                        color: root.isCharging ? Theme.accent : Theme.fg
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.batteryPct + "%"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.Bold
                        color: Theme.fgDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    width: 1
                    height: 14
                    color: Theme.outline
                    opacity: 0.35
                }

                // Power Crystal Button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 4
                    rotation: 45
                    color: powerMouse.containsMouse ? "#ff5555" : (Theme.isDark ? "#1b1e28" : "#ffffff")
                    border.color: powerMouse.containsMouse ? "#ff5555" : Theme.outline
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        rotation: -45
                        text: "power_settings_new"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 12
                        color: powerMouse.containsMouse ? "#ffffff" : Theme.fgDim
                    }

                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openPower()
                    }
                }
            }

            MouseArea {
                id: rightShardMouse
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
            }
        }
    }
}
