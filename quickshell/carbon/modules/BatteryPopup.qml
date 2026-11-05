import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../Singletons"
import "../components"

/**
 * Caelestia-Style Wavy Liquid Battery Popup
 * Vertical pill with animated sinusoidal waves across the liquid fill surface,
 * live percentage, charging animation, health metrics, and power profile selector.
 */
Item {
    id: root

    property bool open: false
    property string barEdge: "top"
    property bool hovered: false

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery ? battery.isPresent : false
    readonly property real batteryPct: battery ? battery.percentage : 1.0
    readonly property int batteryState: battery ? battery.state : UPowerDeviceState.FullyCharged
    readonly property bool isCharging: batteryState === UPowerDeviceState.Charging
    readonly property bool isFull: batteryState === UPowerDeviceState.FullyCharged || root.batteryPct >= 0.99

    /* Smooth battery percentage for fluid liquid level animation */
    property real animatedPct: root.batteryPct
    Behavior on animatedPct { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    /* Power profile state */
    property string activeProfile: "balanced"

    Process {
        id: profileGetProc
        command: ["powerprofilesctl", "get"]
        stdout: SplitParser {
            onRead: (line) => {
                const p = line.trim()
                if (p.length > 0) root.activeProfile = p
            }
        }
    }

    Timer {
        interval: 3000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: profileGetProc.running = true
    }

    function setProfile(p) {
        root.activeProfile = p
        Quickshell.execDetached(["powerprofilesctl", "set", p])
    }

    /* Formatted battery time */
    readonly property string timeEstimateStr: {
        if (root.isFull) return "Fully Charged"
        if (root.isCharging) {
            if (battery && battery.timeToFull > 0) {
                const hrs = Math.floor(battery.timeToFull / 3600)
                const mins = Math.floor((battery.timeToFull % 3600) / 60)
                return hrs > 0 ? (hrs + "h " + mins + "m until full") : (mins + "m until full")
            }
            return "Charging..."
        }
        if (battery && battery.timeToEmpty > 0) {
            const hrs = Math.floor(battery.timeToEmpty / 3600)
            const mins = Math.floor((battery.timeToEmpty % 3600) / 60)
            return hrs > 0 ? (hrs + "h " + mins + "m remaining") : (mins + "m remaining")
        }
        return "On Battery"
    }

    readonly property color statusColor: {
        if (root.isCharging) return Theme.accentLit
        if (root.batteryPct < 0.20) return Theme.err
        if (root.batteryPct < 0.40) return Theme.warn
        return Theme.accent
    }

    implicitWidth: 260
    implicitHeight: 220
    width: 260
    height: 220
    clip: true

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: root.hovered = hoverHandler.hovered
    }

    property bool animatingOut: false
    onOpenChanged: {
        if (!open) {
            animatingOut = true
            animatingOutTimer.restart()
        } else {
            animatingOut = false
            animatingOutTimer.stop()
        }
    }
    Timer {
        id: animatingOutTimer
        interval: 200
        onTriggered: root.animatingOut = false
    }

    property string barMode: "notch"
    property real notchOpacity: 0.96

    readonly property string fillPath: {
        const w = card.width
        const h = card.height
        if (root.barMode === "notch") {
            const r = 16
            if (root.barEdge === "bottom") {
                return `M 0 ${r} A ${r} ${r} 0 0 1 ${r} 0 L ${w} 0 L ${w} ${h} L ${r} ${h} A ${r} ${r} 0 0 1 0 ${h - r} Z`
            }
            return `M 0 ${r} A ${r} ${r} 0 0 1 ${r} 0 L ${w} 0 L ${w} ${h} L ${r} ${h} A ${r} ${r} 0 0 1 0 ${h - r} Z`
        }
        const r = 16
        return `M ${r} 0 L ${w - r} 0 A ${r} ${r} 0 0 1 ${w} ${r} L ${w} ${h - r} A ${r} ${r} 0 0 1 ${w - r} ${h} L ${r} ${h} A ${r} ${r} 0 0 1 0 ${h - r} L 0 ${r} A ${r} ${r} 0 0 1 ${r} 0 Z`
    }

    readonly property string strokePath: {
        const w = card.width
        const h = card.height
        if (root.barMode === "notch") {
            const r = 16
            if (root.barEdge === "bottom") {
                return `M 0 ${h - r} L 0 ${r} A ${r} ${r} 0 0 1 ${r} 0 L ${w} 0`
            }
            return `M 0 ${r} L 0 ${h - r} A ${r} ${r} 0 0 0 ${r} ${h} L ${w} ${h}`
        }
        const r = 16
        return `M ${r} 0 L ${w - r} 0 A ${r} ${r} 0 0 1 ${w} ${r} L ${w} ${h - r} A ${r} ${r} 0 0 1 ${w - r} ${h} L ${r} ${h} A ${r} ${r} 0 0 1 0 ${h - r} L 0 ${r} A ${r} ${r} 0 0 1 ${r} 0 Z`
    }

    Item {
        id: card
        width: parent.width
        height: parent.height

        /* Swallow clicks on the popup card background so they don't dismiss the window */
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {}
        }

        Shape {
            id: cardBgShape
            anchors.fill: parent
            preferredRendererType: Shape.GeometryRenderer
            antialiasing: true
            asynchronous: false

            ShapePath {
                fillColor: root.barMode === "notch" ? (Theme.isDark ? Qt.rgba(0.04, 0.04, 0.06, root.notchOpacity) : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.notchOpacity)) : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.shellOpacity)
                strokeColor: "transparent"
                strokeWidth: 0
                PathSvg { path: root.fillPath }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.open ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.45) : Theme.outline
                strokeWidth: 1
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: root.strokePath }
            }
        }

        opacity: root.open ? 1.0 : 0.0
        scale: root.open ? 1.0 : 0.95
        y: root.open ? 0 : (root.barEdge === "bottom" ? -6 : 6)

        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? 200 : 140
                easing.bezierCurve: Theme.animCurves.expressiveDefaultEffects
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.open ? 280 : 160
                easing.bezierCurve: root.open ? Theme.animCurves.expressiveDefaultSpatial : Theme.animCurves.standardAccel
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: root.open ? 280 : 160
                easing.bezierCurve: root.open ? Theme.animCurves.expressiveDefaultSpatial : Theme.animCurves.standardAccel
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            opacity: root.open ? 1.0 : 0.0
            y: root.open ? 0 : 4
            Behavior on opacity { NumberAnimation { duration: root.open ? Theme.animDurations.fastSpatial : Theme.animDurations.closePopup; easing.bezierCurve: root.open ? Theme.animCurves.expressiveDefaultEffects : Theme.animCurves.standardAccel } }
            Behavior on y { NumberAnimation { duration: root.open ? Theme.animDurations.openPopup : Theme.animDurations.closePopup; easing.bezierCurve: root.open ? Theme.animCurves.expressiveDefaultSpatial : Theme.animCurves.standardAccel } }

            /* ── Left: Caelestia Wavy Liquid Battery Card ───────────── */
            Rectangle {
                id: wavyCard
                Layout.preferredWidth: 94
                Layout.fillHeight: true
                radius: 16
                color: Qt.alpha(root.statusColor, 0.08)
                border.color: root.isCharging ? root.statusColor : Qt.alpha(root.statusColor, 0.25)
                border.width: root.isCharging ? 1.5 : 1
                clip: true

                Behavior on border.color { ColorAnimation { duration: 250 } }

                /* Wave animation phase state */
                property real wavePhase: 0.0

                FrameAnimation {
                    id: waveAnim
                    running: root.open && card.opacity > 0.85 && root.visible
                    onTriggered: {
                        wavyCard.wavePhase += frameTime * 0.88
                        waveCanvas.requestPaint()
                    }
                }

                /* Animated Liquid Surface Canvas */
                Canvas {
                    id: waveCanvas
                    anchors.fill: parent

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        const fillPct = Math.min(1.0, Math.max(0.0, root.animatedPct))
                        // Constrain liquid surface between 34px (below header at 100%) and (height - 8) at 0%
                        const minWaterY = 34
                        const maxWaterY = height - 8
                        const waterLevelY = maxWaterY - fillPct * (maxWaterY - minWaterY)
                        const amp = root.isCharging ? 4.5 : 3.2
                        const waveLength = width * 0.85
                        const phase = wavyCard.wavePhase

                        // 1. Secondary background wave (softer, offset)
                        ctx.save()
                        ctx.beginPath()
                        ctx.moveTo(0, height)
                        ctx.lineTo(0, waterLevelY)

                        for (let x = 0; x <= width; x += 2) {
                            const y = waterLevelY + (amp * 0.7) * Math.sin((x / waveLength + phase * 1.3 + 1.5) * Math.PI * 2)
                            ctx.lineTo(x, y)
                        }

                        ctx.lineTo(width, height)
                        ctx.closePath()
                        ctx.fillStyle = Qt.alpha(root.statusColor, 0.28)
                        ctx.fill()
                        ctx.restore()

                        // 2. Primary foreground wave
                        ctx.save()
                        ctx.beginPath()
                        ctx.moveTo(0, height)
                        ctx.lineTo(0, waterLevelY)

                        for (let x = 0; x <= width; x += 2) {
                            const y = waterLevelY + amp * Math.sin((x / waveLength + phase) * Math.PI * 2)
                            ctx.lineTo(x, y)
                        }

                        ctx.lineTo(width, height)
                        ctx.closePath()

                        // Gradient fill for lush liquid depth
                        const grad = ctx.createLinearGradient(0, waterLevelY, 0, height)
                        grad.addColorStop(0.0, Qt.alpha(root.statusColor, 0.6))
                        grad.addColorStop(1.0, Qt.alpha(root.statusColor, 0.9))
                        ctx.fillStyle = grad
                        ctx.fill()

                        // 3. Wavy crest highlight line
                        ctx.beginPath()
                        for (let x = 0; x <= width; x += 2) {
                            const y = waterLevelY + amp * Math.sin((x / waveLength + phase) * Math.PI * 2)
                            if (x === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.strokeStyle = Qt.alpha("#FFFFFF", 0.55)
                        ctx.lineWidth = 1.5
                        ctx.stroke()

                        ctx.restore()
                    }
                }

                /* Card Overlay: Top Icon & "Battery", Bottom Percentage & Status */
                Item {
                    anchors.fill: parent
                    anchors.margins: 10

                    /* Top: Battery icon & "Battery" label */
                    RowLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 5

                        Text {
                            text: root.isCharging ? "bolt" : "battery_full"
                            font.family: Theme.fontIcon
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: root.isCharging ? root.statusColor : Theme.fg
                        }

                        Text {
                            text: "Battery"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(12)
                            font.weight: Font.DemiBold
                            color: Theme.fg
                            elide: Text.ElideRight
                        }
                    }

                    /* Bottom: Big Percentage & Subtitle */
                    ColumnLayout {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 1

                        Text {
                            text: Math.round(root.batteryPct * 100) + "%"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(22)
                            font.weight: Font.Bold
                            color: Theme.fg
                        }

                        Text {
                            text: root.isCharging ? "Charging" : (root.isFull ? "Full" : "Discharging")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(10)
                            font.weight: Font.Medium
                            color: Theme.fgDim
                        }
                    }
                }
            }

            /* ── Right: Stats & Power Profiles ──────────────────────── */
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                /* Header: Status badge */
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        height: 18
                        width: stateLabel.implicitWidth + 12
                        radius: 9
                        color: Qt.alpha(root.statusColor, 0.18)

                        Text {
                            id: stateLabel
                            anchors.centerIn: parent
                            text: root.isCharging ? "CHARGING" : (root.isFull ? "FULL" : "ON BATTERY")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(8)
                            font.weight: Font.Bold
                            color: root.statusColor
                        }
                    }
                }

                /* Time Remaining & Health */
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: root.timeEstimateStr
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.DemiBold
                        color: Theme.fg
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: (battery && battery.energyRate > 0)
                            ? ("Draw: " + battery.energyRate.toFixed(2) + " W")
                            : "Health: 100%"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(9)
                        color: Theme.fgDim
                    }

                    Text {
                        text: (battery && battery.voltage > 0)
                            ? ("Voltage: " + battery.voltage.toFixed(2) + " V")
                            : "DELL CYMGM8A"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(9)
                        color: Theme.fgFaint
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.outline
                }

                /* Power Profiles selector */
                Text {
                    text: "Power Profile"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(9)
                    font.weight: Font.Bold
                    color: Theme.fgDim
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "power-saver", label: "Quiet", icon: "eco" },
                            { id: "balanced",    label: "Balanced", icon: "balance" },
                            { id: "performance", label: "Max",   icon: "bolt" }
                        ]

                        delegate: Rectangle {
                            id: profBtn
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            radius: 6

                            readonly property bool isSelected: root.activeProfile === modelData.id
                            color: isSelected ? Theme.accent : (pHov.containsMouse ? Theme.bgHover : "#18FFFFFF")
                            border.color: isSelected ? Theme.accentLit : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.motionDurationShort2 } }

                            Text {
                                anchors.centerIn: parent
                                text: profBtn.modelData.icon
                                font.family: Theme.fontIcon
                                font.pixelSize: 14
                                color: profBtn.isSelected ? "#111111" : Theme.fg
                            }

                            MouseArea {
                                id: pHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setProfile(profBtn.modelData.id)
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: "Li-ion Battery"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(8)
                    color: Theme.fgFaint
                    Layout.alignment: Qt.AlignRight
                }
            }
        }
    }
}
