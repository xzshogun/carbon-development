import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import "../services" as QsServices

// Clean Network indicator - No shadows, proper alignment
Item {
    id: root
    
    property var barWindow
    property var bar  // Reference to Bar.qml root for inline popup toggle
    
    readonly property var pywal: QsServices.Pywal
    readonly property var network: QsServices.Network
    readonly property bool isHovered: mouseArea.containsMouse
    readonly property bool isConnected: network.active !== null
    readonly property bool isEnabled: network.wifiEnabled
    readonly property int signalStrength: isConnected ? network.active.strength : 0
    readonly property string networkName: isConnected ? (network.active.ssid ?? "Connected") : ""
    
    implicitWidth: networkRow.implicitWidth
    implicitHeight: 20
    
    RowLayout {
        id: networkRow
        anchors.centerIn: parent
        spacing: 5
        
        // WiFi icon
        Text {
            id: wifiIcon
            Layout.alignment: Qt.AlignVCenter
            
            text: {
                if (!isEnabled) return "󰖪"
                if (!isConnected) return "󰖪"
                if (signalStrength >= 75) return "󰤨"
                if (signalStrength >= 50) return "󰤥"
                if (signalStrength >= 25) return "󰤢"
                return "󰤟"
            }
            
            font.family: "Material Design Icons"
            font.pixelSize: 14
            
            color: {
                if (!isEnabled) return Qt.rgba(pywal.foreground.r, pywal.foreground.g, pywal.foreground.b, 0.3)
                if (!isConnected) return Qt.rgba(pywal.foreground.r, pywal.foreground.g, pywal.foreground.b, 0.4)
                if (isHovered) return pywal.primary
                return Qt.rgba(pywal.foreground.r, pywal.foreground.g, pywal.foreground.b, 0.8)
            }
            
            Behavior on color { ColorAnimation { duration: 150 } }
            
            scale: isHovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }
        }
    }
    
    // Click handler
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        
        onClicked: {
            if (root.bar) {
                root.bar.togglePopup("network")
            }
        }
    }
}
