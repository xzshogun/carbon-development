import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../components"
import "../Singletons"

/**
 * AudioDevicePicker.qml
 *
 * Dedicated Audio Output & Input Device and Route Selector for Carbon Shell.
 * Provides full control over:
 *   - ALSA Output Routes (Speakers, Headphones)
 *   - PipeWire Output Devices / Sinks (Built-in, USB, Bluetooth, HDMI)
 *   - ALSA Input Routes (Internal Mic, Headset Mic)
 *   - PipeWire Input Devices / Sources
 *   - Master and Microphone Volume Sliders
 *   - Application Streams Volume
 */
Item {
    id: root

    property int activeTab: 0 // 0: Outputs, 1: Inputs
    signal backRequested()

    readonly property bool pwReady: Pipewire.ready
    readonly property var allNodes: pwReady ? Pipewire.nodes.values : []
    readonly property var sinks: allNodes.filter(n => n.audio && !n.isStream
        && (n.properties["media.class"] === "Audio/Sink" || (n.isSink && !n.properties["media.class"]))
        && !/virtual|null|stream/i.test(String(n.properties["media.class"] || n.properties["node.name"] || n.name || "")))
    readonly property var sources: allNodes.filter(n => n.audio && !n.isStream
        && (n.properties["media.class"] === "Audio/Source" || ((n.type & PwNodeType.Flag.Source) !== 0 && !n.properties["media.class"]))
        && !/monitor|virtual|null|stream/i.test(String(n.properties["media.class"] || n.properties["node.name"] || n.name || "")))

    readonly property var defaultSink: pwReady ? Pipewire.defaultAudioSink : null
    readonly property var defaultSource: pwReady ? Pipewire.defaultAudioSource : null

    PwNodeLinkTracker {
        id: linkTracker
        node: root.defaultSink
    }

    readonly property var streams: linkTracker.linkGroups

    PwObjectTracker {
        objects: [ root.defaultSink, root.defaultSource ].filter(n => n !== null)
    }

    function nodeName(n) {
        if (!n) return "Default Audio Output";
        const props = n.properties || {};
        const alsaChip = String(props["alsa.name"] || props["alsa.mixer_name"] || props["alsa.card_name"] || "");
        const desc = String(props["node.description"] || n.description || props["device.description"] || n.nickname || "");
        if (desc && desc.trim() !== "" && desc !== "?") {
            if (alsaChip && !desc.toLowerCase().includes(alsaChip.toLowerCase())) {
                return desc.trim() + " (" + alsaChip.trim() + ")";
            }
            return desc.trim();
        }
        if (alsaChip) return alsaChip;
        const app = String(props["application.name"] || props["application.process.binary"] || "");
        if (app && app.trim() !== "" && app !== "?") return app.trim();
        return String(n.name || "Audio Device");
    }

    /* ============ Output ports (speakers / headphones ALSA routes) ============ */
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
                { name: "analog-output-speaker", desc: "Speakers" },
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
        portSettleTimer.restart()
    }

    /* ============ Input ports (headset / internal mic ALSA routes) ============ */
    property var inputPorts: []
    property string activeInputPort: ""
    property string sourceCardName: ""

    Process {
        id: srcProc
        command: ["pactl", "list", "sources"]
        stdout: StdioCollector {
            id: srcCollector
            waitForEnd: true
        }
        onExited: (code, status) => root.parseSources(srcCollector.text)
    }

    Process {
        id: cardProc
        command: ["pactl", "list", "cards"]
        stdout: StdioCollector {
            id: cardCollector
            waitForEnd: true
        }
        onExited: (code, status) => root.parseCardPorts(cardCollector.text)
    }

    Timer {
        id: portSettleTimer
        interval: 900
        onTriggered: {
            root.refreshOutputPorts()
            root.refreshInputPorts()
        }
    }

    function refreshInputPorts() {
        if (!root.pwReady || !root.defaultSource) return
        root.activeInputPort = ""
        if (!srcProc.running) srcProc.running = true
        if (!cardProc.running) cardProc.running = true
    }

    function parseSources(text) {
        const name = root.defaultSource ? root.defaultSource.name : ""
        if (!name) { root.sourceCardName = ""; return }
        for (const block of String(text).split(/\r?\nSource #/)) {
            const nm = /^\tName: (.+)$/m.exec(block)
            if (!nm || nm[1] !== name) continue
            const port = /^\s*Active Port: (.+)$/m.exec(block)
            root.activeInputPort = port ? port[1] : ""
            const card = /^\s*device\.name = "(.+)"$/m.exec(block)
            root.sourceCardName = card ? card[1] : ""
            return
        }
        root.sourceCardName = ""
    }

    function parseCardPorts(text) {
        if (!root.sourceCardName) return
        for (const block of String(text).split(/\r?\nCard #/)) {
            const nm = /^\tName: (.+)$/m.exec(block)
            if (!nm || nm[1] !== root.sourceCardName) continue
            const re = /^\t\t([a-z0-9][a-z0-9-]*)\s*:\s*(.+?)\s*\(type:\s*(Mic|Headset),/gm
            const out = []
            let m
            while ((m = re.exec(block))) out.push({ name: m[1], desc: m[2].trim() })
            root.inputPorts = out
            return
        }
    }

    function selectInputPort(portName) {
        if (!root.defaultSource) return
        Quickshell.execDetached(["pactl", "set-source-port", root.defaultSource.name, portName])
        root.activeInputPort = portName
        portSettleTimer.restart()
    }

    function refreshAll() {
        root.refreshOutputPorts()
        root.refreshInputPorts()
    }

    Component.onCompleted: {
        root.refreshAll()
    }

    /* ── Main Layout ── */
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        /* ── Header: Back button, Title & Mode Tabs ── */
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: backHov.containsMouse ? (Theme.isDark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.10)) : "transparent"
                border.width: 1
                border.color: backHov.containsMouse ? Theme.accent : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    font.family: Theme.fontIcon
                    font.pixelSize: 15
                    color: backHov.containsMouse ? Theme.accent : Theme.fg
                }

                MouseArea {
                    id: backHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Sound Options"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                Text {
                    text: root.activeTab === 0 ? "Output devices & ports" : "Input devices & ports"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(7.5)
                    color: Theme.fgDim
                }
            }

            /* Pill Tab Switcher: Outputs | Inputs */
            Rectangle {
                height: 28
                radius: 14
                color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
                Layout.preferredWidth: 140

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    // Outputs tab
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: root.activeTab === 0 ? Theme.accent : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                text: "volume_up"
                                font.family: Theme.fontIcon
                                font.pixelSize: 12
                                color: root.activeTab === 0 ? (Theme.isDark ? "#101116" : "#ffffff") : Theme.fgDim
                            }
                            Text {
                                text: "Out"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(7.5)
                                font.weight: root.activeTab === 0 ? Font.Bold : Font.Normal
                                color: root.activeTab === 0 ? (Theme.isDark ? "#101116" : "#ffffff") : Theme.fgDim
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeTab = 0
                                root.refreshOutputPorts()
                            }
                        }
                    }

                    // Inputs tab
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: root.activeTab === 1 ? Theme.accent : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                text: "mic"
                                font.family: Theme.fontIcon
                                font.pixelSize: 12
                                color: root.activeTab === 1 ? (Theme.isDark ? "#101116" : "#ffffff") : Theme.fgDim
                            }
                            Text {
                                text: "In"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(7.5)
                                font.weight: root.activeTab === 1 ? Font.Bold : Font.Normal
                                color: root.activeTab === 1 ? (Theme.isDark ? "#101116" : "#ffffff") : Theme.fgDim
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeTab = 1
                                root.refreshInputPorts()
                            }
                        }
                    }
                }
            }
        }

        /* ── Master Slider & Current Route Card ── */
        Rectangle {
            Layout.fillWidth: true
            height: 48
            radius: 12
            color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
            border.width: 1
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // Mute icon button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: {
                        if (root.activeTab === 0) {
                            return (root.defaultSink && root.defaultSink.audio && root.defaultSink.audio.muted)
                                ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.2)
                                : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                        } else {
                            return (root.defaultSource && root.defaultSource.audio && root.defaultSource.audio.muted)
                                ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.2)
                                : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (root.activeTab === 0) {
                                return (root.defaultSink && root.defaultSink.audio && root.defaultSink.audio.muted) ? "volume_off" : "volume_up"
                            } else {
                                return (root.defaultSource && root.defaultSource.audio && root.defaultSource.audio.muted) ? "mic_off" : "mic"
                            }
                        }
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: {
                            if (root.activeTab === 0) {
                                return (root.defaultSink && root.defaultSink.audio && root.defaultSink.audio.muted) ? Theme.err : Theme.accent
                            } else {
                                return (root.defaultSource && root.defaultSource.audio && root.defaultSource.audio.muted) ? Theme.err : Theme.accent
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activeTab === 0 && root.defaultSink && root.defaultSink.audio) {
                                root.defaultSink.audio.muted = !root.defaultSink.audio.muted
                            } else if (root.activeTab === 1 && root.defaultSource && root.defaultSource.audio) {
                                root.defaultSource.audio.muted = !root.defaultSource.audio.muted
                            }
                        }
                    }
                }

                // Title + Volume Track
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (root.activeTab === 0) {
                                return root.defaultSink ? root.nodeName(root.defaultSink) : "No output sink"
                            } else {
                                return root.defaultSource ? root.nodeName(root.defaultSource) : "No input source"
                            }
                        }
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(8.5)
                        font.weight: Font.Bold
                        color: Theme.fg
                        elide: Text.ElideRight
                    }

                    Item {
                        id: topVolTrack
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14

                        readonly property real curRatio: {
                            if (root.activeTab === 0) {
                                return (root.defaultSink && root.defaultSink.audio) ? root.defaultSink.audio.volume : 0
                            } else {
                                return (root.defaultSource && root.defaultSource.audio) ? root.defaultSource.audio.volume : 0
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 7
                            color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
                        }

                        Rectangle {
                            height: parent.height
                            width: Math.max(0, Math.min(parent.width, parent.width * topVolTrack.curRatio))
                            radius: 7
                            color: Theme.accent
                            Behavior on width {
                                enabled: !topVolMouse.pressed
                                NumberAnimation { duration: 100 }
                            }
                        }

                        MouseArea {
                            id: topVolMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function applyVol(mx) {
                                const r = Math.max(0, Math.min(1.0, mx / topVolTrack.width))
                                if (root.activeTab === 0 && root.defaultSink && root.defaultSink.audio) {
                                    root.defaultSink.audio.volume = r
                                    if (root.defaultSink.audio.muted && r > 0) root.defaultSink.audio.muted = false
                                } else if (root.activeTab === 1 && root.defaultSource && root.defaultSource.audio) {
                                    root.defaultSource.audio.volume = r
                                    if (root.defaultSource.audio.muted && r > 0) root.defaultSource.audio.muted = false
                                }
                            }

                            onPressed: mouse => applyVol(mouse.x)
                            onPositionChanged: mouse => { if (pressed) applyVol(mouse.x) }
                        }
                    }
                }

                Text {
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignRight
                    text: {
                        const r = topVolTrack.curRatio
                        return Math.round(r * 100) + "%"
                    }
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(7.5)
                    font.weight: Font.Bold
                    color: Theme.fgDim
                }
            }
        }

        /* ── Scrollable Body: Outputs or Inputs ── */
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: contentCol.height
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                target: flick
                orientation: Qt.Vertical
                onWheel: (event) => {
                    const dy = event.angleDelta.y
                    flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - dy))
                }
            }

            Column {
                id: contentCol
                width: flick.width
                spacing: 8

                /* ========================================================= */
                /* =============== TAB 0: OUTPUTS & DEVICES =============== */
                /* ========================================================= */
                Column {
                    width: parent.width
                    visible: root.activeTab === 0
                    spacing: 6

                    /* 1. Outputs (ALSA sink ports: Speakers, Headphones) */
                    Text {
                        visible: root.outputPorts.length > 0
                        width: parent.width
                        text: "Outputs"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(9)
                        font.weight: Font.Bold
                        color: Theme.fgDim
                    }

                    Column {
                        width: parent.width
                        visible: root.outputPorts.length > 0
                        spacing: 4

                        Repeater {
                            model: root.outputPorts
                            delegate: Rectangle {
                                id: portCard
                                required property var modelData
                                readonly property bool isActive: root.activeOutputPort === modelData.name
                                width: contentCol.width
                                height: 32
                                radius: 8
                                color: isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : (portMouse.containsMouse ? Theme.bgHover : "transparent")
                                border.width: 1
                                border.color: isActive ? Theme.accent : (portMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2))

                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 14
                                        Layout.preferredHeight: 14
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: 7
                                        color: isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : "transparent"
                                        border.width: 1.5
                                        border.color: isActive ? Theme.accent : Theme.fgFaint

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 6
                                            height: 6
                                            radius: 3
                                            color: Theme.accent
                                            visible: isActive
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: /headphone|headset/i.test(modelData.desc || modelData.name) ? "headphones" : "volume_up"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 14
                                        color: isActive ? Theme.accent : Theme.fgDim
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        text: modelData.desc
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(9.5)
                                        font.weight: isActive ? Font.DemiBold : Font.Normal
                                        color: isActive ? Theme.fg : Theme.fgDim
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: isActive
                                        text: "check"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 13
                                        color: Theme.accent
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

                    /* 2. Output Devices (PipeWire sinks) */
                    Text {
                        visible: root.sinks.length > 0
                        width: parent.width
                        text: "Devices"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(9)
                        font.weight: Font.Bold
                        color: Theme.fgDim
                    }

                    Column {
                        width: parent.width
                        visible: root.sinks.length > 0
                        spacing: 4

                        Repeater {
                            model: root.sinks
                            delegate: Rectangle {
                                id: sinkCard
                                required property var modelData
                                readonly property var node: modelData
                                readonly property bool isCurDefault: root.defaultSink && root.defaultSink.id === node.id
                                width: contentCol.width
                                height: 32
                                radius: 8
                                color: isCurDefault ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : (sinkMouse.containsMouse ? Theme.bgHover : "transparent")
                                border.width: 1
                                border.color: isCurDefault ? Theme.accent : (sinkMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2))

                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 14
                                        Layout.preferredHeight: 14
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: 7
                                        color: isCurDefault ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : "transparent"
                                        border.width: 1.5
                                        border.color: isCurDefault ? Theme.accent : Theme.fgFaint

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 6
                                            height: 6
                                            radius: 3
                                            color: Theme.accent
                                            visible: isCurDefault
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: {
                                            const nm = (node.name || "") + (node.description || "")
                                            if (/bluez|bluetooth/i.test(nm)) return "bluetooth_audio"
                                            if (/hdmi/i.test(nm)) return "tv"
                                            if (/headphone|headset/i.test(nm)) return "headphones"
                                            return "volume_up"
                                        }
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 14
                                        color: isCurDefault ? Theme.accent : Theme.fgDim
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        text: root.nodeName(node)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(9.5)
                                        font.weight: isCurDefault ? Font.DemiBold : Font.Normal
                                        color: isCurDefault ? Theme.fg : Theme.fgDim
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: isCurDefault
                                        text: "check"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 13
                                        color: Theme.accent
                                    }
                                }

                                MouseArea {
                                    id: sinkMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Pipewire.preferredDefaultAudioSink = node
                                        Quickshell.execDetached(["wpctl", "set-default", String(node.id)])
                                    }
                                }
                            }
                        }
                    }

                    /* 3. Application Streams */
                    Text {
                        visible: root.streams.length > 0
                        width: parent.width
                        text: "Applications"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(9)
                        font.weight: Font.Bold
                        color: Theme.fgDim
                    }

                    Repeater {
                        model: root.streams
                        delegate: RowLayout {
                            required property var modelData
                            readonly property var node: modelData.source
                            width: contentCol.width
                            spacing: 8

                            PwObjectTracker { objects: [node] }

                            IconButton {
                                id: sMute
                                glyph: node.audio.muted ? "volume_off" : "volume_down"
                                tip: "Mute app"
                                size: 14
                                color: Theme.fg
                                pointer: true
                                onClicked: node.audio.muted = !node.audio.muted
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                text: root.nodeName(node)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(9.5)
                                color: node.muted ? Theme.fgFaint : Theme.fg
                                elide: Text.ElideRight
                            }

                            VolSlider {
                                Layout.preferredWidth: 78
                                active: true
                                value: node.audio.volume
                                fill: Theme.accent
                                track: Theme.fgFaint
                                knob: Theme.fg
                                onChanged: (v) => node.audio.volume = v
                            }
                        }
                    }
                }

                /* ========================================================= */
                /* ================ TAB 1: INPUTS & DEVICES ================ */
                /* ========================================================= */
                Column {
                    width: parent.width
                    visible: root.activeTab === 1
                    spacing: 6

                    /* 1. Inputs (ALSA source ports: Internal Mic, Headset Mic) */
                    Text {
                        visible: root.inputPorts.length > 0
                        width: parent.width
                        text: "Inputs"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(9)
                        font.weight: Font.Bold
                        color: Theme.fgDim
                    }

                    Column {
                        width: parent.width
                        visible: root.inputPorts.length > 0
                        spacing: 4

                        Repeater {
                            model: root.inputPorts
                            delegate: Rectangle {
                                id: inPortCard
                                required property var modelData
                                readonly property bool isActive: root.activeInputPort === modelData.name
                                width: contentCol.width
                                height: 32
                                radius: 8
                                color: isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : (inPortMouse.containsMouse ? Theme.bgHover : "transparent")
                                border.width: 1
                                border.color: isActive ? Theme.accent : (inPortMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2))

                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 14
                                        Layout.preferredHeight: 14
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: 7
                                        color: isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : "transparent"
                                        border.width: 1.5
                                        border.color: isActive ? Theme.accent : Theme.fgFaint

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 6
                                            height: 6
                                            radius: 3
                                            color: Theme.accent
                                            visible: isActive
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: /headset|headphone/i.test(modelData.desc || modelData.name) ? "headphones" : "mic"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 14
                                        color: isActive ? Theme.accent : Theme.fgDim
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        text: modelData.desc
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(9.5)
                                        font.weight: isActive ? Font.DemiBold : Font.Normal
                                        color: isActive ? Theme.fg : Theme.fgDim
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: isActive
                                        text: "check"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 13
                                        color: Theme.accent
                                    }
                                }

                                MouseArea {
                                    id: inPortMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectInputPort(modelData.name)
                                }
                            }
                        }
                    }

                    /* 2. Input Devices (PipeWire sources) */
                    Text {
                        visible: root.sources.length > 0
                        width: parent.width
                        text: "Devices"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(9)
                        font.weight: Font.Bold
                        color: Theme.fgDim
                    }

                    Column {
                        width: parent.width
                        visible: root.sources.length > 0
                        spacing: 4

                        Repeater {
                            model: root.sources
                            delegate: Rectangle {
                                id: srcCard
                                required property var modelData
                                readonly property var node: modelData
                                readonly property bool isCurDefault: root.defaultSource === node
                                width: contentCol.width
                                height: 32
                                radius: 8
                                color: isCurDefault ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : (srcMouse.containsMouse ? Theme.bgHover : "transparent")
                                border.width: 1
                                border.color: isCurDefault ? Theme.accent : (srcMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2))

                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 14
                                        Layout.preferredHeight: 14
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: 7
                                        color: isCurDefault ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : "transparent"
                                        border.width: 1.5
                                        border.color: isCurDefault ? Theme.accent : Theme.fgFaint

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 6
                                            height: 6
                                            radius: 3
                                            color: Theme.accent
                                            visible: isCurDefault
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: {
                                            const nm = (node.name || "") + (node.description || "")
                                            if (/headset|headphone/i.test(nm)) return "headphones"
                                            if (/bluez|bluetooth/i.test(nm)) return "bluetooth"
                                            return "mic"
                                        }
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 14
                                        color: isCurDefault ? Theme.accent : Theme.fgDim
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        text: root.nodeName(node)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(9.5)
                                        font.weight: isCurDefault ? Font.DemiBold : Font.Normal
                                        color: isCurDefault ? Theme.fg : Theme.fgDim
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: isCurDefault
                                        text: "check"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 13
                                        color: Theme.accent
                                    }
                                }

                                MouseArea {
                                    id: srcMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Pipewire.preferredDefaultAudioSource = node
                                        Quickshell.execDetached(["wpctl", "set-default", String(node.id)])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
