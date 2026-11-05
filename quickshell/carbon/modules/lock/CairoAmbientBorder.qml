import QtQuick
import "../../Singletons"

/**
 * CairoAmbientBorder.qml:
 * Music-sensitive ambient perimeter border for Cairo standby / lock screen.
 * Replaces the ReactBits traveling spotlight with a clean, whisper-subtle
 * ambient border matching the music-sensitive app border:
 * - Crisp 1.5px inner border in Theme.m3primary || Theme.accent.
 * - Soft inner edge glow (4px - 10px).
 * - Music sensitive: pulses smoothly in brightness and alpha with audio beats
 *   (resting at subtle 0.20 alpha during silence, blooming to 0.85 on beats).
 * - Zero traveling spotlight or distracting continuous loops.
 */
Item {
    id: root
    anchors.fill: parent

    readonly property color primaryColor: Theme.m3primary || Theme.accent || "#a1c9fd"

    property real beatEnergy: 0.0

    Behavior on beatEnergy {
        NumberAnimation { duration: 280; easing.type: Easing.OutQuad }
    }

    function triggerBeat() {
        beatEnergy = 1.0
        decayTimer.restart()
    }

    Timer {
        id: decayTimer
        interval: 80
        repeat: false
        onTriggered: {
            root.beatEnergy = 0.0
        }
    }

    // Screen border margin
    readonly property real m: 8

    // Base alpha: 0.20 resting silence -> up to 0.85 on peak beats
    readonly property real currentAlpha: 0.20 + (root.beatEnergy * 0.65)

    // 1. Soft inner ambient glow
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.m + 2
        radius: 14
        color: "transparent"
        border.width: 0
        border.color: "transparent"
        opacity: root.currentAlpha * 0.40

        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
        }
    }

    // 2. Ambient Border
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.m
        radius: 16
        color: "transparent"
        border.width: 0
        border.color: "transparent"
        opacity: root.currentAlpha

        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
        }
    }
}
