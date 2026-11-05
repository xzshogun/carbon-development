import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import M3Shapes
import "../Singletons"
import "../components"

/**
 * AtomicValenceBar: Revolutionary "Atomic Valence" Quantum Orbital Desktop Shell
 *
 * Concept 1 Blueprint:
 *   1. Center: The Carbon Nucleus (¹²C) with real-time plasma excitation & nuclear load aura.
 *   2. Quantum Energy Levels (n=1..4): Concentric orbital shells representing Hyprland workspaces
 *      with orbiting valence electron quanta and de Broglie probability density halos.
 *   3. Left Catalyst Satellite: Bohr Carbon launcher & active window spectral wavefunction.
 *   4. Right Quantum Spin Satellites: Audio harmonic resonator, Volume spin node,
 *      Lattice network node, and Valence charge sensor.
 */
Item {
    id: root

    implicitHeight: 46
    implicitWidth: parent ? parent.width : 1366
    height: implicitHeight
    width: implicitWidth

    signal openLauncher()
    signal toggleCenterDashboard()
    signal openCenterDashboard()
    signal closeCenterDashboard()
    signal toggleControls()
    signal openMixer()
    signal toggleMixer()
    signal openWifi()
    signal toggleWifi()
    signal openBattery()
    signal toggleBattery()
    signal openPower()

    /* ── Live Telemetry for Nuclear Excitation ── */
    property int cpuUsage: 0
    property string ramUsageGB: "0.0"
    property int ramPct: 0
    property real lastCpuTotal: 0
    property real lastCpuIdle: 0

    Process {
        id: sysProbe
        command: ["awk", "/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5+$6} /^MemTotal:/ {tot=$2} /^MemAvailable:/ {avail=$2} END {print tot, avail}", "/proc/stat", "/proc/meminfo"]
        running: false
        stdout: StdioCollector {
            id: sysOut
            waitForEnd: true
        }
        onExited: {
            var raw = sysOut.text.trim().split("\n")
            if (raw.length >= 2) {
                var cpuParts = raw[0].trim().split(/\s+/)
                if (cpuParts.length >= 2) {
                    var total = parseFloat(cpuParts[0])
                    var idle = parseFloat(cpuParts[1])
                    if (root.lastCpuTotal > 0 && total > root.lastCpuTotal) {
                        var dTotal = total - root.lastCpuTotal
                        var dIdle = idle - root.lastCpuIdle
                        root.cpuUsage = Math.max(0, Math.min(100, Math.round((1.0 - (dIdle / dTotal)) * 100)))
                    }
                    root.lastCpuTotal = total
                    root.lastCpuIdle = idle
                }

                var memParts = raw[1].trim().split(/\s+/)
                if (memParts.length >= 2) {
                    var totKb = parseFloat(memParts[0])
                    var availKb = parseFloat(memParts[1])
                    if (totKb > 0) {
                        var usedKb = Math.max(0, totKb - availKb)
                        root.ramUsageGB = (usedKb / (1024 * 1024)).toFixed(1)
                        root.ramPct = Math.round((usedKb / totKb) * 100)
                    }
                }
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: sysProbe.running = true
    }

    /* ── Hyprland Workspaces Tracking ── */
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
                const id = parseInt(event.data, 10)
                if (!isNaN(id) && id > 0) root.activeWs = id
            }
        }
    }

    Connections {
        target: Hyprland.focusedMonitor
        function onActiveWorkspaceChanged() {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) {
                root.activeWs = Hyprland.focusedMonitor.activeWorkspace.id
            }
        }
    }

    /* Active window title */
    readonly property string activeWinTitle: {
        if (Hyprland.activeWindow && Hyprland.activeWindow.title) {
            return Hyprland.activeWindow.title
        }
        return "Ground State (Idle)"
    }

    /* ── Live Clock & Time State ── */
    property var now: new Date()
    property string timeStr: Qt.formatTime(now, "hh:mm")
    property string secStr: Qt.formatTime(now, "ss")

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root.now = new Date()
            root.timeStr = Qt.formatTime(root.now, "hh:mm")
            root.secStr = Qt.formatTime(root.now, "ss")
        }
    }

    /* ── MPRIS State ── */
    readonly property var players: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
    property var activePlayer: null

    function resolveActivePlayer() {
        if (!root.players || root.players.length === 0) return null
        for (let i = 0; i < root.players.length; i++) {
            if (root.players[i].playbackState === MprisPlaybackState.Playing)
                return root.players[i]
        }
        for (let i = 0; i < root.players.length; i++) {
            if (root.players[i].playbackState === MprisPlaybackState.Paused && (root.players[i].trackTitle || "").length > 0)
                return root.players[i]
        }
        return root.players[0]
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.activePlayer = root.resolveActivePlayer()
    }

    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property bool hasTrack: root.activePlayer !== null && root.trackTitle.trim().length > 0

    function togglePlayPause() {
        if (root.activePlayer) root.activePlayer.togglePlaying()
    }

    /* ── Audio Sink State ── */
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property real volume: audioSink && audioSink.audio ? audioSink.audio.volume : 0.0
    readonly property bool muted: audioSink && audioSink.audio ? audioSink.audio.muted : false
    readonly property int volumePct: Math.round(root.volume * 100)

    /* ── Battery State ── */
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery ? battery.isPresent : false
    readonly property real batteryPct: battery ? battery.percentage : 1.0
    readonly property bool isCharging: battery ? battery.state === UPowerDeviceState.Charging : false

    /* Continuous subatomic spin animation tick */
    property real quantumPhase: 0.0
    FrameAnimation {
        running: root.visible && root.opacity > 0.01
        onTriggered: root.quantumPhase += frameTime * 40.0
    }

    /* ================================================================= */
    /* MAIN ATOMIC VALENCE CANVAS CONTAINER                              */
    /* ================================================================= */
    Item {
        anchors.fill: parent
        anchors.margins: 3

        /* ------------------------------------------------------------- */
        /* 1. LEFT SATELLITE: QUANTUM CATALYST & SPECTRAL WAVEFUNCTION   */
        /* ------------------------------------------------------------- */
        Rectangle {
            id: leftSatellite
            height: 36
            width: Math.min(270, Math.max(160, leftRow.implicitWidth + 24))
            radius: 18
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.isDark ? Theme.bg : "#0e0e14"
            border.color: Qt.rgba(1, 1, 1, 0.09)
            border.width: 1

            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            // Ambient magnetic halo
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.color: catalystHover.containsMouse ? Theme.accent : "transparent"
                border.width: 1.5
                opacity: catalystHover.containsMouse ? 0.6 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }

            RowLayout {
                id: leftRow
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 12
                spacing: 8

                // Bohr Carbon Atomic Catalyst (Launcher)
                Item {
                    id: catalystBtn
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter

                    StaticCarbonLogo {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        hovered: catalystHover.containsMouse
                    }

                    MouseArea {
                        id: catalystHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openLauncher()
                    }
                }

                // Separator
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    color: Theme.isDark ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.18) : Qt.rgba(0, 0, 0, 0.15)
                }

                // Active App Spectral Wavefunction
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Ψ"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(11)
                        font.bold: true
                        color: Theme.accent
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.activeWinTitle
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.Medium
                        color: Theme.fg
                        elide: Text.ElideRight
                    }
                }
            }
        }

        /* ------------------------------------------------------------- */
        /* 2. CENTER NEXUS: THE CARBON NUCLEUS & QUANTUM WORKSPACES      */
        /* ------------------------------------------------------------- */
        Rectangle {
            id: centerNexus
            height: 40
            width: 420
            radius: 20
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.isDark ? Theme.bg : "#0e0e14"
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
            border.width: 1

            /* Background Orbit Waveform Track */
            Canvas {
                id: orbitWaveCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)

                    var cx = width / 2
                    var cy = height / 2

                    // Fine continuous quantum manifold line linking all orbitals
                    ctx.beginPath()
                    ctx.moveTo(16, cy)
                    ctx.lineTo(width - 16, cy)
                    ctx.strokeStyle = Theme.isDark ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08) : Qt.rgba(0, 0, 0, 0.06)
                    ctx.lineWidth = 1.0
                    ctx.stroke()
                }
                Connections {
                    target: Theme
                    function onFgChanged() { orbitWaveCanvas.requestPaint() }
                    function onIsDarkChanged() { orbitWaveCanvas.requestPaint() }
                }
            }

            /* Left Wing: Shells n=1 and n=2 (Workspaces 1 & 2) */
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: [
                        { id: 1, shell: "K", sub: "1s" },
                        { id: 2, shell: "L", sub: "2s" }
                    ]
                    delegate: Item {
                        required property var modelData
                        width: 58
                        height: 28

                        readonly property bool isActive: root.activeWs === modelData.id
                        readonly property real orbitAngle: (root.quantumPhase * (modelData.id === 1 ? 1.5 : 1.0)) * Math.PI / 180

                        // Quantum energy level badge
                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: isActive ? Theme.accent : (wsMouse.containsMouse ? Theme.bgHover : (Theme.isDark ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08) : Qt.rgba(0, 0, 0, 0.06)))
                            border.color: isActive ? Theme.accentLit : (Theme.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10))
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: "e⁻"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: Theme.fontPx(8)
                                    font.bold: true
                                    color: isActive ? (Theme.isDark ? "#111111" : "#ffffff") : Theme.accent
                                }

                                Text {
                                    text: "n=" + modelData.id
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: Theme.fontPx(10)
                                    font.weight: isActive ? Font.Bold : Font.Normal
                                    color: isActive ? (Theme.isDark ? "#111111" : "#ffffff") : Theme.fg
                                }
                            }

                            // Orbiting quantum bead on edge of badge
                            Rectangle {
                                width: 4
                                height: 4
                                radius: 2
                                x: (parent.width / 2 - 2) + Math.cos(orbitAngle) * (parent.width / 2 - 4)
                                y: (parent.height / 2 - 2) + Math.sin(orbitAngle) * (parent.height / 2 - 4)
                                color: isActive ? "#ffffff" : Theme.accent
                                opacity: 0.95
                            }
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchWorkspace(modelData.id)
                        }
                    }
                }
            }

            /* Center: The Quantum Nucleus (¹²C & Live Clock) */
            Item {
                id: nucleusCore
                width: 130
                height: 38
                anchors.centerIn: parent

                // Multi-layer rotating nuclear aura
                Canvas {
                    id: nucleusCanvas
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.clearRect(0, 0, width, height)

                        var cx = width / 2
                        var cy = height / 2

                        // Outer orbital boundary ring
                        ctx.beginPath()
                        ctx.arc(cx, cy, 18, 0, 2 * Math.PI)
                        ctx.strokeStyle = Theme.isDark ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40) : Qt.rgba(0, 0, 0, 0.20)
                        ctx.lineWidth = 1.0
                        ctx.setLineDash([3, 4])
                        ctx.stroke()
                        ctx.setLineDash([])

                        // Revolving particle cloud (protons & neutrons)
                        var numParticles = 6
                        var rad = root.quantumPhase * Math.PI / 180
                        for (var i = 0; i < numParticles; i++) {
                            var ang = rad + (i * 2 * Math.PI / numParticles)
                            var rDist = 18
                            var px = cx + Math.cos(ang) * rDist
                            var py = cy + Math.sin(ang) * (rDist * 0.65)

                            ctx.beginPath()
                            ctx.arc(px, py, 1.8, 0, 2 * Math.PI)
                            ctx.fillStyle = (i % 2 === 0) ? (Theme.accentLit || "#00f0ff") : (Theme.accent || "#3b6287")
                            ctx.fill()
                        }
                    }

                    Connections {
                        target: root
                        function onQuantumPhaseChanged() { nucleusCanvas.requestPaint() }
                    }
                    Connections {
                        target: Theme
                        function onAccentChanged() { nucleusCanvas.requestPaint() }
                        function onIsDarkChanged() { nucleusCanvas.requestPaint() }
                    }
                }

                // Center Core Pill with Live Time & Isotope ID
                Rectangle {
                    width: 74
                    height: 26
                    radius: 13
                    anchors.centerIn: parent
                    color: nucleusMouse.containsMouse ? Theme.bgHover : (Theme.isDark ? Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.85) : Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.65))
                    border.color: Theme.accent
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: -2

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 1

                            Text {
                                text: root.timeStr
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(10)
                                font.weight: Font.Black
                                color: Theme.fg
                            }

                            Text {
                                text: ":" + root.secStr
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(8)
                                font.weight: Font.Bold
                                color: Theme.accent
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "¹²C · Z=6"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(7)
                            font.weight: Font.Bold
                            color: Theme.fgDim
                        }
                    }
                }

                MouseArea {
                    id: nucleusMouse
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
                    onPressAndHold: root.openPower()
                }
            }

            /* Right Wing: Shells n=3 and n=4 (Workspaces 3 & 4) */
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: [
                        { id: 3, shell: "M", sub: "3s" },
                        { id: 4, shell: "N", sub: "4s" }
                    ]
                    delegate: Item {
                        required property var modelData
                        width: 58
                        height: 28

                        readonly property bool isActive: root.activeWs === modelData.id
                        readonly property real orbitAngle: (root.quantumPhase * (modelData.id === 3 ? 1.1 : 0.8) + 180) * Math.PI / 180

                        // Quantum energy level badge
                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: isActive ? Theme.accent : (wsMouseRight.containsMouse ? Theme.bgHover : (Theme.isDark ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08) : Qt.rgba(0, 0, 0, 0.06)))
                            border.color: isActive ? Theme.accentLit : (Theme.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10))
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: "e⁻"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: Theme.fontPx(8)
                                    font.bold: true
                                    color: isActive ? (Theme.isDark ? "#111111" : "#ffffff") : Theme.accent
                                }

                                Text {
                                    text: "n=" + modelData.id
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: Theme.fontPx(10)
                                    font.weight: isActive ? Font.Bold : Font.Normal
                                    color: isActive ? (Theme.isDark ? "#111111" : "#ffffff") : Theme.fg
                                }
                            }

                            // Orbiting quantum bead on edge of badge
                            Rectangle {
                                width: 4
                                height: 4
                                radius: 2
                                x: (parent.width / 2 - 2) + Math.cos(orbitAngle) * (parent.width / 2 - 4)
                                y: (parent.height / 2 - 2) + Math.sin(orbitAngle) * (parent.height / 2 - 4)
                                color: isActive ? "#ffffff" : Theme.accent
                                opacity: 0.95
                            }
                        }

                        MouseArea {
                            id: wsMouseRight
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchWorkspace(modelData.id)
                        }
                    }
                }
            }
        }

        /* ------------------------------------------------------------- */
        /* 3. RIGHT SATELLITE: QUANTUM TELEMETRY & SPIN NODES            */
        /* ------------------------------------------------------------- */
        Rectangle {
            id: rightSatellite
            height: 36
            width: rightRow.implicitWidth + 20
            radius: 18
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.isDark ? Theme.bg : "#0e0e14"
            border.color: Qt.rgba(1, 1, 1, 0.09)
            border.width: 1

            RowLayout {
                id: rightRow
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                /* Audio Harmonic Resonator */
                Item {
                    Layout.preferredWidth: root.hasTrack ? Math.min(130, trackRow.implicitWidth) : 22
                    Layout.preferredHeight: 24
                    clip: true
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    RowLayout {
                        id: trackRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            text: root.isPlaying ? "graphic_eq" : "music_note"
                            font.family: Theme.fontIcon
                            font.pixelSize: 14
                            color: Theme.accent
                        }

                        Text {
                            visible: root.hasTrack
                            text: root.trackTitle
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(9)
                            font.weight: Font.Medium
                            color: Theme.fg
                            elide: Text.ElideRight
                            Layout.maximumWidth: 100
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePlayPause()
                    }
                }

                // Separator
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    color: Theme.isDark ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.18) : Qt.rgba(0, 0, 0, 0.15)
                }

                /* Volume Spin Node */
                Item {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20

                    Text {
                        anchors.centerIn: parent
                        text: root.muted ? "volume_off" : (root.volume > 0.5 ? "volume_up" : "volume_down")
                        font.family: Theme.fontIcon
                        font.pixelSize: 15
                        color: root.muted ? Theme.err : (volHov.containsMouse ? Theme.accent : Theme.fg)
                    }

                    MouseArea {
                        id: volHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMixer()
                    }
                }

                /* Wi-Fi Quantum Lattice Node */
                Item {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20

                    Text {
                        anchors.centerIn: parent
                        text: "wifi"
                        font.family: Theme.fontIcon
                        font.pixelSize: 15
                        color: wifiHov.containsMouse ? Theme.accent : Theme.fg
                    }

                    MouseArea {
                        id: wifiHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleWifi()
                    }
                }

                /* Valence Charge (Battery) */
                Item {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 20
                    visible: root.hasBattery

                    Text {
                        anchors.centerIn: parent
                        text: root.isCharging ? "battery_charging_full" : (root.batteryPct > 0.8 ? "battery_full" : (root.batteryPct > 0.2 ? "battery_3_bar" : "battery_alert"))
                        font.family: Theme.fontIcon
                        font.pixelSize: 15
                        color: root.batteryPct < 0.2 ? Theme.err : (batHov.containsMouse ? Theme.accent : Theme.fg)
                    }

                    MouseArea {
                        id: batHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleBattery()
                    }
                }

                /* Quantum Matrix / Quick Settings Node */
                Item {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20

                    Text {
                        anchors.centerIn: parent
                        text: "tune"
                        font.family: Theme.fontIcon
                        font.pixelSize: 15
                        color: qkHov.containsMouse ? Theme.accent : Theme.fg
                    }

                    MouseArea {
                        id: qkHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleControls()
                    }
                }
            }
        }
    }
}
