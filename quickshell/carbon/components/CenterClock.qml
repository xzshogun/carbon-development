import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * CenterClock: Live center-island clock supporting 5 distinct visual designs:
 *   1. titan      - Titan 3D Pop (Titan One bold font with dual-tone raised effect)
 *   2. digital    - Cyber Digital (Orbitron glowing digital tech style)
 *   3. minimal    - Modern Minimal (Valley Sans clean geometric with accent dot)
 *   4. pill_badge - Pill Capsule (Contained capsule badge with JetBrainsMono)
 *   5. stacked    - Stacked Dual (Two-line vertical HH/MM compact aesthetic)
 */
Item {
    id: root

    property string clockStyle: "titan"
    property string clockFormat: "12"
    property bool showDate: true
    property string hourStr: "12"
    property string minStr: "00"

    implicitHeight: mainLayout.implicitHeight
    implicitWidth: mainLayout.implicitWidth

    function updateTime() {
        var now = new Date()
        if (root.clockFormat === "24") {
            var h24 = now.getHours()
            root.hourStr = (h24 < 10 ? "0" : "") + h24
        } else {
            var h12 = now.getHours() % 12 || 12
            root.hourStr = (h12 < 10 ? "0" : "") + h12
        }
        var m = now.getMinutes()
        root.minStr = (m < 10 ? "0" : "") + m
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.updateTime()
    }

    FileView {
        id: cfgFile
        path: (Quickshell.env("HOME") || "") + "/.config/hypr/carbon-clock-style.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.applyConfig(cfgFile.text())
        onFileChanged: reload()
    }

    function applyConfig(txt) {
        if (!txt) return
        try {
            var parsed = JSON.parse(txt)
            if (parsed && parsed.style) {
                root.clockStyle = parsed.style
            }
            if (parsed && parsed.format) {
                root.clockFormat = parsed.format
            }
            if (parsed && parsed.showDate !== undefined) {
                root.showDate = Boolean(parsed.showDate)
            }
            root.updateTime()
        } catch (e) {}
    }

    Item {
        id: mainLayout
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        implicitWidth: loader.item ? loader.item.implicitWidth : 50
        implicitHeight: loader.item ? loader.item.implicitHeight : 24
        width: implicitWidth
        height: implicitHeight

        Loader {
            id: loader
            anchors.centerIn: parent
            sourceComponent: {
                switch (root.clockStyle) {
                    case "stacked":      return compStacked
                    case "mono_glow":    return compMonoGlow
                    case "split_pill":   return compSplitPill
                    case "orbitron":
                    case "digital":      return compOrbitron
                    case "minimal_pill":
                    case "minimal":
                    case "valley":       return compMinimalPill
                    case "titan":
                    default:             return compTitan
                }
            }
        }
    }

    /* ── 1. Titan 3D Pop Component ───────────────────────────────────── */
    Component {
        id: compTitan
        Row {
            spacing: Theme.px(2)

            Text {
                text: root.hourStr
                font.family: "Plus Jakarta Sans"
                font.pixelSize: Theme.fontPx(14)
                font.weight: Font.Bold
                color: Theme.fg
            }

            Text {
                text: ":"
                font.family: "Plus Jakarta Sans"
                font.pixelSize: Theme.fontPx(14)
                font.weight: Font.Bold
                color: Theme.accent
            }

            Text {
                text: root.minStr
                font.family: "Plus Jakarta Sans"
                font.pixelSize: Theme.fontPx(14)
                font.weight: Font.Bold
                color: Theme.accent
            }
        }
    }

    /* ── 2. Stacked Dual (Enlarged & High-Impact) ────────────────────── */
    Component {
        id: compStacked
        Row {
            spacing: Theme.px(6)

            Rectangle {
                width: Math.max(1, Theme.px(3))
                height: Theme.px(22)
                radius: Theme.px(1.5)
                color: Theme.accent
            }

            Column {
                spacing: -Theme.px(5)

                Text {
                    text: root.hourStr
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(12)
                    font.weight: Font.Black
                    color: Theme.fg
                }

                Text {
                    text: root.minStr
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(12)
                    font.weight: Font.Black
                    color: Theme.accent
                }
            }
        }
    }

    /* ── 3. Nordic Monospace (Precision JetBrainsMono with Breathing Glow Dot) ── */
    Component {
        id: compMonoGlow
        Row {
            spacing: Theme.px(5)

            Text {
                text: root.hourStr
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(13)
                font.weight: Font.Bold
                color: Theme.fg
            }

            Rectangle {
                width: Theme.px(4)
                height: Theme.px(4)
                radius: Theme.px(2)
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.accentLit
            }

            Text {
                text: root.minStr
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(13)
                font.weight: Font.Bold
                color: Theme.accentLit
            }
        }
    }

    /* ── 4. Split Glass Tiles (Tactile Dual Pill) ────────────────────── */
    Component {
        id: compSplitPill
        Row {
            spacing: Theme.px(5)

            Rectangle {
                width: Theme.px(26)
                height: Theme.px(22)
                radius: Theme.px(6)
                color: Qt.alpha(Theme.fg, 0.09)
                border.color: Qt.alpha(Theme.accent, 0.35)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: root.hourStr
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(12)
                    font.weight: Font.Bold
                    color: Theme.fg
                }
            }

            Text {
                text: ":"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(12)
                font.weight: Font.Black
                color: Theme.accent
            }

            Rectangle {
                width: Theme.px(26)
                height: Theme.px(22)
                radius: Theme.px(6)
                color: Qt.alpha(Theme.accent, 0.16)
                border.color: Theme.accent
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: root.minStr
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(12)
                    font.weight: Font.Bold
                    color: Theme.accentLit
                }
            }
        }
    }

    /* ── 5. Cyberpunk HUD Matrix (Telemetry Brackets) ─────────────────── */
    Component {
        id: compOrbitron
        Row {
            spacing: Theme.px(3)

            Text {
                text: "["
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(13)
                font.weight: Font.Bold
                color: Theme.accent
            }

            Text {
                text: root.hourStr
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(12)
                font.weight: Font.Black
                color: Theme.fg
            }

            Text {
                text: ":"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(12)
                font.weight: Font.Black
                color: Theme.accent
            }

            Text {
                text: root.minStr
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(12)
                font.weight: Font.Black
                color: Theme.fg
            }

            Text {
                text: "]"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(13)
                font.weight: Font.Bold
                color: Theme.accent
            }
        }
    }

    /* ── 6. Aero Pill Badge (Unified Frosted Glass Capsule) ───────────── */
    Component {
        id: compMinimalPill
        Rectangle {
            height: Theme.px(22)
            width: aeroRow.implicitWidth + Theme.px(16)
            implicitHeight: Theme.px(22)
            implicitWidth: width
            radius: Theme.px(11)
            color: Qt.alpha(Theme.fg, 0.08)
            border.color: Qt.alpha(Theme.accent, 0.4)
            border.width: 1

            Row {
                id: aeroRow
                anchors.centerIn: parent
                spacing: Theme.px(2)

                Text {
                    text: root.hourStr
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(12)
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                Text {
                    text: ":"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(12)
                    font.weight: Font.Black
                    color: Theme.accent
                }

                Text {
                    text: root.minStr
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(12)
                    font.weight: Font.Bold
                    color: Theme.accentLit
                }
            }
        }
    }
}
