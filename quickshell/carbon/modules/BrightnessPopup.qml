import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../components"
import "../Singletons"

/**
 * Dedicated display brightness popup card:
 *   - Sun glyph with live brightness percentage
 *   - Interactive smooth wavy level slider
 *   - Backed by brightnessctl (hardware backlight)
 */
Item {
    id: root

    property bool open: false
    property string barEdge: "top"
    property bool anyHover: false

    signal closeRequested()

    implicitWidth: 260
    implicitHeight: 72
    clip: true

    /* ============ Display brightness (via brightnessctl) ============ */
    property real brightRatio: 0
    property real brightMax: 1
    property real lastBrightWrite: 0

    Process {
        id: brightProbe
        command: ["sh", "-c", 'echo "a b c $(brightnessctl --class backlight get) $(brightnessctl --class backlight max)"']
        stdout: SplitParser {
            onRead: data => {
                const tokens = data.trim().split(/\s+/)
                if (tokens.length < 2) return
                const cur = parseFloat(tokens[tokens.length - 2])
                const mx = parseFloat(tokens[tokens.length - 1])
                if (isNaN(cur) || isNaN(mx) || mx <= 0) return
                root.brightMax = mx
                root.brightRatio = cur / mx
            }
        }
    }

    function refreshBrightness() {
        if (!brightProbe.running) brightProbe.running = true
    }

    function setBrightness(v) {
        root.brightRatio = v
        root.lastBrightWrite = Date.now()
        Quickshell.execDetached(["brightnessctl", "--class", "backlight", "s",
            String(Math.round(v * root.brightMax)), "--quiet"])
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.open
        onTriggered: {
            if (Date.now() - root.lastBrightWrite > 1500)
                root.refreshBrightness()
        }
    }

    property bool animatingOut: false
    onOpenChanged: {
        if (root.open) {
            root.refreshBrightness()
            root.animatingOut = false
            animatingOutTimer.stop()
        } else {
            root.animatingOut = true
            animatingOutTimer.restart()
        }
    }
    Timer {
        id: animatingOutTimer
        interval: 200
        onTriggered: root.animatingOut = false
    }

    property string barMode: "notch"
    property real notchOpacity: 0.96

    readonly property string fillPath: {
        const w = card.width
        const h = card.height
        if (root.barMode === "notch") {
            const r = 16
            if (root.barEdge === "bottom") {
                return `M 0 ${r} A ${r} ${r} 0 0 1 ${r} 0 L ${w} 0 L ${w} ${h} L 0 ${h} Z`
            }
            return `M 0 ${r} A ${r} ${r} 0 0 1 ${r} 0 L ${w} 0 L ${w} ${h} L ${r} ${h} A ${r} ${r} 0 0 1 0 ${h - r} Z`
        }
        const r = 16
        return `M ${r} 0 L ${w - r} 0 A ${r} ${r} 0 0 1 ${w} ${r} L ${w} ${h - r} A ${r} ${r} 0 0 1 ${w - r} ${h} L ${r} ${h} A ${r} ${r} 0 0 1 0 ${h - r} L 0 ${r} A ${r} ${r} 0 0 1 ${r} 0 Z`
    }

    readonly property string strokePath: {
        const w = card.width
        const h = card.height
        if (root.barMode === "notch") {
            const r = 16
            if (root.barEdge === "bottom") {
                return `M 0 ${h - r} L 0 ${r} A ${r} ${r} 0 0 1 ${r} 0 L ${w} 0`
            }
            return `M 0 ${r} L 0 ${h - r} A ${r} ${r} 0 0 0 ${r} ${h} L ${w} ${h}`
        }
        const r = 16
        return `M ${r} 0 L ${w - r} 0 A ${r} ${r} 0 0 1 ${w} ${r} L ${w} ${h - r} A ${r} ${r} 0 0 1 ${w - r} ${h} L ${r} ${h} A ${r} ${r} 0 0 1 0 ${h - r} L 0 ${r} A ${r} ${r} 0 0 1 ${r} 0 Z`
    }

    Item {
        id: card
        width: parent.width
        height: parent.height

        /* Swallow clicks on the popup card background so they don't dismiss the window */
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {}
        }

        Shape {
            id: cardBgShape
            anchors.fill: parent
            preferredRendererType: Shape.GeometryRenderer
            antialiasing: true
            asynchronous: false

            ShapePath {
                fillColor: root.barMode === "notch" ? (Theme.isDark ? Qt.rgba(0.04, 0.04, 0.06, root.notchOpacity) : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.notchOpacity)) : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.shellOpacity)
                strokeColor: "transparent"
                strokeWidth: 0
                PathSvg { path: root.fillPath }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.open ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.45) : Theme.outline
                strokeWidth: 1
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: root.strokePath }
            }
        }

        opacity: root.open ? 1.0 : 0.0
        scale: root.open ? 1.0 : 0.95
        y: root.open ? 0 : (root.barEdge === "bottom" ? -6 : 6)

        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? 200 : 140
                easing.bezierCurve: Theme.animCurves.expressiveDefaultEffects
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.open ? 280 : 160
                easing.bezierCurve: root.open ? Theme.animCurves.expressiveDefaultSpatial : Theme.animCurves.standardAccel
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: root.open ? 280 : 160
                easing.bezierCurve: root.open ? Theme.animCurves.expressiveDefaultSpatial : Theme.animCurves.standardAccel
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                opacity: root.open ? 1.0 : 0.0
                transform: Translate {
                    y: root.open ? 0 : 6
                    Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Text {
                    text: "light_mode"
                    font.family: Theme.fontIcon
                    font.pixelSize: 18
                    color: Theme.accentLit
                }

                Text {
                    text: "Brightness"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(13)
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: Math.round(root.brightRatio * 100) + "%"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(13)
                    font.weight: Font.DemiBold
                    color: Theme.fgDim
                }
            }

            VolSlider {
                Layout.fillWidth: true
                interactive: true
                active: root.open
                value: root.brightRatio
                fill: Theme.accent
                track: Theme.fgFaint
                knob: Theme.fg
                onChanged: (v) => root.setBrightness(v)
            }
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            root.anyHover = hover.hovered
        }
    }
}
