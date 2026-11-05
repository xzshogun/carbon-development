import QtQuick
import "../Singletons"

/**
 * StaticCarbonLogo:
 * Renders a crisp, static Bohr atomic model of Carbon (atomic number 6)
 * matching the lockscreen aesthetic:
 *   - Central bold "C" glyph
 *   - 2 concentric orbital circumcircles (K-shell and L-shell)
 *   - Inner shell: 2 electron dots (top, bottom)
 *   - Outer shell: 4 electron dots (top, bottom, left, right)
 *   - Reactive to Theme.accent, Theme.fg, and hover state
 */
Item {
    id: root

    implicitWidth: 18
    implicitHeight: 18

    property color accentColor: Theme.accent ? Theme.accent : "#00F0FF"
    property color glyphColor: root.hovered ? (Theme.accentLit ? Theme.accentLit : Theme.accent) : (Theme.fg ? Theme.fg : "#FFFFFF")
    property bool hovered: false

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const cx = width / 2
            const cy = height / 2
            const outerR = Math.max(2, (Math.min(width, height) / 2) - 2.5)
            const innerR = outerR * 0.58

            const col = root.accentColor
            const r = Math.round(col.r * 255)
            const g = Math.round(col.g * 255)
            const b = Math.round(col.b * 255)

            // 1. Draw Outer Orbit Ring (L-shell)
            ctx.beginPath()
            ctx.arc(cx, cy, outerR, 0, 2 * Math.PI)
            ctx.lineWidth = 1.0
            ctx.strokeStyle = `rgba(${r}, ${g}, ${b}, ${root.hovered ? 0.65 : (Theme.isDark ? 0.35 : 0.60)})`
            ctx.stroke()

            // 2. Draw Inner Orbit Ring (K-shell)
            ctx.beginPath()
            ctx.arc(cx, cy, innerR, 0, 2 * Math.PI)
            ctx.lineWidth = 1.0
            ctx.strokeStyle = `rgba(${r}, ${g}, ${b}, ${root.hovered ? 0.75 : (Theme.isDark ? 0.45 : 0.70)})`
            ctx.stroke()

            // Helper to draw filled electron dot
            const dotR = Math.max(1.0, width * 0.07)
            function drawDot(x, y) {
                ctx.beginPath()
                ctx.arc(x, y, dotR, 0, 2 * Math.PI)
                ctx.fillStyle = root.hovered ? "#FFFFFF" : `rgb(${r}, ${g}, ${b})`
                ctx.fill()
            }

            // 3. Inner shell: 2 dots (top, bottom)
            drawDot(cx, cy - innerR)
            drawDot(cx, cy + innerR)

            // 4. Outer shell: 4 dots (top, bottom, left, right)
            drawDot(cx, cy - outerR)
            drawDot(cx, cy + outerR)
            drawDot(cx - outerR, cy)
            drawDot(cx + outerR, cy)
        }
    }

    // Central "C" glyph with precise optical centering
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -0.5
        text: "C"
        font.family: Theme.font
        font.pixelSize: Math.max(7, Math.round(root.width * 0.42))
        font.bold: true
        color: root.glyphColor
        scale: root.hovered ? 1.08 : 1.0
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Connections {
        target: Theme
        function onAccentChanged() { canvas.requestPaint() }
        function onIsDarkChanged() { canvas.requestPaint() }
    }

    onHoveredChanged: canvas.requestPaint()
    onAccentColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
}
