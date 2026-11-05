import QtQuick

/**
 * Smooth, continuously-animated sine wave line, drawn on a Canvas.
 * Phase advances from wall-clock time (Date.now()) so the line always
 * ripples forward regardless of how/when it's repainted.
 *
 * This is the "wavy line" control-centre visual: a thin stroked sinusoid
 * used as the volume/brightness fill. Amplitude and frequency are driven by
 * the caller, typically scaled from the current value.
 */
Canvas {
    id: root

    property color color: "#EDFF33"
    property real lineWidth: 3
    property real frequency: 2
    property real amplitudeMultiplier: 0.5
    property real fullLength: width
    property bool running: true

    readonly property bool isWindowVisible: Window.window ? (Window.window.visible && Window.window.opacity > 0.01) : true
    readonly property bool shouldAnimate: root.running && root.visible && root.isWindowVisible
        && root.width > 0 && root.height > 0 && root.opacity > 0.01

    onPaint: {
        var ctx = root.getContext("2d")
        ctx.clearRect(0, 0, root.width, root.height)

        if (root.width <= 1 || root.height <= 1) return

        /* Never draw outside the canvas: clamp the amplitude so the stroke
         * (and its round cap) always fits between top and bottom. */
        var amp = Math.min(
            root.lineWidth * root.amplitudeMultiplier,
            Math.max(1, root.height / 2 - root.lineWidth / 2 - 0.5))
        var phase = root.phase
        var centerY = root.height / 2
        var span = Math.max(1, root.fullLength)

        ctx.strokeStyle = root.color
        ctx.lineWidth = root.lineWidth
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.beginPath()

        var step = Math.max(1, Math.floor(root.lineWidth / 2))
        var x = ctx.lineWidth / 2
        ctx.moveTo(x, centerY + amp * Math.sin(root.frequency * 2 * Math.PI * x / span + phase))
        x += step
        for (; x <= root.width - ctx.lineWidth / 2; x += step) {
            var y = centerY + amp * Math.sin(root.frequency * 2 * Math.PI * x / span + phase)
            ctx.lineTo(x, y)
        }

        ctx.stroke()
    }

    property real phase: 0.0
    FrameAnimation {
        running: root.shouldAnimate
        onTriggered: {
            root.phase += frameTime * 2.5
            root.requestPaint()
        }
    }
}