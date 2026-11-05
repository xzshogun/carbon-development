import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Singletons"

/**
 * DynamicIslandPill: Animated HUD content rendered inside the center pill or notch
 * when HudService is active (volume, brightness, track change, charging).
 */
Item {
    id: root

    implicitHeight: Theme.px(26)
    implicitWidth: mainRow.implicitWidth

    Row {
        id: mainRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(10)

        /* ── Volume & Brightness HUD ─────────────────────────────────── */
        Row {
            id: sliderHud
            spacing: Theme.px(8)
            anchors.verticalCenter: parent.verticalCenter
            visible: HudService.mode === "volume" || HudService.mode === "brightness"

            Text {
                id: iconText
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontPx(15)
                color: HudService.muted ? Theme.error : Theme.accent
                text: HudService.icon
            }

            Rectangle {
                id: trackBg
                width: Theme.px(90)
                height: Theme.px(5)
                radius: Theme.px(2.5)
                color: Qt.alpha(Theme.fg, 0.15)
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    radius: Theme.px(2.5)
                    width: Math.max(0, Math.min(parent.width, parent.width * (HudService.muted ? 0 : HudService.value)))

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: HudService.muted ? Theme.error : Theme.accent
                        }
                        GradientStop {
                            position: 1.0
                            color: HudService.muted ? Theme.error : Qt.tint(Theme.accent, "#FFFFFF")
                        }
                    }

                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(11)
                font.weight: Font.Bold
                color: HudService.muted ? Theme.error : Theme.fg
                text: HudService.text
            }
        }

        /* ── Track Change HUD ─────────────────────────────────────────── */
        Row {
            id: trackHud
            spacing: Theme.px(8)
            anchors.verticalCenter: parent.verticalCenter
            visible: HudService.mode === "track"

            Rectangle {
                width: Theme.px(20)
                height: Theme.px(20)
                radius: Theme.px(10)
                color: Theme.bgAlt
                border.color: Theme.accent
                border.width: 1
                clip: true
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    source: HudService.artUrl
                    sourceSize: Qt.size(Theme.px(40), Theme.px(40))
                    visible: HudService.artUrl.length > 0
                    fillMode: Image.PreserveAspectCrop
                }

                Text {
                    anchors.centerIn: parent
                    visible: HudService.artUrl.length === 0
                    text: "music_note"
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontPx(13)
                    color: Theme.accent
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: "NOW PLAYING"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(7)
                    font.weight: Font.Bold
                    color: Theme.accent
                }

                Text {
                    text: HudService.title
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(10)
                    font.weight: Font.Bold
                    color: Theme.fg
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, Theme.px(140))
                }
            }
        }

        /* ── Battery / Power HUD ──────────────────────────────────────── */
        Row {
            id: batteryHud
            spacing: Theme.px(8)
            anchors.verticalCenter: parent.verticalCenter
            visible: HudService.mode === "battery"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontPx(15)
                color: Theme.accent
                text: HudService.icon
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: HudService.title
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(9)
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                Text {
                    text: HudService.subText
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(8)
                    color: Theme.fgDim
                    visible: text.length > 0
                }
            }
        }
    }
}
