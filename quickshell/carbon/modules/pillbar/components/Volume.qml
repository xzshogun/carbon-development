import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import "../services" as QsServices
import "../effects"

// Volume indicator with number - no popup
Item {
    id: root
    
    property var barWindow
    property var mixer
    
    readonly property var pywal: QsServices.Pywal
    readonly property var audio: QsServices.Audio
    readonly property bool isHovered: mouseArea.containsMouse
    readonly property bool isMuted: audio.muted
    readonly property int percentage: audio.percentage
    readonly property bool isActive: (mixer && mixer.shouldShow) ? true : false
    
    implicitWidth: volumeRow.implicitWidth
    implicitHeight: 20
    
    RowLayout {
        id: volumeRow
        anchors.centerIn: parent
        spacing: 3
        
        // Volume icon
        Text {
            id: volumeIcon
            
            text: {
                if (isMuted) return "󰖁"
                if (percentage >= 70) return "󰕾"
                if (percentage >= 30) return "󰖀"
                return "󰕿"
            }
            
            font.family: "Material Design Icons"
            font.pixelSize: 15
            
            color: {
                if (isMuted) return Qt.rgba(pywal.foreground.r, pywal.foreground.g, pywal.foreground.b, 0.35)
                if (isActive || isHovered) return pywal.primary
                return pywal.foreground
            }
            
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
            
            scale: isHovered || isActive ? 1.08 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 100 }
            }
        }
    }
    
    // Interaction area
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) {
                audio.increaseVolume()
            } else {
                audio.decreaseVolume()
            }
        }
        
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                audio.toggleMute()
            } else {
                if (mixer && mixer.toggle) {
                    mixer.toggle()
                }
            }
        }
    }
    
    // Volume change pulse
    Connections {
        target: audio
        function onPercentageChanged() {
            pulseAnim.restart()
        }
    }
    
    SequentialAnimation {
        id: pulseAnim
        
        NumberAnimation {
            target: volumeIcon
            property: "scale"
            to: 1.2
            duration: 80
        }
        NumberAnimation {
            target: volumeIcon
            property: "scale"
            to: isHovered ? 1.05 : 1.0
            duration: 120
        }
    }
}
