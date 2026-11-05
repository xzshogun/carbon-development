import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * Detail popup for the Bluetooth quick tile: paired/known devices from
 * bluez, connect/disconnect, scan.
 */
Item {
    id: root

    property bool open: false
    property string barEdge: "top"
    property bool powerOn: true
    property string btName: ""

    property string barMode: "notch"
    property real notchOpacity: 0.96

    signal requestedClose()
    signal powerToggled(bool on)

    implicitWidth: 260
    implicitHeight: 286
    width: 260
    height: 286
    clip: true
    visible: root.open || root.animatingOut
    enabled: root.open

    /* ----------------------------- state ----------------------------- */
    property bool scanning: false
    property bool working: false
    property string status: ""

    property bool animatingOut: false
    onOpenChanged: {
        if (root.open) {
            root.status = ""
            root.reloadAll()
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

    ListModel { id: deviceModel }

    Process {
        id: listProc
        command: ["sh", "-c", "echo '===PAIRED==='; bluetoothctl devices Paired 2>/dev/null | sed -E 's/^Device ([0-9A-F:]+) (.*)/\\1|\\2/'; echo '===CONNECTED==='; bluetoothctl devices Connected 2>/dev/null | sed -E 's/^Device ([0-9A-F:]+).*/\\1/'; echo '===ALL==='; bluetoothctl devices 2>/dev/null | sed -E 's/^Device ([0-9A-F:]+) (.*)/\\1|\\2/'"]
        stdout: StdioCollector { id: listC; waitForEnd: true }
        onExited: root.applyDevices(String(listC.text))
    }

    Process {
        id: actProc
        command: ["sh", "-c", "true"]
        stdout: StdioCollector { id: actC; waitForEnd: true }
        stderr: StdioCollector { id: actE; waitForEnd: true }
        onExited: {
            root.working = false
            if (exitCode === 0) {
                root.status = "Success"
            } else {
                var err = String(actE.text).trim()
                if (!err) err = String(actC.text).trim()
                root.status = err.length > 0 ? err.split("\n")[0] : "Action failed"
            }
            delayRelist.restart()
        }
    }

    Process {
        id: scanProc
        command: ["sh", "-c", "bluetoothctl scan on >/dev/null 2>&1; sleep 8; bluetoothctl scan off >/dev/null 2>&1"]
        onExited: {
            root.scanning = false
            root.reloadAll()
        }
    }

    Timer {
        id: scanTicker
        interval: 1800
        repeat: true
        running: root.open && root.scanning
        onTriggered: root.reloadAll()
    }

    Timer { id: delayRelist; interval: 1000; onTriggered: root.reloadAll() }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function reloadAll() {
        listProc.running = true
    }

    function scanDevices() {
        if (!root.powerOn || root.scanning || root.working) return
        root.scanning = true
        scanProc.running = true
    }

    function toggleDevice(mac, connected, paired) {
        if (root.working) return
        root.working = true
        if (connected) {
            root.status = "Disconnecting…"
            actProc.command = ["sh", "-c", "bluetoothctl disconnect " + root.shellQuote(mac)]
        } else if (paired) {
            root.status = "Connecting…"
            actProc.command = ["sh", "-c", "bluetoothctl connect " + root.shellQuote(mac)]
        } else {
            root.status = "Pairing…"
            actProc.command = ["sh", "-c", "bluetoothctl trust " + root.shellQuote(mac) + " >/dev/null 2>&1; bluetoothctl pair " + root.shellQuote(mac) + " && bluetoothctl connect " + root.shellQuote(mac)]
        }
        actProc.running = true
    }

    function applyDevices(text) {
        var pairedMap = {}
        var connectedMap = {}
        var allDevices = {}
        var lines = String(text).split("\n")
        var section = ""

        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (!l) continue
            if (l === "===PAIRED===") { section = "paired"; continue }
            if (l === "===CONNECTED===") { section = "connected"; continue }
            if (l === "===ALL===") { section = "all"; continue }

            if (section === "paired") {
                var barP = l.indexOf("|")
                if (barP > 0) {
                    var mP = l.substring(0, barP).trim()
                    var nP = l.substring(barP + 1).trim()
                    if (mP) {
                        pairedMap[mP] = nP
                        allDevices[mP] = { mac: mP, name: nP, paired: true, connected: false }
                    }
                }
            } else if (section === "connected") {
                connectedMap[l] = true
            } else if (section === "all") {
                var barA = l.indexOf("|")
                if (barA > 0) {
                    var mA = l.substring(0, barA).trim()
                    var nA = l.substring(barA + 1).trim()
                    if (mA) {
                        if (!allDevices[mA]) {
                            allDevices[mA] = { mac: mA, name: nA, paired: false, connected: false }
                        }
                    }
                }
            }
        }

        var rows = []
        for (var k in allDevices) {
            var dev = allDevices[k]
            dev.connected = !!connectedMap[dev.mac]
            dev.paired = !!pairedMap[dev.mac]
            rows.push(dev)
        }

        rows.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.paired !== b.paired) return a.paired ? -1 : 1
            return a.name.localeCompare(b.name)
        })

        deviceModel.clear()
        if (root.powerOn) {
            for (var j = 0; j < rows.length; j++) deviceModel.append(rows[j])
        }
    }

    readonly property string fillPath: {
        const w = sheet.width
        const h = sheet.height
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
        const w = sheet.width
        const h = sheet.height
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

    /* ----------------------------- visuals ----------------------------- */
    Item {
        id: sheet
        anchors.fill: parent

        Rectangle {
            id: cardBgRect
            anchors.fill: parent
            visible: root.barMode !== "notch"
            radius: 16
            color: Theme.isDark ? Qt.rgba(0.06, 0.07, 0.09, 0.98) : Qt.rgba(Theme.m3surfaceContainer.r, Theme.m3surfaceContainer.g, Theme.m3surfaceContainer.b, 0.98)
            border.width: 1
            border.color: root.open ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.40) : Theme.outline
        }

        Shape {
            id: cardBgShape
            anchors.fill: parent
            visible: root.barMode === "notch"
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true
            asynchronous: false
            layer.enabled: true
            layer.smooth: true

            ShapePath {
                fillColor: Theme.isDark ? Qt.rgba(0.04, 0.04, 0.06, root.notchOpacity) : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.notchOpacity)
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

        /* swallow clicks on empty popup real estate */
        MouseArea { anchors.fill: parent }

        RowLayout {
            id: headRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            anchors.leftMargin: root.barMode === "notch" ? 20 : 12
            height: 24
            spacing: 8

            Text {
                text: "bluetooth"
                font.family: Theme.fontIcon
                font.pixelSize: 18
                color: Theme.accentLit
            }
            Text {
                text: "Bluetooth"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(14)
                font.weight: Font.Bold
                color: Theme.fg
            }
            Text {
                Layout.fillWidth: true
                text: root.btName.length > 0 ? root.btName
                     : (root.powerOn ? (deviceModel.count === 0 ? "No devices" : "On")
                                     : "Off")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(11)
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                color: (root.btName.length > 0 || root.powerOn) ? Theme.accentLit : Theme.fgFaint
            }
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter
                radius: 9
                color: root.powerOn ? Theme.accent : Theme.bgAlt
                border.width: 1
                border.color: root.powerOn ? "transparent" : Theme.fgFaint
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.powerToggled(!root.powerOn)
                }
                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: root.powerOn ? "#0e0e12" : Theme.fgDim
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.powerOn ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }
                }
            }
            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                radius: 11
                color: closeHov.containsMouse ? Theme.bgHover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "close"
                    font.family: Theme.fontIcon
                    font.pixelSize: 15
                    color: closeHov.containsMouse ? Theme.fg : Theme.fgDim
                }
                MouseArea {
                    id: closeHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestedClose()
                }
            }
        }

        Rectangle {
            id: sepLine
            anchors.top: headRow.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.barMode === "notch" ? 20 : 12
            anchors.rightMargin: 12
            height: 1
            color: Theme.outline
        }

        ListView {
            id: devList
            anchors.top: sepLine.bottom
            anchors.topMargin: 8
            anchors.bottom: footRow.top
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.barMode === "notch" ? 16 : 8
            anchors.rightMargin: 8
            clip: true
            model: deviceModel
            spacing: 4

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 4
                parent: devList
                anchors.top: devList.top
                anchors.bottom: devList.bottom
                anchors.right: devList.right
            }

            delegate: Rectangle {
                id: row
                width: devList.width
                height: 40
                radius: 10
                color: hov.hovered ? Theme.bgHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "bluetooth"
                        font.family: Theme.fontIcon
                        font.pixelSize: 16
                        color: model.connected ? Theme.accentLit : Theme.fgFaint
                        Layout.preferredWidth: 16
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: model.name.length > 0 ? model.name : model.mac
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(12)
                            font.weight: model.connected ? Font.Bold : Font.Normal
                            color: model.connected ? Theme.accentLit : Theme.fg
                        }
                        Text {
                            Layout.fillWidth: true
                            text: model.connected ? "Connected" : (model.paired ? "Paired" : "Ready to pair")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(9.5)
                            color: model.connected ? Theme.accentLit : Theme.fgDim
                        }
                    }

                    Rectangle {
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: model.connected ? 48 : (model.paired ? 42 : 38)
                        radius: 6
                        color: model.connected ? Qt.rgba(1, 0.3, 0.3, 0.15) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        border.width: 1
                        border.color: model.connected ? Qt.rgba(1, 0.3, 0.3, 0.35) : Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.35)

                        Text {
                            anchors.centerIn: parent
                            text: model.connected ? "DROP" : (model.paired ? "LINK" : "PAIR")
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(9)
                            font.bold: true
                            color: model.connected ? "#ff6b6b" : Theme.accentLit
                        }
                    }
                }

                MouseArea {
                    id: hov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleDevice(model.mac, model.connected, model.paired)
                }
            }
        }

        Text {
            anchors.centerIn: devList
            visible: root.powerOn && deviceModel.count === 0 && !root.scanning
            text: "No paired devices found"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Theme.fontPx(11)
            color: Theme.fgFaint
        }

        Text {
            anchors.centerIn: devList
            visible: !root.powerOn
            text: "Bluetooth is disabled"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Theme.fontPx(11)
            color: Theme.fgFaint
        }

        Rectangle {
            id: footRow
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottomMargin: 12
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 38
            radius: 12
            color: Theme.bgAlt
            border.width: 1
            border.color: Theme.outline

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: root.working ? "" : (root.scanning ? "sync" : "search")
                    font.family: Theme.fontIcon
                    font.pixelSize: 16
                    color: Theme.fgDim
                }

                Text {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    elide: Text.ElideRight
                    text: root.status.length > 0 ? root.status
                        : root.scanning ? "Scanning for devices…"
                        : !root.powerOn ? "Bluetooth is off"
                        : deviceModel.count === 0 ? "No known devices"
                        : "Tap a device to connect"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(11)
                    color: root.status.length > 0 ? Theme.accentLit : Theme.fgFaint
                }

                Text {
                    text: "SCAN"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(11)
                    font.bold: true
                    color: (!root.powerOn || root.scanning || root.working) ? Theme.fgFaint : Theme.accentLit
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.scanDevices()
                    }
                }
            }
        }
    }
}