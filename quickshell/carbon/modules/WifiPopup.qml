import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * Detail popup for the Wi-Fi quick tile. A compact rounded sheet listing every
 * network in range (from NetworkManager), with scan + connect actions and a
 * password prompt for secured networks. Stays inside the quick-settings panel
 * and is scrollable when the list is long.
 */
Item {
    id: root

    property bool open: false
    property string barEdge: "top"
    property bool powerOn: true
    property string wifiName: ""

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

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    /* ----------------------------- state ----------------------------- */
    property bool scanning: false
    property bool connecting: false
    property bool pwVisible: false
    property string pwSsid: ""
    property string pwBssid: ""
    property string status: ""

    property bool animatingOut: false
    onOpenChanged: {
        if (root.open) {
            root.status = ""
            root.pwVisible = false
            root.connecting = false
            if (root.powerOn) root.listNetworks()
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

    /* --------------------------- list backend --------------------------- */
    ListModel { id: networkModel }
    property var savedConns: ({})

    onPwVisibleChanged: {
        if (root.pwVisible) {
            Qt.callLater(() => {
                pwField.text = ""
                pwField.forceActiveFocus()
            })
        }
    }

    Process {
        id: listProc
        command: ["sh", "-c", "echo '===SAVED==='; nmcli -t -f NAME,TYPE con show 2>/dev/null | grep -E ':802-11-wireless|:wifi'; echo '===WIFI==='; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY,BSSID dev wifi list 2>/dev/null"]
        stdout: StdioCollector { id: listC; waitForEnd: true }
        onExited: root.applyCombinedList(String(listC.text))
    }

    Process {
        id: rescanProc
        command: ["sh", "-c", "nmcli dev wifi rescan >/dev/null 2>&1"]
        onExited: {
            root.scanning = true
            relistTimer.restart()
        }
    }

    Timer {
        id: relistTimer
        interval: 3200
        onTriggered: root.listNetworks()
    }

    Process {
        id: connectProc
        command: ["sh", "-c", "true"]
        stdout: StdioCollector { id: connC; waitForEnd: true }
        stderr: StdioCollector { id: connE; waitForEnd: true }
        onExited: {
            root.connecting = false
            if (exitCode === 0) {
                root.pwVisible = false
                root.status = "Connected to " + root.pwSsid
                delayRelist.restart()
            } else {
                var err = String(connE.text).trim()
                if (err.indexOf("Secrets were required") >= 0 || err.indexOf("no-secrets") >= 0 || err.indexOf("password") >= 0) {
                    root.pwVisible = true
                    pwField.text = ""
                    Qt.callLater(() => pwField.forceActiveFocus())
                    root.status = "Enter password for " + root.pwSsid
                } else {
                    root.status = err.length > 0 ? err : "Connection failed"
                }
                listTimer.restart()
            }
        }
    }

    Timer { id: listTimer; interval: 1200; onTriggered: root.listNetworks() }
    Timer { id: delayRelist; interval: 2500; onTriggered: root.listNetworks() }

    function listNetworks() {
        root.scanning = false
        listProc.running = true
    }

    function scanNetworks() {
        if (!root.powerOn || root.scanning) return
        rescanProc.running = true
    }

    function requestConnect(bssid, secured, ssid, isSaved) {
        if (root.connecting) return
        root.pwSsid = ssid
        root.pwBssid = bssid
        if (isSaved) {
            root.pwVisible = false
            root.doConnect(ssid, bssid, "")
            return
        }
        if (secured) {
            root.pwVisible = true
            Qt.callLater(() => {
                pwField.text = ""
                pwField.forceActiveFocus()
            })
            root.status = "Enter password for " + ssid
            return
        }
        root.doConnect(ssid, bssid, "")
    }

    function doConnect(ssid, bssid, pw) {
        root.status = "Connecting to " + (ssid || root.pwSsid) + "…"
        root.connecting = true
        var targetSsid = ssid || root.pwSsid
        var targetBssid = bssid || root.pwBssid
        var cmd = ""
        if (pw && pw.length > 0) {
            cmd = "nmcli con delete id " + root.shellQuote(targetSsid) + " >/dev/null 2>&1; " +
                  "nmcli dev wifi connect " + root.shellQuote(targetSsid) + " password " + root.shellQuote(pw)
            if (targetBssid && targetBssid.length > 0) {
                cmd += " bssid " + root.shellQuote(targetBssid)
            }
        } else {
            cmd = "nmcli con up id " + root.shellQuote(targetSsid) + " 2>/dev/null || nmcli dev wifi connect " + root.shellQuote(targetSsid)
        }
        connectProc.command = ["sh", "-c", cmd]
        connectProc.running = true
    }

    function applyCombinedList(text) {
        networkModel.clear()
        var saved = {}
        var seen = {}
        var lines = String(text).split("\n")
        var inSavedSection = false
        var inWifiSection = false

        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (!l) continue
            if (l === "===SAVED===") {
                inSavedSection = true
                inWifiSection = false
                continue
            } else if (l === "===WIFI===") {
                inSavedSection = false
                inWifiSection = true
                continue
            }

            if (inSavedSection) {
                var pSaved = l.split(":")
                if (pSaved.length >= 1 && pSaved[0]) {
                    saved[pSaved[0]] = true
                }
            } else if (inWifiSection || (!inSavedSection && text.indexOf("===SAVED===") === -1)) {
                var rawL = lines[i].replace(/\\:/g, "\u0000")
                var p = rawL.split(":")
                if (p.length < 5) continue
                var ssid = p[1].replace(/\u0000/g, ":").trim()
                if (!ssid) continue
                var sig = parseInt(p[2], 10) || 0
                var sec = p[3].replace(/\u0000/g, ":")
                var inUse = p[0] === "*" || p[0] === "yes"
                var cur = seen[ssid]
                if (!cur || inUse || sig > cur.sig) {
                    seen[ssid] = {
                        ssid: ssid,
                        sig: sig,
                        sec: sec,
                        bssid: p[4].replace(/\u0000/g, ":"),
                        inUse: inUse,
                        isSaved: !!saved[ssid]
                    }
                }
            }
        }
        root.savedConns = saved
        var rows = []
        for (var k in seen) rows.push(seen[k])
        rows.sort(function(a, b) {
            if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
            if (a.isSaved !== b.isSaved) return a.isSaved ? -1 : 1
            return b.sig - a.sig
        })
        for (var j = 0; j < rows.length; j++) networkModel.append(rows[j])
        root.scanning = false
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

        /* Header */
        RowLayout {
            id: headRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            anchors.leftMargin: root.barMode === "notch" ? 24 : 14
            height: 18
            spacing: 8

            Text {
                text: "wifi"
                font.family: Theme.fontIcon
                font.pixelSize: 18
                color: Theme.accent
            }
            Text {
                text: "Wi-Fi"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(15)
                font.weight: Font.Bold
                color: Theme.fg
            }
            Text {
                Layout.fillWidth: true
                text: root.wifiName.length > 0 ? root.wifiName : (root.powerOn ? "Not connected" : "Off")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(12)
                font.weight: root.wifiName.length > 0 ? Font.Bold : Font.Normal
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                color: root.wifiName.length > 0 ? Theme.accent : Theme.fgFaint
            }
            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter
                radius: 9
                color: root.powerOn ? Theme.accent : Theme.bgAlt
                border.width: 1
                border.color: root.powerOn ? "transparent" : Theme.fgFaint
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.powerToggled(!root.powerOn)
                }
                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: root.powerOn ? "#0e0e12" : Theme.fgDim
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.powerOn ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: Theme.motionDurationShort3 } }
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
            anchors.top: headRow.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.barMode === "notch" ? 24 : 14
            anchors.rightMargin: 14
            height: 1
            color: Theme.outline
        }

        /* Network list (scrollable) */
        ListView {
            id: netList
            anchors.top: parent.top
            anchors.topMargin: 44
            anchors.bottom: footRow.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.barMode === "notch" ? 18 : 6
            anchors.rightMargin: 6
            clip: true
            model: networkModel
            spacing: 2

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 6
                parent: netList
                anchors.top: netList.top
                anchors.bottom: netList.bottom
                anchors.right: netList.right
            }

            delegate: Rectangle {
                id: row
                width: netList.width - 12
                height: 38
                radius: 10
                color: hov.hovered ? Theme.bgHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: model.inUse ? "check" : (model.sec ? "lock" : "")
                        font.family: Theme.fontIcon
                        font.pixelSize: 13
                        color: model.inUse ? Theme.accentLit : Theme.fgFaint
                        Layout.preferredWidth: 14
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: model.ssid
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(14)
                            font.weight: model.inUse ? Font.Bold : Font.Normal
                            color: model.inUse ? Theme.accentLit : Theme.fg
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: model.inUse || model.isSaved
                            elide: Text.ElideRight
                            text: model.inUse ? "Connected" : (model.isSaved ? "Saved" : "")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(11)
                            font.weight: model.inUse ? Font.DemiBold : Font.Normal
                            color: model.inUse ? Theme.accent : Theme.fgDim
                        }
                    }

                    Text {
                        text: model.sig >= 75 ? "\u2587" : model.sig >= 45 ? "\u2585" : model.sig >= 20 ? "\u2583" : "\u2581"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(12)
                        color: model.sig >= 45 ? Theme.fgDim : Theme.fgFaint
                    }
                }

                MouseArea {
                    id: hov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestConnect(model.bssid, !!model.sec, model.ssid, !!model.isSaved)
                }
            }
        }

        /* Footer: scan action or password entry */
        Rectangle {
            id: footRow
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottomMargin: 14
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            height: 40
            radius: 12
            color: Theme.bgAlt

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                visible: !root.pwVisible

                Text {
                    text: root.connecting ? "" : (root.scanning ? "sync" : "search")
                    font.family: Theme.fontIcon
                    font.pixelSize: 15
                    color: Theme.fgDim

                    NumberAnimation on rotation {
                        from: 0; to: 360; duration: 900
                        loops: Animation.Infinite
                        easing.type: Easing.Linear
                        running: root.scanning
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    elide: Text.ElideRight
                    text: statusText()
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(12)
                    color: root.status.length > 0 ? Theme.accentLit : Theme.fgFaint
                }

                Text {
                    text: "SCAN"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(11)
                    font.bold: true
                    color: (!root.powerOn || root.scanning || root.connecting) ? Theme.fgFaint : Theme.accentLit
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.scanNetworks()
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6
                visible: root.pwVisible

                Text {
                    elide: Text.ElideRight
                    text: root.pwSsid
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(12)
                    color: Theme.fgDim
                    Layout.maximumWidth: 80
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 26
                    radius: 8
                    color: "#0E0F14"
                    border.width: 1
                    border.color: Theme.outline

                    TextInput {
                        id: pwField
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(12)
                        color: Theme.fg
                        echoMode: TextInput.Password
                        focus: root.pwVisible
                        onAccepted: root.doConnect(root.pwSsid, root.pwBssid, pwField.text)
                    }
                }

                Text {
                    text: "CONNECT"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(11)
                    font.bold: true
                    color: Theme.accentLit
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.doConnect(root.pwSsid, root.pwBssid, pwField.text)
                    }
                }

                Text {
                    text: "close"
                    font.family: Theme.fontIcon
                    font.pixelSize: 14
                    color: Theme.fgDim
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.pwVisible = false
                            root.status = ""
                        }
                    }
                }
            }
        }
    }

    function statusText() {
        if (root.pwVisible || root.connecting) return root.status
        if (root.scanning) return "Scanning for networks…"
        if (!root.powerOn) return "Wi-Fi is off"
        if (networkModel.count === 0) return "No networks found"
        return root.status
    }
}