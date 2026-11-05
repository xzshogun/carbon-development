import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../services" as QsServices
import "../effects"

Item {
    id: root

    property var launcher
    property var controlCenter
    property var sidebar
    property var dashboard
    readonly property var pywal: QsServices.Pywal
    readonly property var time: QsServices.Time
    
    implicitWidth: clockRow.implicitWidth
    implicitHeight: clockRow.implicitHeight
    
    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 8
        
        // Compact time display
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            
            // Hours
            Text {
                id: hoursText
                text: time.format("hh")
                color: pywal.foreground
                font.pixelSize: 12
                font.weight: Font.Bold
                font.family: "Inter"
                font.letterSpacing: 0.3
            }
            
            // Animated colon separator
            Text {
                id: colonSeparator
                text: ":"
                color: pywal.primary
                font.pixelSize: 12
                font.weight: Font.Bold
                font.family: "Inter"
                opacity: 0.4
                
                // Blinks once per second via timer instead of continuous animation
                // to avoid constant GPU repaints
                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: colonSeparator.opacity = colonSeparator.opacity === 1.0 ? 0.4 : 1.0
                }
            }
            
            // Minutes
            Text {
                id: minutesText
                text: time.format("mm")
                color: pywal.foreground
                font.pixelSize: 12
                font.weight: Font.Bold
                font.family: "Inter"
                font.letterSpacing: 0.3
            }
        }
        
        // Compact date
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: time.format("ddd d")
            color: Qt.rgba(pywal.foreground.r, pywal.foreground.g, pywal.foreground.b, 0.6)
            font.pixelSize: 10
            font.weight: Font.Medium
            font.family: "Inter"
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (!root.dashboard)
                    return

                root.dashboard.shouldShow = !root.dashboard.shouldShow
                if (root.dashboard.shouldShow) {
                    if (root.launcher)
                        root.launcher.shouldShow = false
                    if (root.controlCenter)
                        root.controlCenter.shouldShow = false
                    if (root.sidebar)
                        root.sidebar.shouldShow = false
                }
                return
            }

            if (!root.launcher)
                return

            root.launcher.shouldShow = !root.launcher.shouldShow
            if (root.launcher.shouldShow) {
                if (root.controlCenter)
                    root.controlCenter.shouldShow = false
                if (root.sidebar)
                    root.sidebar.shouldShow = false
                if (root.dashboard)
                    root.dashboard.shouldShow = false
            }
        }
    }
}
