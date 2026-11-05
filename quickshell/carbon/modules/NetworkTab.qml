import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Singletons"
import "../components"

Item {
    id: root

    implicitWidth: 800
    implicitHeight: 600

    property string selectedSsid: ""
    property string passwordInput: ""
    property bool showPassword: false
    property string localIp: "192.168.1.9"
    property string gatewayIp: "192.168.1.1"
    property string pingResult: ""
    property bool pinging: false

    // Fetch IP and Gateway
    Process {
        id: ipProc
        command: ["bash", "-c", "ip -4 -br addr show | grep -v '^lo' | awk '{print $1 \":\" $3}'; ip route show default 2>/dev/null | awk '{print \"gw:\" $3}'"]
        stdout: StdioCollector {
            id: ipCollector
            waitForEnd: true
        }
        onExited: {
            var lines = ipCollector.text.trim().split("\n")
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i].trim()
                if (l.startsWith("gw:")) {
                    root.gatewayIp = l.replace("gw:", "").trim()
                } else if (l.includes(":")) {
                    var parts = l.split(":")
                    if (parts.length > 1 && parts[1].length > 0) {
                        root.localIp = parts[1].trim()
                    }
                }
            }
        }
    }

    // Diagnostic Ping Process
    Process {
        id: pingProc
        command: ["bash", "-c", "ping -c 1 -W 1 1.1.1.1 2>/dev/null | grep 'time=' | sed -E 's/.*time=([0-9.]+) ms/\\1 ms/'"]
        stdout: StdioCollector {
            id: pingCollector
            waitForEnd: true
        }
        onExited: {
            root.pinging = false
            var res = pingCollector.text.trim()
            if (res.length > 0) {
                root.pingResult = res
            } else {
                root.pingResult = "Offline / Timeout"
            }
        }
    }

    function testPing() {
        root.pinging = true
        root.pingResult = "Testing..."
        if (!pingProc.running) pingProc.running = true
    }

    Timer {
        interval: 8000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: {
            if (!ipProc.running) ipProc.running = true
        }
    }

    Component.onCompleted: {
        WifiController.refreshState()
        WifiController.refreshNetworks(false)
        root.testPing()
    }

    // Scrollable Layout
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
            // 1. HERO BANNER: NETWORK STATUS & MASTER WI-FI TOGGLE
            // =================================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.px(100)
                radius: Theme.px(12)
                color: Qt.rgba(0, 0, 0, 0.30)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.px(16)
                    spacing: Theme.px(16)

                    // Network Icon with active state halo
                    Rectangle {
                        Layout.preferredWidth: Theme.px(60)
                        Layout.preferredHeight: Theme.px(60)
                        radius: Theme.px(12)
                        color: WifiController.enabled ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: WifiController.enabled ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40) : Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (!WifiController.enabled) return "󰤭"
                                if (WifiController.currentSsid.length > 0) return "󰤨"
                                return "󰤩"
                            }
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(28)
                            color: WifiController.enabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.40)
                        }
                    }

                    // Network State & Telemetry Text
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(4)

                        RowLayout {
                            spacing: Theme.px(8)

                            Text {
                                text: {
                                    if (!WifiController.enabled) return "WIRELESS RADIO DISABLED"
                                    if (WifiController.currentSsid.length > 0) return WifiController.currentSsid.toUpperCase()
                                    return "NO ACTIVE CONNECTION"
                                }
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(14)
                                font.weight: Font.Bold
                                color: Qt.rgba(1, 1, 1, 0.95)
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.preferredWidth: Theme.px(76)
                                Layout.preferredHeight: Theme.px(18)
                                radius: Theme.px(9)
                                color: (WifiController.currentSsid.length > 0) ? Qt.rgba(0.2, 0.8, 0.4, 0.15) : Qt.rgba(1, 0.7, 0.2, 0.15)
                                border.color: (WifiController.currentSsid.length > 0) ? Qt.rgba(0.2, 0.8, 0.4, 0.5) : Qt.rgba(1, 0.7, 0.2, 0.5)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: (WifiController.currentSsid.length > 0) ? "● CONNECTED" : (WifiController.enabled ? "○ IDLE" : "✕ OFF")
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(9)
                                    font.weight: Font.Bold
                                    color: (WifiController.currentSsid.length > 0) ? "#55FF99" : (WifiController.enabled ? "#FFAA33" : Qt.rgba(1, 1, 1, 0.5))
                                }
                            }
                        }

                        // Network Details IP & Gateway
                        RowLayout {
                            spacing: Theme.px(14)

                            Text {
                                text: "IP: " + root.localIp
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(11)
                                color: Qt.rgba(1, 1, 1, 0.60)
                            }

                            Text {
                                text: "GW: " + root.gatewayIp
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(11)
                                color: Qt.rgba(1, 1, 1, 0.45)
                            }

                            Text {
                                text: "RTT: " + (root.pingResult ? root.pingResult : "checking...")
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(11)
                                color: Theme.primary
                            }
                        }
                    }

                    // Master Wi-Fi Power Switch
                    Rectangle {
                        Layout.preferredWidth: Theme.px(130)
                        Layout.preferredHeight: Theme.px(36)
                        radius: Theme.px(18)
                        color: WifiController.enabled ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: WifiController.enabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1
                        scale: toggleMouse.pressed ? 0.96 : (toggleMouse.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.px(8)

                            Text {
                                text: WifiController.enabled ? "󰤨" : "󰤭"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(14)
                                color: WifiController.enabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.4)
                            }

                            Text {
                                text: WifiController.enabled ? "Wi-Fi ON" : "Wi-Fi OFF"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.DemiBold
                                color: WifiController.enabled ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.5)
                            }
                        }

                        MouseArea {
                            id: toggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                WifiController.setEnabled(!WifiController.enabled)
                            }
                        }
                    }
                }
            }

            // =================================================================
            // 2. DETECTED WIRELESS NETWORKS
            // =================================================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: networksCol.implicitHeight + Theme.px(28)
                radius: Theme.px(12)
                color: Qt.rgba(0, 0, 0, 0.22)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                ColumnLayout {
                    id: networksCol
                    anchors.fill: parent
                    anchors.margins: Theme.px(16)
                    spacing: Theme.px(14)

                    // Header Row with Rescan Button
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "WIRELESS ENVIRONMENTS"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(12)
                            font.weight: Font.Bold
                            color: Qt.rgba(1, 1, 1, 0.90)
                        }

                        Item { Layout.fillWidth: true }

                        // Scan / Refresh Button
                        Rectangle {
                            Layout.preferredWidth: Theme.px(90)
                            Layout.preferredHeight: Theme.px(28)
                            radius: Theme.px(6)
                            color: scanMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                            border.color: scanMouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1
                            scale: scanMouse.pressed ? 0.96 : 1.0

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.px(6)

                                Text {
                                    text: "󰑐"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(12)
                                    color: Theme.primary
                                    rotation: WifiController.scanning ? 360 : 0
                                    Behavior on rotation { NumberAnimation { duration: 1000; loops: Animation.Infinite } }
                                }

                                Text {
                                    text: WifiController.scanning ? "Scanning..." : "Rescan"
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(10)
                                    font.weight: Font.Medium
                                    color: Qt.rgba(1, 1, 1, 0.85)
                                }
                            }

                            MouseArea {
                                id: scanMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WifiController.refreshNetworks(true)
                            }
                        }
                    }

                    // Empty State or Wi-Fi Disabled
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(60)
                        visible: !WifiController.enabled || WifiController.networks.length === 0

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.px(10)

                            Text {
                                text: !WifiController.enabled ? "󰤭" : "󰤨"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(18)
                                color: Qt.rgba(1, 1, 1, 0.3)
                            }

                            Text {
                                text: !WifiController.enabled ? "Turn Wi-Fi on to discover nearby wireless networks" : "No networks detected. Click Rescan to search."
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(11)
                                color: Qt.rgba(1, 1, 1, 0.4)
                            }
                        }
                    }

                    // Networks List Repeater
                    Repeater {
                        model: WifiController.networks

                        delegate: Rectangle {
                            id: netCard
                            required property var modelData
                            readonly property bool isCurrent: (WifiController.currentSsid === modelData.ssid && modelData.ssid.length > 0)
                            readonly property bool isExpanded: (root.selectedSsid === modelData.ssid)

                            Layout.fillWidth: true
                            implicitHeight: isExpanded ? Theme.px(108) : Theme.px(48)
                            radius: Theme.px(8)
                            color: isCurrent ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : (netMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03))
                            border.color: isCurrent ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.50) : (netMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06))
                            border.width: 1

                            Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.px(10)
                                spacing: Theme.px(10)

                                // Main Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(12)

                                    // Signal Icon
                                    Text {
                                        text: {
                                            var sig = modelData.signal || 50
                                            if (sig > 75) return "󰤨"
                                            if (sig > 50) return "󰤥"
                                            if (sig > 25) return "󰤢"
                                            return "󰤟"
                                        }
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(16)
                                        color: isCurrent ? Theme.primary : Qt.rgba(1, 1, 1, 0.70)
                                    }

                                    // Network Name (SSID)
                                    Text {
                                        text: modelData.ssid || "Hidden Network"
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(12)
                                        font.weight: isCurrent ? Font.DemiBold : Font.Normal
                                        color: isCurrent ? Qt.rgba(1, 1, 1, 0.98) : Qt.rgba(1, 1, 1, 0.85)
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    // Security Badge
                                    Rectangle {
                                        Layout.preferredWidth: Theme.px(54)
                                        Layout.preferredHeight: Theme.px(20)
                                        radius: Theme.px(4)
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        visible: modelData.security && modelData.security.length > 0

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: Theme.px(4)

                                            Text {
                                                text: "󰌾"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(10)
                                                color: Qt.rgba(1, 1, 1, 0.5)
                                            }

                                            Text {
                                                text: modelData.security.includes("WPA") ? "WPA2" : "SEC"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(9)
                                                color: Qt.rgba(1, 1, 1, 0.6)
                                            }
                                        }
                                    }

                                    // Status Badge (Connected / Disconnect)
                                    Rectangle {
                                        Layout.preferredWidth: Theme.px(82)
                                        Layout.preferredHeight: Theme.px(24)
                                        radius: Theme.px(6)
                                        color: isCurrent ? Qt.rgba(0.2, 0.8, 0.4, 0.2) : "transparent"
                                        border.color: isCurrent ? "#55FF99" : "transparent"
                                        border.width: 1
                                        visible: isCurrent

                                        Text {
                                            anchors.centerIn: parent
                                            text: "CONNECTED"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontPx(9)
                                            font.weight: Font.Bold
                                            color: "#55FF99"
                                        }
                                    }

                                    // Action Button (Disconnect or Connect Drawer)
                                    Rectangle {
                                        Layout.preferredWidth: Theme.px(74)
                                        Layout.preferredHeight: Theme.px(24)
                                        radius: Theme.px(6)
                                        color: isCurrent ? Qt.rgba(1, 0.2, 0.2, 0.15) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                        border.color: isCurrent ? "#FF5555" : Theme.primary
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: isCurrent ? "Disconnect" : (isExpanded ? "Close" : "Connect")
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontPx(10)
                                            font.weight: Font.Medium
                                            color: isCurrent ? "#FF6666" : Theme.primary
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (isCurrent) {
                                                    WifiController.disconnectCurrent()
                                                } else {
                                                    if (isExpanded) {
                                                        root.selectedSsid = ""
                                                    } else {
                                                        root.selectedSsid = modelData.ssid
                                                        root.passwordInput = ""
                                                        // If open network or already saved, connect immediately
                                                        if (!modelData.security || modelData.security.length === 0 || modelData.saved) {
                                                            WifiController.connectToNetwork(modelData.ssid, "")
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Expandable Inline Password Drawer
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: isExpanded && !isCurrent
                                    spacing: Theme.px(8)

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Theme.px(32)
                                        radius: Theme.px(6)
                                        color: Qt.rgba(0, 0, 0, 0.40)
                                        border.color: Qt.rgba(1, 1, 1, 0.20)
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Theme.px(10)
                                            anchors.rightMargin: Theme.px(10)
                                            spacing: Theme.px(8)

                                            TextInput {
                                                id: passField
                                                Layout.fillWidth: true
                                                verticalAlignment: TextInput.AlignVCenter
                                                echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(11)
                                                color: Qt.rgba(1, 1, 1, 0.95)
                                                text: root.passwordInput
                                                onTextChanged: root.passwordInput = text
                                                onAccepted: {
                                                    WifiController.connectToNetwork(modelData.ssid, root.passwordInput)
                                                    root.selectedSsid = ""
                                                }
                                            }

                                            // Show Password Eye Toggle
                                            Text {
                                                text: root.showPassword ? "󰈈" : "󰈉"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(14)
                                                color: Qt.rgba(1, 1, 1, 0.5)

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.showPassword = !root.showPassword
                                                }
                                            }
                                        }
                                    }

                                    // Confirm Connect Button
                                    Rectangle {
                                        Layout.preferredWidth: Theme.px(70)
                                        Layout.preferredHeight: Theme.px(32)
                                        radius: Theme.px(6)
                                        color: Theme.primary
                                        scale: connMouse.pressed ? 0.95 : 1.0

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Join"
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontPx(11)
                                            font.weight: Font.Bold
                                            color: "#000000"
                                        }

                                        MouseArea {
                                            id: connMouse
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                WifiController.connectToNetwork(modelData.ssid, root.passwordInput)
                                                root.selectedSsid = ""
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: netMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                z: -1
                                onClicked: {
                                    if (!isCurrent) {
                                        if (root.selectedSsid === modelData.ssid) root.selectedSsid = ""
                                        else root.selectedSsid = modelData.ssid
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // 3. HARDWARE ADAPTER MATRIX
            // =================================================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: adapterCol.implicitHeight + Theme.px(28)
                radius: Theme.px(12)
                color: Qt.rgba(0, 0, 0, 0.22)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                ColumnLayout {
                    id: adapterCol
                    anchors.fill: parent
                    anchors.margins: Theme.px(16)
                    spacing: Theme.px(12)

                    Text {
                        text: "NETWORK INTERFACE CONTROLLERS"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(12)
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.90)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(12)

                        // Wi-Fi NIC Card
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.px(64)
                            radius: Theme.px(8)
                            color: Qt.rgba(1, 1, 1, 0.03)
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.px(12)
                                spacing: Theme.px(10)

                                Text {
                                    text: "󰤨"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(20)
                                    color: Theme.primary
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(2)

                                    Text {
                                        text: "Wireless Interface (wlp2s0)"
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(11)
                                        font.weight: Font.Bold
                                        color: Qt.rgba(1, 1, 1, 0.90)
                                    }

                                    Text {
                                        text: WifiController.enabled ? "Status: UP / 802.11ac" : "Status: DOWN"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(10)
                                        color: WifiController.enabled ? "#55FF99" : Qt.rgba(1, 1, 1, 0.4)
                                    }
                                }
                            }
                        }

                        // Ethernet NIC Card
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.px(64)
                            radius: Theme.px(8)
                            color: Qt.rgba(1, 1, 1, 0.03)
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.px(12)
                                spacing: Theme.px(10)

                                Text {
                                    text: "󰈀"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(20)
                                    color: Qt.rgba(1, 1, 1, 0.4)
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(2)

                                    Text {
                                        text: "Ethernet Interface (enp1s0)"
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(11)
                                        font.weight: Font.Bold
                                        color: Qt.rgba(1, 1, 1, 0.90)
                                    }

                                    Text {
                                        text: "Cable Disconnected"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(10)
                                        color: Qt.rgba(1, 1, 1, 0.4)
                                    }
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
