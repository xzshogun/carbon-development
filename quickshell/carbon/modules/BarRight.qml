import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import M3Shapes
import "../Singletons"
import "../components"

/**
 * Nebula-style Top-Right Island (Proportionally Scaled 38px):
 *   - Horizontal System Tray
 *   - Battery badge (Icon + %, hover/click opens BatteryPopup)
 *   - Sound icon (hover/click opens audio & mic device popup)
 *   - Sun icon (hover/click opens brightness control popup)
 *   - Bell icon (hover/click opens animated NotificationPopup)
 *   - Power button (opens native animated PowerMenu)
 */
Item {
    id: root

    implicitHeight: root.vertical ? (verticalCol.implicitHeight + (root.attachedEdge !== "" ? 24 : (root.showBackground ? 16 : 8))) : 38
    implicitWidth: root.vertical ? (root.attachedEdge !== "" ? 34 : 38) : pill.width

    property var anchorWindow: null
    property int notifCount: 0

    signal openMixer()
    signal closeMixer()
    signal toggleMixer()
    signal openBrightness()
    signal closeBrightness()
    signal toggleBrightness()
    signal openBattery()
    signal closeBattery()
    signal toggleBattery()
    signal openTray()
    signal closeTray()
    signal toggleTray()
    signal openNotif()
    signal closeNotif()
    signal toggleNotif()
    signal toggleControls()
    signal openPower()

    /* Audio Sink State */
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property real volume: audioSink && audioSink.audio ? audioSink.audio.volume : 0.0
    readonly property bool muted: audioSink && audioSink.audio ? audioSink.audio.muted : false

    readonly property string volumeGlyph: {
        if (root.muted) return "volume_off"
        if (root.volume > 0.5) return "volume_up"
        if (root.volume > 0.0) return "volume_down"
        return "volume_mute"
    }

    /* Battery State */
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery ? battery.isPresent : false
    readonly property real batteryPct: battery ? battery.percentage : 1.0
    readonly property bool isCharging: battery ? battery.state === UPowerDeviceState.Charging : false

    readonly property string batteryGlyph: {
        if (root.isCharging) return "battery_charging_full"
        if (root.batteryPct > 0.8) return "battery_full"
        if (root.batteryPct > 0.5) return "battery_5_bar"
        if (root.batteryPct > 0.2) return "battery_3_bar"
        return "battery_alert"
    }

    /* System Tray Items */
    readonly property var trayItems: SystemTray.items.values.filter(function (it) {
        var key = ((it.id || "") + " " + (it.title || "") + " " + (it.tooltipTitle || "")).toLowerCase()
        return !/(nm[ _-]?applet|blueman)/.test(key)
    })

    property bool showBackground: true
    property bool vertical: false
    property string attachedEdge: ""

    readonly property string notchFillPath: {
        const w = pill.width
        const h = pill.height
        const rf = 12
        const rc = 12
        if (root.attachedEdge === "left") {
            return `M 0 0 A ${rf} ${rf} 0 0 0 ${rf} ${rf} L ${w - rc} ${rf} A ${rc} ${rc} 0 0 1 ${w} ${rf + rc} L ${w} ${h - (rf + rc)} A ${rc} ${rc} 0 0 1 ${w - rc} ${h - rf} L ${rf} ${h - rf} A ${rf} ${rf} 0 0 0 0 ${h} L 0 0 Z`
        } else if (root.attachedEdge === "right") {
            return `M ${w} 0 A ${rf} ${rf} 0 0 1 ${w - rf} ${rf} L ${rc} ${rf} A ${rc} ${rc} 0 0 0 0 ${rf + rc} L 0 ${h - (rf + rc)} A ${rc} ${rc} 0 0 0 ${rc} ${h - rf} L ${w - rf} ${h - rf} A ${rf} ${rf} 0 0 1 ${w} ${h} L ${w} 0 Z`
        }
        return ""
    }

    readonly property string notchStrokePath: {
        const w = pill.width
        const h = pill.height
        const rf = 12
        const rc = 12
        if (root.attachedEdge === "left") {
            return `M 0 0 A ${rf} ${rf} 0 0 0 ${rf} ${rf} L ${w - rc} ${rf} A ${rc} ${rc} 0 0 1 ${w} ${rf + rc} L ${w} ${h - (rf + rc)} A ${rc} ${rc} 0 0 1 ${w - rc} ${h - rf} L ${rf} ${h - rf} A ${rf} ${rf} 0 0 0 0 ${h}`
        } else if (root.attachedEdge === "right") {
            return `M ${w} 0 A ${rf} ${rf} 0 0 1 ${w - rf} ${rf} L ${rc} ${rf} A ${rc} ${rc} 0 0 0 0 ${rf + rc} L 0 ${h - (rf + rc)} A ${rc} ${rc} 0 0 0 ${rc} ${h - rf} L ${w - rf} ${h - rf} A ${rf} ${rf} 0 0 1 ${w} ${h}`
        }
        return ""
    }

    Rectangle {
        id: pill
        anchors.top: parent.top
        anchors.right: parent.right
        height: root.vertical ? (verticalCol.implicitHeight + (root.attachedEdge !== "" ? 28 : (root.showBackground ? 16 : 8))) : 38
        width: root.vertical ? (root.attachedEdge !== "" ? 34 : 38) : (contentRow.implicitWidth + (root.showBackground ? 20 : 8))
        radius: root.attachedEdge !== "" ? 0 : 19
        color: (root.attachedEdge === "" && root.showBackground) ? Theme.bg : "transparent"
        border.color: (root.attachedEdge === "" && root.showBackground) ? Theme.outline : "transparent"
        border.width: (root.attachedEdge === "" && root.showBackground) ? 1 : 0

        Shape {
            id: notchShape
            visible: root.attachedEdge !== ""
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            asynchronous: false
            layer.enabled: true
            layer.smooth: true

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: root.showBackground ? Theme.bg : "transparent"

                PathSvg {
                    path: root.notchFillPath
                }
            }

            ShapePath {
                strokeWidth: root.showBackground ? 1 : 0
                strokeColor: root.showBackground ? Theme.outline : "transparent"
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: root.notchStrokePath
                }
            }
        }

        RowLayout {
            id: contentRow
            visible: !root.vertical
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 8
            spacing: 7

            /* ── System Tray (Windows-style Up Arrow) ─────────────────── */
            Item {
                id: trayBadge
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                visible: true
                readonly property bool isHovered: trayMouse.containsMouse

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: "transparent"
                    border.color: trayBadge.isHovered ? Theme.accent : "transparent"
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "keyboard_arrow_up"
                    font.family: Theme.fontIcon
                    font.pixelSize: 18
                    color: trayBadge.isHovered ? Theme.accent : Theme.fg
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleTray()
                }
            }

            /* Divider after tray */
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 14
                Layout.alignment: Qt.AlignVCenter
                color: "#25FFFFFF"
                visible: true
            }

            /* ── Control Center Button (Simple clean outline on hover) ─ */
            Item {
                id: controlsBadge
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                readonly property bool isHovered: controlsMouse.containsMouse

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: "transparent"
                    border.color: controlsBadge.isHovered ? Theme.accent : "transparent"
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "tune"
                    font.family: Theme.fontIcon
                    font.pixelSize: 15
                    color: controlsBadge.isHovered ? Theme.accent : Theme.fg
                }

                MouseArea {
                    id: controlsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleControls()
                }
            }

            /* Notification Bell Badge */
            Item {
                id: notifBadge
                Layout.preferredWidth: root.notifCount > 0 ? (notifRow.implicitWidth + 12) : 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                readonly property bool isHovered: notifMouse.containsMouse

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: "transparent"
                    border.color: notifBadge.isHovered ? Theme.accent : (root.notifCount > 0 ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35) : "transparent")
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                }

                RowLayout {
                    id: notifRow
                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                        text: root.notifCount > 0 ? "notifications_active" : "notifications"
                        font.family: Theme.fontIcon
                        font.pixelSize: 15
                        color: root.notifCount > 0 ? Theme.accentLit : (notifBadge.isHovered ? Theme.accent : Theme.fg)
                    }

                    Text {
                        visible: root.notifCount > 0
                        text: String(root.notifCount)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(7.5)
                        font.weight: Font.Bold
                        color: Theme.accentLit
                    }
                }

                MouseArea {
                    id: notifMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleNotif()
                }
            }

            /* Divider */
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 14
                Layout.alignment: Qt.AlignVCenter
                color: "#25FFFFFF"
            }

            /* ── Power Button (Simple clean outline on hover) ────────── */
            Item {
                id: pwrBadge
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                readonly property bool isHovered: pwrMouse.containsMouse

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: "transparent"
                    border.color: pwrBadge.isHovered ? Theme.err : "transparent"
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "power_settings_new"
                    font.family: Theme.fontIcon
                    font.pixelSize: 15
                    color: pwrBadge.isHovered ? Theme.err : Theme.fgDim
                }

                MouseArea {
                    id: pwrMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openPower()
                }
            }
        }

        /* ── Vertical Column for Dock / Edge Mode ─────────────── */
        ColumnLayout {
            id: verticalCol
            visible: root.vertical
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.attachedEdge !== "" ? 12 : (root.showBackground ? 8 : 4)
            spacing: 6

            /* System Tray (Vertical) */
            Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignHCenter
                visible: true
                readonly property bool isHovered: trayMouseV.containsMouse

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: "transparent"
                    border.color: parent.isHovered ? Theme.accent : "transparent"
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "keyboard_arrow_up"
                    font.family: Theme.fontIcon
                    font.pixelSize: 18
                    color: parent.isHovered ? Theme.accent : Theme.fgDim
                }

                MouseArea {
                    id: trayMouseV
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleTray()
                }
            }

            /* Control Center Button (Simple clean outline on hover) */
            Item {
                id: controlsBadgeV
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignHCenter
                readonly property bool isHovered: controlsMouseV.containsMouse

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: "transparent"
                    border.color: controlsBadgeV.isHovered ? Theme.accent : "transparent"
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "tune"
                    font.family: Theme.fontIcon
                    font.pixelSize: 15
                    color: parent.isHovered ? Theme.accent : Theme.fg
                }

                MouseArea {
                    id: controlsMouseV
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleControls()
                }
            }

            /* Divider */
            Rectangle {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 1
                Layout.alignment: Qt.AlignHCenter
                color: "#25FFFFFF"
            }

            /* Power (Simple clean outline on hover) */
            Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignHCenter
                readonly property bool isHovered: pwrMouseV.containsMouse

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: "transparent"
                    border.color: pwrMouseV.isHovered ? Theme.err : "transparent"
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "power_settings_new"
                    font.family: Theme.fontIcon
                    font.pixelSize: 15
                    color: parent.isHovered ? Theme.err : Theme.fgDim
                }

                MouseArea {
                    id: pwrMouseV
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openPower()
                }
            }
        }
    }
}
