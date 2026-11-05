import QtQuick
import "../Singletons"

Item {
    id: root

    property real progress: 0.0
    property real thickness: 2
    property real radius: Math.min(width, height) / 2 - thickness
    property color baseColor: "#2AFFFFFF"
    property color lineColor: Theme.accent

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        readonly property real centerX: width / 2
        readonly property real centerY: height / 2
        readonly property real startAngle: -Math.PI / 2
        readonly property real endAngle: startAngle + (2 * Math.PI * Math.max(0, Math.min(1, root.progress)))

        onEndAngleChanged: requestPaint()

        Connections {
            target: root
            function onProgressChanged() { canvas.requestPaint(); }
            function onBaseColorChanged() { canvas.requestPaint(); }
            function onLineColorChanged() { canvas.requestPaint(); }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const cx = centerX;
            const cy = centerY;
            const r = Math.max(1, root.radius);

            ctx.lineWidth = root.thickness;
            ctx.lineCap = "round";

            // Base track
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, 2 * Math.PI, false);
            ctx.strokeStyle = root.baseColor;
            ctx.stroke();

            // Progress arc
            if (root.progress > 0.001) {
                ctx.beginPath();
                ctx.arc(cx, cy, r, startAngle, endAngle, false);
                ctx.strokeStyle = root.lineColor;
                ctx.stroke();
            }
        }
    }
}
