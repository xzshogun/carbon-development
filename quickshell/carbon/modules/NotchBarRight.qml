import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import "../Singletons"
import "../components"

/**
 * NotchBarRight: Top-attached curved notch for Right side
 *   - Control/Mixer button
 *   - Volume badge (speaker icon + %)
 *   - Wi-Fi status indicator
 *   - Notification Bell with unread badge counter
 *   - Battery icon with hover trigger
 *   - Power menu button
 */
NotchContainer {
    id: root

    implicitHeight: 34
    earWidth: 20
    contentSpacing: 7

    property int notifCount: 0
    implicitWidth: contentImplicitWidth + (leftFillet ? filletRadius : 0) + (horizontalPadding * 2)

    signal openMixer()
    signal closeMixer()
    signal toggleMixer()
    signal openBrightness()
    signal closeBrightness()
    signal toggleBrightness()
    signal openBattery()
    signal closeBattery()
    signal toggleBattery()
    signal openWifi()
    signal toggleWifi()
    signal openTray()
    signal closeTray()
    signal toggleTray()
    signal openPower()

    /* ── Network State ───────────────────────────────────────────────── */
    readonly property bool wifiConnected: WifiController.currentSsid.length > 0
    readonly property string wifiGlyph: {
        if (!WifiController.enabled) return "󰤮"
        if (!root.wifiConnected) return "󰤭"
        const s = WifiController.currentSignal
        if (s > 75) return "󰤨"
        if (s > 50) return "󰤥"
        if (s > 25) return "󰤢"
        return "󰤟"
    }

    /* ── Audio Sink State ────────────────────────────────────────────── */
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property real volume: audioSink && audioSink.audio ? audioSink.audio.volume : 0.0
    readonly property bool muted: audioSink && audioSink.audio ? audioSink.audio.muted : false
    readonly property int volumePct: Math.round(root.volume * 100)

    readonly property string volumeGlyph: {
        if (root.muted) return "󰝟"
        if (root.volume > 0.66) return "󰕾"
        if (root.volume > 0.33) return "󰖀"
        if (root.volume > 0.0) return "󰕿"
        return "󰝟"
    }

    /* ── Battery State ───────────────────────────────────────────────── */
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery ? battery.isPresent : false
    readonly property real batteryPct: battery ? battery.percentage : 1.0
    readonly property bool isCharging: battery ? (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged) : false

    readonly property string batteryGlyph: {
        if (root.isCharging) return "󰂄"
        const p = root.batteryPct * 100
        if (p > 85) return "󰁹"
        if (p > 70) return "󰂀"
        if (p > 55) return "󰁿"
        if (p > 40) return "󰁾"
        if (p > 25) return "󰁽"
        if (p > 10) return "󰁼"
        return "󰂃"
    }
    /* ── System Tray for Background App Mini Icons ──────────────────── */
    readonly property var trayItems: SystemTray.items.values.filter(function (it) {
        var key = ((it.id || "") + " " + (it.title || "") + " " + (it.tooltipTitle || "")).toLowerCase()
        return !/(nm[ _-]?applet|blueman)/.test(key)
    })

    /* ── Content Inside Notch ────────────────────────────────────────── */
    content: [
        /* 1. Wi-Fi Status Badge */
        Item {
            id: wifiBadge
            width: Theme.px(24)
            height: Theme.px(24)
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool isHovered: wifiMouse.containsMouse

            Rectangle {
                anchors.fill: parent
                radius: Theme.px(6)
                color: "transparent"
                border.color: wifiBadge.isHovered ? Theme.accent : "transparent"
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }
            }

            Text {
                anchors.centerIn: parent
                text: root.wifiGlyph
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(15)
                color: root.wifiConnected ? (wifiBadge.isHovered ? Theme.accentLit : Theme.accent) : Theme.fgDim
            }

            MouseArea {
                id: wifiMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleWifi()
            }
        },

        /* 2. Volume Status Badge (Scroll wheel to adjust volume, right click to mute) */
        Item {
            id: volumeBadge
            width: Theme.px(24)
            height: Theme.px(24)
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool isHovered: volMouse.containsMouse

            Rectangle {
                anchors.fill: parent
                radius: Theme.px(6)
                color: "transparent"
                border.color: volumeBadge.isHovered ? Theme.accent : "transparent"
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }
            }

            Text {
                anchors.centerIn: parent
                text: root.volumeGlyph
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(15)
                color: root.muted ? Theme.fgDim : (volumeBadge.isHovered ? Theme.accentLit : Theme.fg)
            }

            MouseArea {
                id: volMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        if (root.audioSink && root.audioSink.audio) {
                            root.audioSink.audio.muted = !root.audioSink.audio.muted
                        }
                    } else {
                        root.toggleMixer()
                    }
                }
                onWheel: (wheel) => {
                    if (root.audioSink && root.audioSink.audio) {
                        if (wheel.angleDelta.y > 0) {
                            root.audioSink.audio.volume = Math.min(1.0, root.audioSink.audio.volume + 0.05)
                        } else if (wheel.angleDelta.y < 0) {
                            root.audioSink.audio.volume = Math.max(0.0, root.audioSink.audio.volume - 0.05)
                        }
                    }
                }
            }
        },

        /* 3. Battery Status Badge */
        Item {
            id: batteryBadge
            visible: root.hasBattery
            width: Theme.px(24)
            height: Theme.px(24)
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool isHovered: batMouse.containsMouse

            Rectangle {
                anchors.fill: parent
                radius: Theme.px(6)
                color: "transparent"
                border.color: batteryBadge.isHovered ? Theme.accent : "transparent"
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }
            }

            Text {
                anchors.centerIn: parent
                text: root.batteryGlyph
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(15)
                color: root.isCharging ? Theme.accent : (root.batteryPct < 0.2 ? Theme.err : Theme.fg)
            }

            MouseArea {
                id: batMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleBattery()
            }
        },

        /* 4. System Tray Overflow: Chevron */
        Item {
            id: trayBadge
            width: Theme.px(22)
            height: Theme.px(22)
            anchors.verticalCenter: parent.verticalCenter
            visible: true
            readonly property bool isHovered: trayMouse.containsMouse

            Rectangle {
                anchors.fill: parent
                radius: Theme.px(6)
                color: "transparent"
                border.color: trayBadge.isHovered ? Theme.accent : "transparent"
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }
            }

            Text {
                anchors.centerIn: parent
                text: "󰅀"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(15)
                color: trayBadge.isHovered ? Theme.accent : Theme.fg
            }

            MouseArea {
                id: trayMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleTray()
            }
        },

        /* 5. Power Menu Button */
        Item {
            id: pwrBadge
            width: Theme.px(24)
            height: Theme.px(24)
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool isHovered: pwrMouse.containsMouse

            Rectangle {
                anchors.fill: parent
                radius: Theme.px(6)
                color: "transparent"
                border.color: pwrBadge.isHovered ? Theme.err : "transparent"
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }
            }

            Text {
                anchors.centerIn: parent
                text: "󰐥"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(15)
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
    ]
}
