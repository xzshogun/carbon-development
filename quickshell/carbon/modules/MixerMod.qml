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
 * Carbon mixer popup: a small rounded panel that sticks to the right of the
 * left bar and slides/fades in when it opens.
 *
 * Three categories, switched from the header:
 *   · speaker -> mixer: master (system) volume + per-application streams
 *   · mic     -> input: default input volume/mute + the list of input
 *                 devices with instant default-switching
 *   · sun     -> brightness: display backlight slider, backed by brightnessctl
 *
 * Volume changes are pushed live to Pipewire, brightness via brightnessctl.
 * Everything is theme-aware.
 */
Item {
    id: root

    property bool open: false
    property string barEdge: "top"
    property int view: 0
    property bool anyHover: false

    signal closeRequested()

    implicitWidth: 260
    implicitHeight: 330
    clip: true

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

    /* Apps currently routed towards the default sink (the mixer list). */
    PwNodeLinkTracker {
        id: linkTracker
        node: root.defaultSink
    }

    readonly property var streams: linkTracker.linkGroups

    /* Keep QML bindings on the live audio state of the tracked nodes. */
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
        return String(n.name || "Analog Stereo Device");
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

    /* ============ Input ports (headset / internal mic ALSA routes) ============
     * A card can expose several mics as *routes* on one PipeWire source node
     * (e.g. Internal Mic, Headset Mic). WirePlumber hides these ports, so we
     * list them from pactl and switch with set-source-port. */
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

    onViewChanged: {
        if (root.view === 0) root.refreshOutputPorts()
        else if (root.view === 1) root.refreshInputPorts()
    }

    property bool animatingOut: false
    onOpenChanged: {
        if (root.open) {
            root.view = 0
            root.refreshOutputPorts()
            root.refreshInputPorts()
            root.animatingOut = false
            animatingOutTimer.stop()
        } else {
            root.animatingOut = true
            animatingOutTimer.restart()
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
                duration: root.open ? 200 : 150
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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            anchors.leftMargin: root.barMode === "notch" ? 20 : 8
            spacing: 6

            /* ============ Header: speaker + mic ============ */
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Item {
                    id: soundTab
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    property bool active: root.view === 0

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: parent.active ? Theme.accent : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "volume_up"
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: parent.active ? "#0e0e12" : Theme.fgDim
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Behavior on color { ColorAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingStandard } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.view = 0
                    }
                }

                Item {
                    id: micTab
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    property bool active: root.view === 1

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: parent.active ? Theme.accent : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "mic"
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: parent.active ? "#0e0e12" : Theme.fgDim
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Behavior on color { ColorAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingStandard } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.view = 1
                    }
                }

                Item { Layout.fillWidth: true }

                IconButton {
                    id: closeBtn
                    glyph: "close"
                    tip: "Close"
                    size: 14
                    color: Theme.fgDim
                    hoverColor: Theme.fg
                    pointer: true
                    onClicked: root.closeRequested()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.outline
            }

            /* ============ Category 1: the mixer ============ */
            ColumnLayout {
                id: mixerPane
                visible: root.view === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    IconButton {
                        id: masterMute
                        glyph: root.defaultSink && root.defaultSink.audio.muted ? "volume_off" : "volume_up"
                        tip: "Mute system sound"
                        size: 14
                        color: Theme.fg
                        pointer: true
                        onClicked: {
                            if (root.defaultSink)
                                root.defaultSink.audio.muted = !root.defaultSink.audio.muted
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (!root.pwReady) return "Connecting to Pipewire…"
                                if (!root.defaultSink) return "No output device"
                                return root.nodeName(root.defaultSink)
                            }
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(12)
                            font.weight: Font.Bold
                            color: Theme.fg
                            elide: Text.ElideRight
                        }

                        VolSlider {
                            Layout.fillWidth: true
                            active: root.open
                            interactive: root.pwReady && !!root.defaultSink
                            value: root.defaultSink ? root.defaultSink.audio.volume : 0
                            fill: Theme.accent
                            track: Theme.fgFaint
                            knob: Theme.fg
                            onChanged: (v) => {
                                if (root.defaultSink) root.defaultSink.audio.volume = v
                            }
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: mixerContentCol.height
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        target: parent
                        orientation: Qt.Vertical
                        onWheel: (event) => {
                            const dy = event.angleDelta.y
                            parent.contentY = Math.max(0, Math.min(parent.contentHeight - parent.height, parent.contentY - dy))
                        }
                    }

                    Column {
                        id: mixerContentCol
                        width: parent.width
                        spacing: 6

                        /* Output Ports (Speakers / Headphones routes) */
                        Text {
                            visible: root.outputPorts.length > 0
                            width: parent.width
                            text: "Outputs"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(10)
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
                                    width: mixerContentCol.width
                                    height: 30
                                    radius: 8
                                    color: isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : (portMouse.containsMouse ? Theme.bgHover : "transparent")
                                    border.width: 1
                                    border.color: isActive ? Theme.accent : (portMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

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
                                            font.pixelSize: Theme.fontPx(11)
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
                                        z: 5
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectOutputPort(modelData.name)
                                        onWheel: (wheel) => { wheel.accepted = false }
                                    }
                                }
                            }
                        }

                        /* Output Devices (Sinks: Built-in, Bluetooth, USB, HDMI) */
                        Text {
                            visible: root.sinks.length > 0
                            width: parent.width
                            text: "Devices"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(10)
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
                                    width: mixerContentCol.width
                                    height: 30
                                    radius: 8
                                    color: isCurDefault ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : (sinkMouse.containsMouse ? Theme.bgHover : "transparent")
                                    border.width: 1
                                    border.color: isCurDefault ? Theme.accent : (sinkMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

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
                                            font.pixelSize: Theme.fontPx(11)
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
                                        z: 5
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Pipewire.preferredDefaultAudioSink = node
                                            Quickshell.execDetached(["wpctl", "set-default", String(node.id)])
                                        }
                                        onWheel: (wheel) => { wheel.accepted = false }
                                    }
                                }
                            }
                        }

                        /* Applications Section */
                        Text {
                            width: parent.width
                            text: "Applications"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(10)
                            font.weight: Font.Bold
                            color: Theme.fgDim
                        }

                        Repeater {
                            model: root.streams
                            delegate: RowLayout {
                                required property var modelData
                                readonly property var node: modelData.source
                                width: mixerContentCol.width
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
                                    onWheel: (w) => { w.accepted = false }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    text: root.nodeName(node)
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: Theme.fontPx(11)
                                    color: node.muted ? Theme.fgFaint : Theme.fg
                                    elide: Text.ElideRight
                                }

                                VolSlider {
                                    Layout.preferredWidth: 78
                                    active: root.open
                                    value: node.audio.volume
                                    fill: Theme.accent
                                    track: Theme.fgFaint
                                    knob: Theme.fg
                                    onChanged: (v) => node.audio.volume = v
                                }
                            }
                        }

                        Text {
                            visible: root.streams.length === 0
                            width: parent.width
                            text: "No applications playing right now"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(11)
                            color: Theme.fgDim
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: 6
                        }
                    }
                }
            }

            /* ============ Category 2: mic / input ============ */
            ColumnLayout {
                id: micPane
                visible: root.view === 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    IconButton {
                        id: srcMute
                        glyph: root.defaultSource && root.defaultSource.audio.muted ? "mic_off" : "mic"
                        tip: "Mute microphone"
                        size: 14
                        color: Theme.fg
                        pointer: true
                        onClicked: {
                            if (root.defaultSource)
                                root.defaultSource.audio.muted = !root.defaultSource.audio.muted
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (!root.pwReady) return "Connecting to Pipewire…"
                                if (!root.defaultSource) return "No input device"
                                return root.nodeName(root.defaultSource)
                            }
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(12)
                            font.weight: Font.Bold
                            color: Theme.fg
                            elide: Text.ElideRight
                        }

                        VolSlider {
                            Layout.fillWidth: true
                            active: root.open
                            interactive: root.pwReady && !!root.defaultSource
                            value: root.defaultSource ? root.defaultSource.audio.volume : 0
                            fill: Theme.accent
                            track: Theme.fgFaint
                            knob: Theme.fg
                            onChanged: (v) => {
                                if (root.defaultSource) root.defaultSource.audio.volume = v
                            }
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: sourcesCol.height
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        target: parent
                        orientation: Qt.Vertical
                        onWheel: (event) => {
                            const dy = event.angleDelta.y
                            parent.contentY = Math.max(0, Math.min(parent.contentHeight - parent.height, parent.contentY - dy))
                        }
                    }

                    Column {
                        id: sourcesCol
                        width: parent.width
                        spacing: 6

                        /* Inputs / Routes */
                        Text {
                            visible: root.inputPorts.length > 0
                            width: parent.width
                            text: "Inputs"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(10)
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
                                    width: sourcesCol.width
                                    height: 30
                                    radius: 8
                                    color: isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : (inPortMouse.containsMouse ? Theme.bgHover : "transparent")
                                    border.width: 1
                                    border.color: isActive ? Theme.accent : (inPortMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

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
                                            font.pixelSize: Theme.fontPx(11)
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
                                        z: 5
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectInputPort(modelData.name)
                                        onWheel: (wheel) => { wheel.accepted = false }
                                    }
                                }
                            }
                        }

                        /* Input Devices */
                        Text {
                            width: parent.width
                            text: "Devices"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(10)
                            font.weight: Font.Bold
                            color: Theme.fgDim
                        }

                        Column {
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: root.sources
                                delegate: Rectangle {
                                    id: srcCard
                                    required property var modelData
                                    readonly property var node: modelData
                                    readonly property bool isCurDefault: root.defaultSource === node
                                    width: sourcesCol.width
                                    height: 30
                                    radius: 8
                                    color: isCurDefault ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : (srcMouse.containsMouse ? Theme.bgHover : "transparent")
                                    border.width: 1
                                    border.color: isCurDefault ? Theme.accent : (srcMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

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
                                                if (/headset|headphone/i.test(nm)) return "headphones"
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
                                            font.pixelSize: Theme.fontPx(11)
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
                                        z: 5
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Pipewire.preferredDefaultAudioSource = node
                                            Quickshell.execDetached(["wpctl", "set-default", String(node.id)])
                                        }
                                        onWheel: (wheel) => { wheel.accepted = false }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.sources.length === 0
                            width: parent.width
                            text: "No input devices found"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(11)
                            color: Theme.fgDim
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: 6
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.outline
            }

            /* ============ Footer: open the full sound settings ============ */
            IconButton {
                Layout.alignment: Qt.AlignLeft
                glyph: "settings"
                tip: "Open full sound settings"
                size: 14
                color: Theme.fgDim
                hoverColor: Theme.fg
                pointer: true
                onClicked: {
                    Quickshell.execDetached(["sh", "-c", "command -v pavucontrol >/dev/null && pavucontrol || pwvucontrol"])
                    root.closeRequested()
                }
            }
        }
    }

    /* Hover tracking for the popup. HoverHandler never claims press events,
     * so every button/slider below still receives clicks and drags. */
    HoverHandler {
        id: hover
        onHoveredChanged: {
            root.anyHover = hover.hovered
        }
    }
}