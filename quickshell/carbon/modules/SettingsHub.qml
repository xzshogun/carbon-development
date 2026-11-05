import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import "../Singletons"
import "../components"

Item {
    id: root

    property bool open: false
    signal closeRequested()

    property string currentSection: "Modes"

    // Backdrop dismissal
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    // Main Hub Window (Full-screen flush edge-to-edge layout separated by strict 1px hairlines)
    Rectangle {
        id: hubWindow
        anchors.fill: parent
        color: Theme.surface
        border.width: 0
        radius: 0
        clip: true
        focus: true

        Keys.onEscapePressed: root.closeRequested()

        // Stop propagation so clicking inside window doesn't close
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.px(52)
                color: Qt.rgba(0, 0, 0, 0.20)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(20)
                    anchors.rightMargin: Theme.px(16)
                    spacing: Theme.px(12)

                    Text {
                        text: "CARBON // SETTINGS HUB"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(13)
                        font.weight: Font.Bold
                        color: Theme.primary
                    }

                    Item { Layout.fillWidth: true }

                    // Close Button
                    Rectangle {
                        Layout.preferredWidth: Theme.px(28)
                        Layout.preferredHeight: Theme.px(28)
                        radius: Theme.px(6)
                        color: closeMouse.pressed ? Qt.rgba(1, 1, 1, 0.15) : (closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        border.color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(13)
                            color: Qt.rgba(1, 1, 1, 0.70)
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeRequested()
                        }
                    }
                }
            }

            // Body: Sidebar + Vertical Hairline + Main Tab Content
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ==========================================
                // SIDEBAR with subtle tactile hardware pattern
                // ==========================================
                Item {
                    Layout.preferredWidth: Theme.px(210)
                    Layout.fillHeight: true

                    // Plain solid background
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                    }

                    // Sidebar Navigation Items
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: Theme.px(16)
                        anchors.leftMargin: Theme.px(12)
                        anchors.rightMargin: Theme.px(12)
                        spacing: Theme.px(4)

                        Repeater {
                            model: [
                                { name: "Appearance", glyph: "󰏘", badge: "M3" },
                                { name: "Modes", glyph: "󱐋", badge: "STUDIO" },
                                { name: "Panels & Canvas", glyph: "󰹑", badge: "PRO" },
                                { name: "Display", glyph: "󰍹", badge: "" },
                                { name: "Audio", glyph: "󰓃", badge: "" },
                                { name: "Network", glyph: "󰤨", badge: "" },
                                { name: "System", glyph: "󰘚", badge: "" }
                            ]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.px(38)
                                radius: Theme.px(6)
                                color: (root.currentSection.toLowerCase() === modelData.name.toLowerCase()) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : (navMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                                border.color: (root.currentSection.toLowerCase() === modelData.name.toLowerCase()) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40) : "transparent"
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.px(12)
                                    anchors.rightMargin: Theme.px(12)
                                    spacing: Theme.px(10)

                                    Text {
                                        text: modelData.glyph
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(15)
                                        color: (root.currentSection.toLowerCase() === modelData.name.toLowerCase()) ? Theme.primary : Qt.rgba(1, 1, 1, 0.60)
                                    }

                                    Text {
                                        text: modelData.name
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(13)
                                        font.weight: (root.currentSection.toLowerCase() === modelData.name.toLowerCase()) ? Font.DemiBold : Font.Normal
                                        color: (root.currentSection.toLowerCase() === modelData.name.toLowerCase()) ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.65)
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: modelData.badge.length > 0
                                        text: modelData.badge
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(9)
                                        font.weight: Font.Bold
                                        color: Theme.primary
                                    }
                                }

                                MouseArea {
                                    id: navMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.currentSection = modelData.name
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Version info at bottom of sidebar
                        Text {
                            text: "CARBON // v2.6.4"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(10)
                            color: Qt.rgba(1, 1, 1, 0.25)
                            Layout.alignment: Qt.AlignHCenter
                            Layout.bottomMargin: 12
                        }
                    }
                }

                // 1px Vertical Hairline Separating Sidebar & Content
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                // Main Content View
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    AppearanceTab {
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "appearance"
                    }

                    ModesTab {
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "modes"
                    }

                    PanelsCanvasTab {
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "panels & canvas" || root.currentSection.toLowerCase() === "panels"
                    }

                    DisplaysTab {
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "display" || root.currentSection.toLowerCase() === "displays"
                    }

                    AudioTab {
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "audio"
                    }

                    NetworkTab {
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "network"
                    }

                    // Placeholder for other sections (e.g. System)
                    Item {
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "system"

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "SYSTEM TELEMETRY"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(14)
                                font.weight: Font.Bold
                                color: Qt.rgba(1, 1, 1, 0.50)
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "Section under active development"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(12)
                                color: Qt.rgba(1, 1, 1, 0.30)
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
