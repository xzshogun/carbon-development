import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../Singletons"
import "../components"

Item {
    id: root

    implicitWidth: 800
    implicitHeight: 600

    readonly property bool pwReady: Pipewire.ready

    // PipeWire Sink & Source Node Filtering
    readonly property var allNodes: pwReady ? Pipewire.nodes.values : []
    readonly property var sinks: allNodes.filter(n => n.audio && !n.isStream
        && (n.properties["media.class"] === "Audio/Sink" || (n.isSink && !n.properties["media.class"]))
        && !/virtual|null|stream/i.test(String(n.properties["media.class"] || n.properties["node.name"] || n.name || "")))
    readonly property var sources: allNodes.filter(n => n.audio && !n.isStream
        && (n.properties["media.class"] === "Audio/Source" || ((n.type & PwNodeType.Flag.Source) !== 0 && !n.properties["media.class"]))
        && !/monitor|virtual|null|stream/i.test(String(n.properties["media.class"] || n.properties["node.name"] || n.name || "")))

    readonly property var defaultSink: pwReady ? Pipewire.defaultAudioSink : null
    readonly property var defaultSource: pwReady ? Pipewire.defaultAudioSource : null

    // Track application streams routed to default sink
    PwNodeLinkTracker {
        id: linkTracker
        node: root.defaultSink
    }
    readonly property var streams: linkTracker.linkGroups

    // Keep live audio state bound for default sink & source
    PwObjectTracker {
        objects: [ root.defaultSink, root.defaultSource ].filter(n => n !== null)
    }

    // ALSA Route / Port Detection
    property var outputPorts: []
    property string activeOutputPort: ""

    Process {
        id: sinkProc
        command: ["pactl", "list", "sinks"]
        stdout: StdioCollector {
            id: sinkCollector
            waitForEnd: true
        }
        onExited: (code, status) => root.parseSinks(sinkCollector.text)
    }

    function refreshOutputPorts() {
        if (!root.pwReady || !root.defaultSink) return
        root.activeOutputPort = ""
        if (!sinkProc.running) sinkProc.running = true
    }

    function parseSinks(text) {
        const name = root.defaultSink ? String(root.defaultSink.name || "") : ""
        let foundPorts = []
        for (const block of String(text).split(/\r?\nSink #/)) {
            const nm = /^\tName: (.+)$/m.exec(block)
            if (name && nm && nm[1] !== name) continue
            const port = /^\s*Active Port: (.+)$/m.exec(block)
            if (port) root.activeOutputPort = port[1].trim()
            const portSection = block.split(/\r?\n\tPorts:\r?\n/)[1]
            if (portSection) {
                const portsText = portSection.split(/\r?\n\tActive Port:/)[0]
                const re = /^\t\t([a-z0-9_.-]+)\s*:\s*([^(]+?)(?:\s*\((.*)\))?$/gmi
                let m
                while ((m = re.exec(portsText))) {
                    const pName = m[1].trim()
                    let pDesc = m[2].trim()
                    if (pDesc.length === 0) pDesc = pName
                    foundPorts.push({ name: pName, desc: pDesc })
                }
                if (foundPorts.length > 0) break
            }
        }
        if (foundPorts.length === 0 && name.includes("analog")) {
            foundPorts = [
                { name: "analog-output-speaker", desc: "Built-in Speakers" },
                { name: "analog-output-headphones", desc: "Headphones" }
            ]
        }
        root.outputPorts = foundPorts
    }

    function selectOutputPort(portName) {
        if (!root.defaultSink) return
        Quickshell.execDetached(["pactl", "set-sink-port", root.defaultSink.name, portName])
        Quickshell.execDetached(["amixer", "-q", "sset", "Master", "unmute"])
        if (/speaker/i.test(portName)) {
            Quickshell.execDetached(["amixer", "-q", "sset", "Speaker", "unmute", "100%"])
        } else if (/headphone/i.test(portName)) {
            Quickshell.execDetached(["amixer", "-q", "sset", "Headphone", "unmute", "100%"])
        }
        root.activeOutputPort = portName
        refreshOutputPorts()
    }

    function nodeDisplayName(n) {
        if (!n) return "Default Audio Device"
        const props = n.properties || {}
        const desc = String(props["node.description"] || n.description || props["device.description"] || n.nickname || "")
        if (desc && desc.trim() !== "" && desc !== "?") return desc.trim()
        const alsaChip = String(props["alsa.name"] || props["alsa.mixer_name"] || props["alsa.card_name"] || "")
        if (alsaChip) return alsaChip
        const app = String(props["application.name"] || props["application.process.binary"] || "")
        if (app && app.trim() !== "" && app !== "?") return app.trim()
        return String(n.name || "Audio Device")
    }

    Component.onCompleted: {
        root.refreshOutputPorts()
    }

    // Scrollable Settings Layout
    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight + Theme.px(48)
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.px(24)
            anchors.rightMargin: Theme.px(24)
            anchors.topMargin: Theme.px(20)
            spacing: Theme.px(20)

            // =================================================================
            // 1. HERO BANNER: PIPEWIRE MATRIX & DYNAMIC SPECTRUM
            // =================================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.px(90)
                radius: Theme.px(12)
                color: Qt.rgba(0, 0, 0, 0.30)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.px(16)
                    spacing: Theme.px(16)

                    // Audio Core Icon with subtle halo
                    Rectangle {
                        Layout.preferredWidth: Theme.px(54)
                        Layout.preferredHeight: Theme.px(54)
                        radius: Theme.px(10)
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰓃"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(26)
                            color: Theme.primary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(3)

                        RowLayout {
                            spacing: Theme.px(8)

                            Text {
                                text: "PIPEWIRE AUDIO ENGINE"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(14)
                                font.weight: Font.Bold
                                color: Qt.rgba(1, 1, 1, 0.95)
                            }

                            Rectangle {
                                Layout.preferredWidth: Theme.px(64)
                                Layout.preferredHeight: Theme.px(18)
                                radius: Theme.px(9)
                                color: (root.defaultSink && !root.defaultSink.audio.muted) ? Qt.rgba(0.2, 0.8, 0.4, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                                border.color: (root.defaultSink && !root.defaultSink.audio.muted) ? Qt.rgba(0.2, 0.8, 0.4, 0.5) : Qt.rgba(1, 1, 1, 0.15)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: (root.defaultSink && !root.defaultSink.audio.muted) ? "● ACTIVE" : "○ MUTED"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(9)
                                    font.weight: Font.Bold
                                    color: (root.defaultSink && !root.defaultSink.audio.muted) ? "#55FF99" : Qt.rgba(1, 1, 1, 0.5)
                                }
                            }
                        }

                        Text {
                            text: root.defaultSink ? root.nodeDisplayName(root.defaultSink) : "Scanning audio subsystem..."
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(11)
                            color: Qt.rgba(1, 1, 1, 0.55)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Tactile Fluid Equalizer / Spectrum Visualizer
                    Row {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Theme.px(3)

                        Repeater {
                            model: 18

                            delegate: Rectangle {
                                id: specBar
                                required property int index
                                width: Theme.px(3)
                                radius: 1.5

                                readonly property bool isAudioActive: (root.defaultSink && root.defaultSink.audio && !root.defaultSink.audio.muted && root.defaultSink.audio.volume > 0)
                                property real targetHeight: 4

                                height: targetHeight
                                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                                color: {
                                    if (!isAudioActive) return Qt.rgba(1, 1, 1, 0.12)
                                    var norm = index / 18.0
                                    return (norm > 0.8) ? "#FF5577" : ((norm > 0.6) ? "#FFAA33" : Theme.primary)
                                }

                                Timer {
                                    interval: 100 + (specBar.index * 15)
                                    running: true
                                    repeat: true
                                    onTriggered: {
                                        if (specBar.isAudioActive) {
                                            var base = Math.sin(Date.now() / 200.0 + specBar.index * 0.6) * 0.5 + 0.5
                                            specBar.targetHeight = Math.max(4, Math.round(base * 32 * (root.defaultSink.audio.volume || 0.5)))
                                        } else {
                                            specBar.targetHeight = 4
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // 2. MASTER OUTPUT SECTION
            // =================================================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: masterOutputCol.implicitHeight + Theme.px(28)
                radius: Theme.px(12)
                color: Qt.rgba(0, 0, 0, 0.22)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                ColumnLayout {
                    id: masterOutputCol
                    anchors.fill: parent
                    anchors.margins: Theme.px(16)
                    spacing: Theme.px(14)

                    // Header Row
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "MASTER AUDIO OUTPUT"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(12)
                            font.weight: Font.Bold
                            color: Qt.rgba(1, 1, 1, 0.90)
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: {
                                if (!root.defaultSink || !root.defaultSink.audio) return "0%"
                                if (root.defaultSink.audio.muted) return "MUTED"
                                return Math.round(root.defaultSink.audio.volume * 100) + "%"
                            }
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(12)
                            font.weight: Font.Bold
                            color: (root.defaultSink && root.defaultSink.audio && root.defaultSink.audio.muted) ? "#FF6666" : Theme.primary
                        }
                    }

                    // Output Route / Devices Selector Chips
                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.px(8)

                        // 1. Sinks from PipeWire
                        Repeater {
                            model: root.sinks

                            delegate: Rectangle {
                                id: sinkChip
                                required property var modelData
                                readonly property bool isSelected: (root.defaultSink && root.defaultSink.id === modelData.id)

                                width: chipRow.implicitWidth + Theme.px(20)
                                height: Theme.px(34)
                                radius: Theme.px(8)
                                color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                                border.color: isSelected ? Theme.primary : (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08))
                                border.width: 1
                                scale: chipMouse.pressed ? 0.97 : (chipMouse.containsMouse ? 1.02 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 120 } }

                                RowLayout {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: Theme.px(8)

                                    Text {
                                        text: {
                                            var name = root.nodeDisplayName(modelData).toLowerCase()
                                            if (name.includes("headphone") || name.includes("headset")) return "󰋋"
                                            if (name.includes("hdmi") || name.includes("displayport")) return "󰡁"
                                            if (name.includes("bluez") || name.includes("bluetooth")) return "󰂯"
                                            return "󰓃"
                                        }
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(14)
                                        color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.6)
                                    }

                                    Text {
                                        text: root.nodeDisplayName(modelData)
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(11)
                                        font.weight: isSelected ? Font.DemiBold : Font.Normal
                                        color: isSelected ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.70)
                                    }
                                }

                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["wpctl", "set-default", String(modelData.id)])
                                    }
                                }
                            }
                        }

                        // 2. Hardware Ports (Speakers / Headphones on current sink)
                        Repeater {
                            model: root.outputPorts

                            delegate: Rectangle {
                                id: portChip
                                required property var modelData
                                readonly property bool isPortActive: (root.activeOutputPort === modelData.name)

                                width: portRow.implicitWidth + Theme.px(20)
                                height: Theme.px(34)
                                radius: Theme.px(8)
                                color: isPortActive ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : (portMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                                border.color: isPortActive ? Theme.primary : (portMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08))
                                border.width: 1
                                scale: portMouse.pressed ? 0.97 : (portMouse.containsMouse ? 1.02 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 120 } }

                                RowLayout {
                                    id: portRow
                                    anchors.centerIn: parent
                                    spacing: Theme.px(8)

                                    Text {
                                        text: /headphone/i.test(modelData.name) ? "󰋋" : "󰓃"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(14)
                                        color: isPortActive ? Theme.primary : Qt.rgba(1, 1, 1, 0.6)
                                    }

                                    Text {
                                        text: modelData.desc
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(11)
                                        font.weight: isPortActive ? Font.DemiBold : Font.Normal
                                        color: isPortActive ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.70)
                                    }
                                }

                                MouseArea {
                                    id: portMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectOutputPort(modelData.name)
                                }
                            }
                        }
                    }

                    // Master Volume Slider & Mute Button
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(12)

                        // Mute / Unmute Button
                        Rectangle {
                            Layout.preferredWidth: Theme.px(42)
                            Layout.preferredHeight: Theme.px(42)
                            radius: Theme.px(8)
                            color: (root.defaultSink && root.defaultSink.audio && root.defaultSink.audio.muted) ? Qt.rgba(1, 0.2, 0.2, 0.2) : (muteMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                            border.color: (root.defaultSink && root.defaultSink.audio && root.defaultSink.audio.muted) ? "#FF5555" : (muteMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10))
                            border.width: 1
                            scale: muteMouse.pressed ? 0.95 : 1.0

                            Text {
                                anchors.centerIn: parent
                                text: (root.defaultSink && root.defaultSink.audio && root.defaultSink.audio.muted) ? "󰝟" : "󰕾"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(16)
                                color: (root.defaultSink && root.defaultSink.audio && root.defaultSink.audio.muted) ? "#FF6666" : Theme.primary
                            }

                            MouseArea {
                                id: muteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.defaultSink && root.defaultSink.audio) {
                                        root.defaultSink.audio.muted = !root.defaultSink.audio.muted
                                    } else {
                                        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                                    }
                                }
                            }
                        }

                        // RazorWire Slider for Master Volume
                        RazorWireSlider {
                            Layout.fillWidth: true
                            label: "Master Output Level"
                            from: 0.0
                            to: 1.0
                            stepSize: 0.01
                            decimals: 0
                            unit: "%"
                            value: (root.defaultSink && root.defaultSink.audio) ? root.defaultSink.audio.volume : 0.5
                            onMoved: (val) => {
                                if (root.defaultSink && root.defaultSink.audio) {
                                    root.defaultSink.audio.volume = val
                                }
                            }
                        }
                    }

                    // Quick Volume Preset Buttons
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(8)

                        Repeater {
                            model: [
                                { label: "25%", val: 0.25 },
                                { label: "50%", val: 0.50 },
                                { label: "75%", val: 0.75 },
                                { label: "100%", val: 1.00 }
                            ]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.px(28)
                                radius: Theme.px(6)
                                color: preMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(1, 1, 1, 0.04)
                                border.color: preMouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(10)
                                    color: preMouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.75)
                                }

                                MouseArea {
                                    id: preMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.defaultSink && root.defaultSink.audio) {
                                            root.defaultSink.audio.volume = modelData.val
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // 3. MASTER INPUT (MICROPHONE) SECTION
            // =================================================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: masterInputCol.implicitHeight + Theme.px(28)
                radius: Theme.px(12)
                color: Qt.rgba(0, 0, 0, 0.22)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                ColumnLayout {
                    id: masterInputCol
                    anchors.fill: parent
                    anchors.margins: Theme.px(16)
                    spacing: Theme.px(14)

                    // Header Row
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "INPUT SOURCE & SENSITIVITY"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(12)
                            font.weight: Font.Bold
                            color: Qt.rgba(1, 1, 1, 0.90)
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: {
                                if (!root.defaultSource || !root.defaultSource.audio) return "0%"
                                if (root.defaultSource.audio.muted) return "MUTED"
                                return Math.round(root.defaultSource.audio.volume * 100) + "%"
                            }
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(12)
                            font.weight: Font.Bold
                            color: (root.defaultSource && root.defaultSource.audio && root.defaultSource.audio.muted) ? "#FF6666" : Theme.primary
                        }
                    }

                    // Input Sources Chips
                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.px(8)

                        Repeater {
                            model: root.sources

                            delegate: Rectangle {
                                id: srcChip
                                required property var modelData
                                readonly property bool isSelected: (root.defaultSource && root.defaultSource.id === modelData.id)

                                width: srcRow.implicitWidth + Theme.px(20)
                                height: Theme.px(34)
                                radius: Theme.px(8)
                                color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : (srcMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                                border.color: isSelected ? Theme.primary : (srcMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08))
                                border.width: 1

                                RowLayout {
                                    id: srcRow
                                    anchors.centerIn: parent
                                    spacing: Theme.px(8)

                                    Text {
                                        text: "󰍬"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(14)
                                        color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.6)
                                    }

                                    Text {
                                        text: root.nodeDisplayName(modelData)
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(11)
                                        font.weight: isSelected ? Font.DemiBold : Font.Normal
                                        color: isSelected ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.70)
                                    }
                                }

                                MouseArea {
                                    id: srcMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["wpctl", "set-default", String(modelData.id)])
                                    }
                                }
                            }
                        }
                    }

                    // Mic Volume & Mute Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(12)

                        // Mic Mute Button
                        Rectangle {
                            Layout.preferredWidth: Theme.px(42)
                            Layout.preferredHeight: Theme.px(42)
                            radius: Theme.px(8)
                            color: (root.defaultSource && root.defaultSource.audio && root.defaultSource.audio.muted) ? Qt.rgba(1, 0.2, 0.2, 0.2) : (micMuteMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                            border.color: (root.defaultSource && root.defaultSource.audio && root.defaultSource.audio.muted) ? "#FF5555" : (micMuteMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10))
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: (root.defaultSource && root.defaultSource.audio && root.defaultSource.audio.muted) ? "󰍭" : "󰍬"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(16)
                                color: (root.defaultSource && root.defaultSource.audio && root.defaultSource.audio.muted) ? "#FF6666" : Theme.primary
                            }

                            MouseArea {
                                id: micMuteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.defaultSource && root.defaultSource.audio) {
                                        root.defaultSource.audio.muted = !root.defaultSource.audio.muted
                                    } else {
                                        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
                                    }
                                }
                            }
                        }

                        // RazorWire Slider for Microphone Sensitivity
                        RazorWireSlider {
                            Layout.fillWidth: true
                            label: "Microphone Gain"
                            from: 0.0
                            to: 1.0
                            stepSize: 0.01
                            decimals: 0
                            unit: "%"
                            value: (root.defaultSource && root.defaultSource.audio) ? root.defaultSource.audio.volume : 0.8
                            onMoved: (val) => {
                                if (root.defaultSource && root.defaultSource.audio) {
                                    root.defaultSource.audio.volume = val
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // 4. APPLICATION AUDIO STREAMS MIXER
            // =================================================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: appMixerCol.implicitHeight + Theme.px(28)
                radius: Theme.px(12)
                color: Qt.rgba(0, 0, 0, 0.22)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                ColumnLayout {
                    id: appMixerCol
                    anchors.fill: parent
                    anchors.margins: Theme.px(16)
                    spacing: Theme.px(12)

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "APPLICATION AUDIO MIXER"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(12)
                            font.weight: Font.Bold
                            color: Qt.rgba(1, 1, 1, 0.90)
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.streams.length + " active stream" + (root.streams.length === 1 ? "" : "s")
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(10)
                            color: Qt.rgba(1, 1, 1, 0.40)
                        }
                    }

                    // No Active Streams Placeholder
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(50)
                        visible: root.streams.length === 0

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.px(10)

                            Text {
                                text: "󰓃"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(16)
                                color: Qt.rgba(1, 1, 1, 0.3)
                            }

                            Text {
                                text: "No active application audio streams playing right now"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(11)
                                color: Qt.rgba(1, 1, 1, 0.4)
                            }
                        }
                    }

                    // Active Stream Rows
                    Repeater {
                        model: root.streams

                        delegate: Rectangle {
                            id: streamCard
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.px(54)
                            radius: Theme.px(8)
                            color: Qt.rgba(1, 1, 1, 0.03)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.px(12)
                                anchors.rightMargin: Theme.px(12)
                                spacing: Theme.px(12)

                                // App Glyph
                                Text {
                                    text: {
                                        var app = String(modelData.name || "").toLowerCase()
                                        if (app.includes("firefox")) return "󰈹"
                                        if (app.includes("chrome") || app.includes("chromium")) return "󰊯"
                                        if (app.includes("spotify")) return "󰓇"
                                        if (app.includes("discord")) return "󰙯"
                                        if (app.includes("cava")) return "󱑽"
                                        return "󰓃"
                                    }
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(18)
                                    color: Theme.primary
                                    Layout.preferredWidth: Theme.px(24)
                                }

                                Text {
                                    text: modelData.name || "App Stream"
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(12)
                                    font.weight: Font.Medium
                                    color: Qt.rgba(1, 1, 1, 0.90)
                                    Layout.preferredWidth: Theme.px(110)
                                    elide: Text.ElideRight
                                }

                                // Stream Mute Button
                                Rectangle {
                                    Layout.preferredWidth: Theme.px(30)
                                    Layout.preferredHeight: Theme.px(30)
                                    radius: Theme.px(6)
                                    color: (modelData.audio && modelData.audio.muted) ? Qt.rgba(1, 0.2, 0.2, 0.2) : (appMuteMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                                    border.color: (modelData.audio && modelData.audio.muted) ? "#FF5555" : Qt.rgba(1, 1, 1, 0.12)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: (modelData.audio && modelData.audio.muted) ? "󰝟" : "󰕾"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(12)
                                        color: (modelData.audio && modelData.audio.muted) ? "#FF6666" : Qt.rgba(1, 1, 1, 0.70)
                                    }

                                    MouseArea {
                                        id: appMuteMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.audio) {
                                                modelData.audio.muted = !modelData.audio.muted
                                            }
                                        }
                                    }
                                }

                                // Interactive Mini Volume Slider
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Theme.px(18)

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 2
                                        radius: 1
                                        color: Qt.rgba(1, 1, 1, 0.12)
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width * Math.max(0.0, Math.min(1.0, (modelData.audio ? modelData.audio.volume : 0.5)))
                                        height: 2
                                        radius: 1
                                        color: Theme.primary
                                    }

                                    Rectangle {
                                        x: (parent.width - 10) * Math.max(0.0, Math.min(1.0, (modelData.audio ? modelData.audio.volume : 0.5)))
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: Theme.primary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onPositionChanged: (mouse) => {
                                            if (pressed && modelData.audio) {
                                                var r = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                                modelData.audio.volume = r
                                            }
                                        }
                                        onClicked: (mouse) => {
                                            if (modelData.audio) {
                                                var r = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                                modelData.audio.volume = r
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: Math.round((modelData.audio ? modelData.audio.volume : 0) * 100) + "%"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(11)
                                    color: Theme.primary
                                    Layout.preferredWidth: Theme.px(36)
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }

            // Bottom Spacing
            Item { Layout.preferredHeight: Theme.px(12) }
        }
    }
}
