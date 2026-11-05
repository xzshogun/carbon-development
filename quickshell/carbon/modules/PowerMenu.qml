import QtQuick
import QtQuick.Layouts
import Quickshell
import M3Shapes
import "../Singletons"

/**
 * Modern Power Menu:
 * Floating individual circular action buttons with no enclosing box.
 * Features:
 *   - Prominent 34px icons in 92px individual circular buttons
 *   - Unique MaterialShape hover morphing (Clover4Leaf, Sunny, Flower, Heart)
 *   - Bouncy spring rotation and glowing ambient rings on hover
 *   - 'Log Off' removed
 *   - 'Lock' opens Quickshell's custom Carbon session lock (visualizer, Lewis dot logo, etc.)
 */
Item {
    id: root

    property bool open: false
    signal requestClose()
    signal requestLock()

    implicitWidth: 620
    implicitHeight: 250

    /* Keyboard dismiss */
    focus: root.open
    Keys.onEscapePressed: root.requestClose()

    /* Backdrop dimmer: click anywhere to close */
    Rectangle {
        anchors.fill: parent
        color: "#88000000"
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

        TapHandler {
            onTapped: root.requestClose()
        }
    }

    /* Floating action buttons container (NO enclosing box or card background) */
    Item {
        id: container
        anchors.centerIn: parent
        width: actionsRow.width
        height: actionsRow.height

        opacity: root.open ? 1.0 : 0.0
        scale: root.open ? 1.0 : 0.86
        transform: Translate {
            y: root.open ? 0 : 26
            Behavior on y {
                NumberAnimation {
                    duration: root.open ? 300 : 200
                    easing.type: root.open ? Easing.OutBack : Easing.InQuad
                    easing.overshoot: 1.3
                }
            }
        }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale {
            NumberAnimation {
                duration: root.open ? 300 : 200
                easing.type: root.open ? Easing.OutBack : Easing.InQuad
                easing.overshoot: 1.35
            }
        }

        Row {
            id: actionsRow
            spacing: 34
            anchors.centerIn: parent

            Repeater {
                model: [
                    {
                        id: "lock",
                        label: "Lock",
                        icon: "lock",
                        hoverShape: MaterialShape.Clover4Leaf,
                        accentColor: Theme.accent ? Theme.accent : "#00F0FF",
                        isDestructive: false
                    },
                    {
                        id: "switch",
                        label: "Switch",
                        icon: "switch_account",
                        hoverShape: MaterialShape.Sunny,
                        accentColor: "#b4befe",
                        cmd: ["sh", "-c", "loginctl terminate-session ${XDG_SESSION_ID:-2} || loginctl terminate-user $USER || hyprctl repl 'hl.dispatch(hl.dsp.exit())' || pkill -9 Hyprland"],
                        isDestructive: false
                    },
                    {
                        id: "reboot",
                        label: "Reboot",
                        icon: "restart_alt",
                        hoverShape: MaterialShape.Flower,
                        accentColor: "#fab387",
                        cmd: ["sh", "-c", "systemctl reboot || loginctl reboot"],
                        isDestructive: true
                    },
                    {
                        id: "shutdown",
                        label: "Shutdown",
                        icon: "power_settings_new",
                        hoverShape: MaterialShape.SoftBurst,
                        accentColor: Theme.err ? Theme.err : "#f38ba8",
                        cmd: ["sh", "-c", "systemctl poweroff || loginctl poweroff"],
                        isDestructive: true
                    }
                ]

                delegate: Item {
                    id: btnRoot
                    required property var modelData
                    required property int index

                    width: 96
                    height: 132

                    readonly property bool isHovered: btnHover.hovered

                    // Circular action button
                    Item {
                        id: circleBox
                        width: 92
                        height: 92
                        anchors.horizontalCenter: parent.horizontalCenter

                        // Ambient glowing halo behind the shape on hover
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 16
                            height: parent.height + 16
                            radius: width / 2
                            color: btnRoot.isHovered
                                ? Qt.rgba(btnRoot.modelData.accentColor.r, btnRoot.modelData.accentColor.g, btnRoot.modelData.accentColor.b, 0.28)
                                : "transparent"
                            scale: btnRoot.isHovered ? 1.10 : 0.8
                            opacity: btnRoot.isHovered ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
                        }

                        // Unique MaterialShape: Circle at rest, morphs into unique geometric shape on hover
                        MaterialShape {
                            id: m3Shape
                            anchors.fill: parent
                            shape: btnRoot.isHovered ? btnRoot.modelData.hoverShape : MaterialShape.Circle
                            animationDuration: 280

                            color: btnRoot.isHovered
                                ? Qt.rgba(btnRoot.modelData.accentColor.r, btnRoot.modelData.accentColor.g, btnRoot.modelData.accentColor.b, 0.22)
                                : Qt.rgba(0.08, 0.08, 0.12, 0.72)

                            strokeColor: btnRoot.isHovered
                                ? btnRoot.modelData.accentColor
                                : Qt.rgba(1, 1, 1, 0.18)
                            strokeWidth: btnRoot.isHovered ? 2.2 : 1.2

                            rotation: btnRoot.isHovered ? (btnRoot.index % 2 === 0 ? 12 : -12) : 0
                            scale: btnRoot.isHovered ? 1.08 : 1.0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 320
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.4
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 280
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.3
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 220 } }
                            Behavior on strokeColor { ColorAnimation { duration: 220 } }
                        }

                        // Big prominent icon (M3 Material Symbol)
                        Text {
                            anchors.centerIn: parent
                            text: btnRoot.modelData.icon
                            font.family: Theme.fontIcon
                            font.pixelSize: 36
                            color: btnRoot.isHovered ? btnRoot.modelData.accentColor : Theme.fg
                            scale: btnRoot.isHovered ? 1.12 : 1.0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.motionDurationShort4
                                    easing.type: Theme.easingEmphasized
                                }
                            }
                            Behavior on color { ColorAnimation { duration: Theme.motionDurationShort3 } }
                        }
                    }

                    // Clean label below circle
                    Text {
                        anchors.top: circleBox.bottom
                        anchors.topMargin: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: btnRoot.modelData.label
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(13)
                        font.weight: btnRoot.isHovered ? Font.Bold : Font.Medium
                        color: btnRoot.isHovered ? btnRoot.modelData.accentColor : Theme.fgDim

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    HoverHandler {
                        id: btnHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            root.requestClose()
                            if (btnRoot.modelData.id === "lock") {
                                root.requestLock()
                                Quickshell.execDetached(["sh", (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/carbon-ipc.sh", "lock"])
                            } else if (btnRoot.modelData.cmd) {
                                Quickshell.execDetached(btnRoot.modelData.cmd)
                            }
                        }
                    }
                }
            }
        }
    }
}
