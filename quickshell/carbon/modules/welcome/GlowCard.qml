import QtQuick

/**
 * GlowCard — Inspired by Reactbits Border Glow
 * Card container with luminous neon perimeter borders, glassmorphic fill,
 * and customizable hover / selection highlights.
 */
Item {
    id: root

    property alias contentChildren: contentArea.data
    default property alias data: contentArea.data
    property color cardColor: "#13121d"
    property real cardOpacity: 0.88
    property color glowColor: "#38bdf8"
    property color secondaryGlowColor: "#a855f7"
    property int cornerRadius: 16
    property real borderWidth: selected ? 2.0 : (isHovered ? 1.8 : 1.2)
    property bool selected: false
    property bool interactive: true
    readonly property bool isHovered: mouseArea.containsMouse

    signal clicked()

    // Interactive scale feedback
    scale: selected ? 1.015 : (isHovered && interactive ? 1.012 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    // Outer Soft Ambient Glow Rim
    Rectangle {
        id: ambientGlow
        anchors.fill: parent
        anchors.margins: -2
        radius: root.cornerRadius + 2
        color: "transparent"
        border.width: 1.5
        border.color: root.selected ? root.glowColor : (root.isHovered ? Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.6) : "#14ffffff")
        opacity: root.selected ? 0.95 : (root.isHovered ? 0.75 : 0.35)

        Behavior on opacity { NumberAnimation { duration: 260 } }
        Behavior on border.color { ColorAnimation { duration: 260 } }
    }

    // Border Glow Frame with Rotating Beam Mask
    Rectangle {
        id: borderClipContainer
        anchors.fill: parent
        radius: root.cornerRadius
        color: "#181726"
        clip: true

        // Rotating gradient beam (Reactbits Border Glow)
        Item {
            id: beamSpinner
            width: Math.max(root.width, root.height) * 2.2
            height: width
            anchors.centerIn: parent

            NumberAnimation on rotation {
                from: 0
                to: 360
                duration: root.selected ? 3600 : (root.isHovered ? 2600 : 6400)
                loops: Animation.Infinite
                running: true
            }

            // Beam 1: Primary Glow Color
            Rectangle {
                width: parent.width
                height: parent.height * 0.42
                anchors.centerIn: parent
                opacity: root.selected ? 1.0 : (root.isHovered ? 0.9 : 0.45)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: root.glowColor }
                    GradientStop { position: 1.0; color: "transparent" }
                }

                Behavior on opacity { NumberAnimation { duration: 260 } }
            }

            // Beam 2: Secondary Harmonic Glow Color (Orthogonal)
            Rectangle {
                width: parent.height * 0.42
                height: parent.width
                anchors.centerIn: parent
                opacity: root.selected ? 0.85 : (root.isHovered ? 0.7 : 0.3)
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: root.secondaryGlowColor }
                    GradientStop { position: 1.0; color: "transparent" }
                }

                Behavior on opacity { NumberAnimation { duration: 260 } }
            }
        }

        // Inner Card Surface (Insets the border so only the perimeter glow beam is visible)
        Rectangle {
            id: cardBg
            anchors.fill: parent
            anchors.margins: root.borderWidth
            radius: Math.max(0, root.cornerRadius - root.borderWidth)
            color: root.cardColor
            opacity: root.cardOpacity

            Behavior on anchors.margins { NumberAnimation { duration: 180 } }

            // Subtle surface lighting
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { 
                        position: 0.0 
                        color: root.selected ? Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.14) : 
                                               (root.isHovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.02)) 
                    }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    // Content container
    Item {
        id: contentArea
        anchors.fill: parent
        anchors.margins: 16
    }

    // Interaction handling
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
