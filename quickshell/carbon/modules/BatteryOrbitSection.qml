import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../Singletons"
import "../components"

/**
 * BatteryOrbitSection.qml
 *
 * Nucleus Hub Attached Battery & Power Mode Section.
 * Blooms smoothly from the nucleus when the Battery satellite is triggered in Vanish Mode.
 *
 * Features:
 * - Fluid Wavy Liquid Battery Card displaying real-time charge %, time remaining & draw
 * - Direct Power Mode switching between:
 *     1. Power Saving (Eco)
 *     2. Balanced (Normal)
 *     3. Performance (High)
 *     4. Ultra (Game Mode / Direct Scanout via hypr-gamemode)
 * - Seamless back navigation return to orbital lobes
 * - Clean 1px accent outlines on hover (zero solid dark fills)
 */
Item {
    id: root

    /* ── Mode & State ── */
    property bool isOpen: false
    property real transitionProgress: 0.0
    readonly property bool reducedMotion: Boolean(Theme.reducedMotion)
    signal backRequested()

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string powerProfileScript: root.home + "/.config/hypr/scripts/carbon-power-profile.sh"

    /* ── Battery State ── */
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery ? battery.isPresent : false
    readonly property real batteryPct: battery ? battery.percentage : 1.0
    readonly property int batteryState: battery ? battery.state : UPowerDeviceState.FullyCharged
    readonly property bool isCharging: batteryState === UPowerDeviceState.Charging
    readonly property bool isFull: batteryState === UPowerDeviceState.FullyCharged || root.batteryPct >= 0.99

    property real animatedPct: root.batteryPct
    Behavior on animatedPct { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

    readonly property color statusColor: {
        if (root.isCharging) return Theme.accentLit
        if (root.batteryPct < 0.20) return Theme.err
        if (root.batteryPct < 0.40) return Theme.warn
        return Theme.accent
    }

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

    /* ── Power Profile State ── */
    property string activeProfile: "balanced"

    Process {
        id: profileGetProc
        command: [root.powerProfileScript, "get"]
        stdout: SplitParser {
            onRead: line => {
                const p = line.trim()
                if (p.length > 0) root.activeProfile = p
            }
        }
    }

    Timer {
        id: profilePollTimer
        interval: 3000
        running: root.isOpen && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!profileGetProc.running) {
                profileGetProc.command = [root.powerProfileScript, "get"]
                profileGetProc.running = true
            }
        }
    }

    function setProfile(p) {
        root.activeProfile = p
        Quickshell.execDetached([root.powerProfileScript, "set", p])
        profilePollTimer.restart()
    }

    /* ── Transitions ── */
    NumberAnimation {
        id: openAnim
        target: root
        property: "transitionProgress"
        from: 0.0
        to: 1.0
        duration: root.reducedMotion ? 0 : 380
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "transitionProgress"
        from: 1.0
        to: 0.0
        duration: root.reducedMotion ? 0 : 320
        easing.type: Easing.OutCubic
        onFinished: {
            root.isOpen = false
            root.backRequested()
        }
    }

    function openSection() {
        closeAnim.stop()
        root.isOpen = true
        openAnim.restart()
        if (!profileGetProc.running) {
            profileGetProc.command = [root.powerProfileScript, "get"]
            profileGetProc.running = true
        }
    }

    function closeSection() {
        openAnim.stop()
        closeAnim.restart()
    }

    width: 360
    height: 360
    visible: root.isOpen && (root.transitionProgress > 0.001)
    opacity: root.transitionProgress
    scale: 0.94 + 0.06 * root.transitionProgress

    /* ── Back Navigation Pill (Top) ── */
    Rectangle {
        id: backPill
        anchors.horizontalCenter: parent.horizontalCenter
        y: -150 * root.transitionProgress
        width: 72
        height: 28
        radius: 14
        color: backMouse.containsMouse ? Qt.alpha(Theme.accent, 0.15) : Qt.alpha(Theme.bgAlt, 0.90)
        border.color: backMouse.containsMouse ? Theme.accent : Theme.outline
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: "arrow_back"
                font.family: Theme.fontIcon
                font.pixelSize: 14
                color: backMouse.containsMouse ? Theme.accentLit : Theme.fg
            }

            Text {
                text: "Hub"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(10)
                font.weight: Font.Bold
                color: backMouse.containsMouse ? Theme.accentLit : Theme.fg
            }
        }

        MouseArea {
            id: backMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeSection()
        }
    }

    /* ── Top Card: Wavy Liquid Battery & Stats Capsule ── */
    Rectangle {
        id: batteryCard
        anchors.horizontalCenter: parent.horizontalCenter
        y: -108 * root.transitionProgress
        width: 340
        height: 84
        radius: 18
        color: Qt.alpha(Theme.bgAlt, 0.92)
        border.color: root.isCharging ? root.statusColor : Theme.outline
        border.width: root.isCharging ? 1.5 : 1.0
        clip: true

        Behavior on border.color { ColorAnimation { duration: 250 } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            /* Wavy Mini Liquid Tank */
            Rectangle {
                id: wavyTank
                Layout.preferredWidth: 64
                Layout.fillHeight: true
                radius: 12
                color: Qt.alpha(root.statusColor, 0.10)
                border.color: root.isCharging ? root.statusColor : Qt.alpha(root.statusColor, 0.35)
                border.width: 1
                clip: true

                property real wavePhase: 0.0
                FrameAnimation {
                    running: root.isOpen && root.visible
                    onTriggered: {
                        wavyTank.wavePhase += frameTime * 0.90
                        wCanvas.requestPaint()
                    }
                }

                Canvas {
                    id: wCanvas
                    anchors.fill: parent

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        const fillPct = Math.min(1.0, Math.max(0.0, root.animatedPct))
                        const waterLevelY = height - fillPct * height
                        const amp = root.isCharging ? 3.5 : 2.5
                        const waveLength = width * 0.9
                        const phase = wavyTank.wavePhase

                        // Liquid Fill
                        ctx.save()
                        ctx.beginPath()
                        ctx.moveTo(0, height)
                        ctx.lineTo(0, waterLevelY)

                        for (let x = 0; x <= width; x += 3) {
                            const y = waterLevelY + Math.sin((x / waveLength) * Math.PI * 2 + phase) * amp
                            ctx.lineTo(x, y)
                        }

                        ctx.lineTo(width, height)
                        ctx.closePath()

                        const grad = ctx.createLinearGradient(0, waterLevelY, 0, height)
                        grad.addColorStop(0, root.statusColor)
                        grad.addColorStop(1, Qt.darker(root.statusColor, 1.4))
                        ctx.fillStyle = grad
                        ctx.fill()
                        ctx.restore()
                    }
                }

                // Bolt Icon in center if charging
                Text {
                    anchors.centerIn: parent
                    visible: root.isCharging
                    text: "bolt"
                    font.family: Theme.fontIcon
                    font.pixelSize: 22
                    color: "#ffffff"
                    style: Text.Raised
                    styleColor: "#80000000"
                }
            }

            /* Stats Column */
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 3

                // Top: % and status badge
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: Math.round(root.batteryPct * 100) + "%"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(22)
                        font.weight: Font.Bold
                        color: Theme.fg
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        height: 20
                        width: stateLabel.implicitWidth + 14
                        radius: 10
                        color: Qt.alpha(root.statusColor, 0.20)
                        border.color: root.statusColor
                        border.width: 1

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

                // Middle: Time estimate
                Text {
                    text: root.timeEstimateStr
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.Medium
                    color: Theme.fg
                }

                // Bottom: Power draw / device label
                Text {
                    text: (battery && battery.energyRate > 0)
                        ? ("Discharge Rate: " + battery.energyRate.toFixed(1) + " W")
                        : "Battery Health: 100%"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(8.5)
                    color: Theme.fgDim
                }
            }
        }
    }

    /* ── Bottom Section: 4 Power Mode Action Cards ── */
    Rectangle {
        id: powerModeContainer
        anchors.horizontalCenter: parent.horizontalCenter
        y: 48 * root.transitionProgress
        width: 340
        height: 86
        radius: 18
        color: Qt.alpha(Theme.bgAlt, 0.92)
        border.color: Theme.outline
        border.width: 1.0

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            Repeater {
                model: [
                    { id: "power-saver", label: "Power Saver", sub: "Eco Mode", icon: "eco" },
                    { id: "balanced",    label: "Balanced",    sub: "Standard", icon: "balance" },
                    { id: "performance", label: "Performance", sub: "Max Clock", icon: "bolt" },
                    { id: "ultra",       label: "Ultra",       sub: "Game Mode", icon: "sports_esports" }
                ]

                delegate: Rectangle {
                    id: modeCard
                    required property var modelData
                    required property int index

                    readonly property bool isActive: (root.activeProfile === modelData.id)

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: isActive ? Qt.alpha(Theme.accent, 0.22) : (modeMouse.containsMouse ? Qt.alpha(Theme.accent, 0.08) : Qt.alpha(Theme.bg, 0.70))
                    border.width: isActive ? 1.5 : 1.0
                    border.color: isActive ? Theme.accentLit : (modeMouse.containsMouse ? Theme.accent : Theme.outline)

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.icon
                            font.family: Theme.fontIcon
                            font.pixelSize: 20
                            color: modeCard.isActive ? Theme.accentLit : (modeMouse.containsMouse ? Theme.fg : Theme.fgDim)
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(8.5)
                            font.weight: Font.Bold
                            color: modeCard.isActive ? Theme.accentLit : Theme.fg
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.sub
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(7)
                            color: modeCard.isActive ? Theme.accent : Theme.fgDim
                        }
                    }

                    MouseArea {
                        id: modeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setProfile(modelData.id)
                    }
                }
            }
        }
    }
}
