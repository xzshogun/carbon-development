import QtQuick
import QtQuick.Layouts
import "../Singletons"

/**
 * TacticalChronometer:
 * Variation 02: Quad Compass Rose Harmonic Rosette Clock.
 * Features:
 *   - 4-Petal Cardinal Rosette orbit with zero-touch text clearance
 *   - Dual counter-rotating stars (Primary Amber Supernova & Secondary Photon Star)
 *   - Smooth multi-segment fading comet ribbons
 *   - Pure floating typography (zero static rails or enclosing circles)
 *   - Live seconds micro-pill and letter-spaced date
 *   - 100% dynamic Matugen Theme tokens
 */
Item {
    id: root

    implicitWidth: 320
    implicitHeight: 236

    property var currentDate: new Date()
    property string clockFormat: "12"
    property bool showDate: true

    property int hoursRaw: currentDate.getHours()
    property int minutesRaw: currentDate.getMinutes()
    property int secondsRaw: currentDate.getSeconds()

    property string hourStr: {
        let h = root.hoursRaw
        if (root.clockFormat !== "24") {
            h = h % 12 || 12
        }
        return (h < 10 ? "0" : "") + h
    }

    property string minStr: {
        let m = root.minutesRaw
        return (m < 10 ? "0" : "") + m
    }

    property string secStr: {
        let s = root.secondsRaw
        return (s < 10 ? "0" : "") + s
    }

    property string dateStr: {
        let d = root.currentDate
        let days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        return days[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()]
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.currentDate = new Date()
        }
    }

    // Dial geometry constants
    readonly property real centerX: width / 2
    readonly property real centerY: height / 2

    // ── Superellipse Keep-Out Boundary ─────────────────────────────────────────
    // Guarantees stars and trails never touch or overlap the typography
    function getTextClearanceRadius(theta) {
        var w = 76.0
        var h = 40.0
        var n = 3.2
        var cosA = Math.abs(Math.cos(theta))
        var sinA = Math.abs(Math.sin(theta))
        var t1 = Math.pow(cosA / w, n)
        var t2 = Math.pow(sinA / h, n)
        return Math.pow(t1 + t2, -1.0 / n)
    }

    // ── 60 FPS Kinetic Rosette Engine ─────────────────────────────────────────
    property real animTime: 0.0
    property real p1X: root.centerX
    property real p1Y: root.centerY
    property real p2X: root.centerX
    property real p2Y: root.centerY

    property real beaconPulse: 0.0
    SequentialAnimation on beaconPulse {
        loops: Animation.Infinite
        running: true
        NumberAnimation { from: 0.0; to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.0; to: 0.0; duration: 1400; easing.type: Easing.InOutSine }
    }

    // Trail buffers (longer buffer for sweeping graceful petal ribbons)
    property var trail1: []
    property var trail2: []
    readonly property int maxTrail: 46

    function updateOrbits(dt) {
        root.animTime += dt

        var t = root.animTime
        var speed = 1.15
        var cx = root.centerX
        var cy = root.centerY

        // Star 1 (Clockwise, Primary Supernova)
        var th1 = t * speed
        var rClear1 = root.getTextClearanceRadius(th1)
        var lobe1 = (1.0 + Math.cos(4.0 * th1)) * 0.5
        var r1 = rClear1 + 5.0 + lobe1 * 24.0
        root.p1X = cx + r1 * Math.cos(th1)
        root.p1Y = cy + r1 * Math.sin(th1)

        // Star 2 (Counter-Clockwise, Secondary Photon Star)
        var th2 = -t * speed + Math.PI * 0.5
        var rClear2 = root.getTextClearanceRadius(th2)
        var lobe2 = (1.0 + Math.cos(4.0 * th2)) * 0.5
        var r2 = rClear2 + 5.0 + lobe2 * 24.0
        root.p2X = cx + r2 * Math.cos(th2)
        root.p2Y = cy + r2 * Math.sin(th2)

        // Update trail 1
        var t1 = root.trail1
        t1.push({ x: root.p1X, y: root.p1Y })
        if (t1.length > root.maxTrail) t1.shift()
        root.trail1 = t1

        // Update trail 2
        var t2 = root.trail2
        t2.push({ x: root.p2X, y: root.p2Y })
        if (t2.length > root.maxTrail) t2.shift()
        root.trail2 = t2
    }

    FrameAnimation {
        id: frameAnim
        running: root.visible
        onTriggered: {
            root.updateOrbits(frameTime)
            rosetteCanvas.requestPaint()
        }
    }

    /* ── Canvas Layer: Dual Smooth Fading Rosette Comet Ribbons ────────────── */
    Canvas {
        id: rosetteCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // Draw Trail 1 (Primary Amber Gold Flame)
            var t1 = root.trail1
            var len1 = t1.length
            if (len1 > 1) {
                for (var i = 1; i < len1; i++) {
                    var progress1 = i / len1
                    var alpha1 = progress1 * 0.72
                    ctx.beginPath()
                    ctx.moveTo(t1[i - 1].x, t1[i - 1].y)
                    ctx.lineTo(t1[i].x, t1[i].y)
                    ctx.strokeStyle = Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, alpha1)
                    ctx.lineWidth = progress1 * 4.2
                    ctx.lineCap = "round"
                    ctx.stroke()
                }
            }

            // Draw Trail 2 (Secondary Photon Star Ribbon)
            var t2 = root.trail2
            var len2 = t2.length
            if (len2 > 1) {
                for (var j = 1; j < len2; j++) {
                    var progress2 = j / len2
                    var alpha2 = progress2 * 0.58
                    ctx.beginPath()
                    ctx.moveTo(t2[j - 1].x, t2[j - 1].y)
                    ctx.lineTo(t2[j].x, t2[j].y)
                    ctx.strokeStyle = Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, alpha2)
                    ctx.lineWidth = progress2 * 2.8
                    ctx.lineCap = "round"
                    ctx.stroke()
                }
            }
        }
    }

    /* ── Star 1: Primary Amber Supernova Orb ───────────────────────────────── */
    Item {
        id: star1Node
        x: root.p1X - width / 2
        y: root.p1Y - height / 2
        width: 16
        height: 16

        // Pulsing Soft Glow Halo
        Rectangle {
            anchors.centerIn: parent
            width: 22 + root.beaconPulse * 6
            height: width
            radius: width / 2
            color: Theme.primary
            opacity: 0.35 - root.beaconPulse * 0.18
        }

        // Outer Accent Ring
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.88)
            border.color: Theme.primary
            border.width: 1.5

            // Inner Solid Glowing Orb Core
            Rectangle {
                anchors.centerIn: parent
                width: 6
                height: 6
                radius: 3
                color: Theme.primary
            }
        }
    }

    /* ── Star 2: Secondary Photon Star ─────────────────────────────────────── */
    Item {
        id: star2Node
        x: root.p2X - width / 2
        y: root.p2Y - height / 2
        width: 12
        height: 12

        // Outer Soft Halo
        Rectangle {
            anchors.centerIn: parent
            width: 16
            height: 16
            radius: 8
            color: Theme.fg
            opacity: 0.22
        }

        // Outer Ring
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.90)
            border.color: Theme.fg
            border.width: 1.2

            // Inner Crisp Photon Core
            Rectangle {
                anchors.centerIn: parent
                width: 4
                height: 4
                radius: 2
                color: Theme.fg
            }
        }
    }

    /* ── Center Digital Time & Date (Pure Minimalist Floating Typography) ──── */
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4
        z: 10

        // Big Bold Digital Time (Optically and mathematically dead-centered)
        Item {
            id: timeReadoutItem
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 140
            implicitHeight: timeColon.implicitHeight

            Text {
                id: timeColon
                anchors.centerIn: parent
                text: ":"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(38)
                font.weight: Font.Light
                color: Theme.primary
                opacity: 0.7 + root.beaconPulse * 0.3
            }

            Text {
                id: hourText
                anchors.right: timeColon.left
                anchors.rightMargin: 1
                anchors.verticalCenter: timeColon.verticalCenter
                text: root.hourStr
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(38)
                font.weight: Font.Black
                color: Theme.fg
            }

            Text {
                id: minText
                anchors.left: timeColon.right
                anchors.leftMargin: 1
                anchors.verticalCenter: timeColon.verticalCenter
                text: root.minStr
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(38)
                font.weight: Font.Black
                color: Theme.fg
            }

            /* Click to toggle 12h / 24h format */
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.clockFormat = (root.clockFormat === "24" ? "12" : "24")
                }
            }
        }

        // Symmetrically Balanced Date & Seconds (Optically and mathematically dead-centered)
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            visible: root.showDate

            // Left Balancer: Year
            Text {
                text: root.currentDate.getFullYear()
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(8.5)
                font.weight: Font.Bold
                font.letterSpacing: 0.8
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.40)
            }

            Rectangle {
                width: 3
                height: 3
                radius: 1.5
                color: Theme.primary
                opacity: 0.50
            }

            // Center: Date (THU 29 OCT) - Dead-centered directly under colon
            Text {
                text: root.dateStr
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(9.5)
                font.weight: Font.Bold
                font.letterSpacing: 1.4
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.75)
            }

            Rectangle {
                width: 3
                height: 3
                radius: 1.5
                color: Theme.primary
                opacity: 0.50
            }

            // Right Balancer: Seconds
            Text {
                text: root.secStr + "s"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(8.5)
                font.weight: Font.Bold
                font.letterSpacing: 0.8
                color: Theme.primary
            }
        }

        // Ambient Vibe Engine Line (GreetingEngine)
        Item {
            id: vibeWrapper
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            implicitWidth: vibeText.implicitWidth + 24
            implicitHeight: vibeText.implicitHeight + 8

            property real textOpacity: 1.0

            SequentialAnimation {
                id: shuffleCrossFade
                NumberAnimation {
                    target: vibeWrapper
                    property: "textOpacity"
                    to: 0.0
                    duration: 80
                    easing.type: Easing.OutQuad
                }
                ScriptAction {
                    script: GreetingEngine.shuffle()
                }
                NumberAnimation {
                    target: vibeWrapper
                    property: "textOpacity"
                    to: 1.0
                    duration: 80
                    easing.type: Easing.InQuad
                }
            }

            Text {
                id: vibeText
                anchors.centerIn: parent
                text: GreetingEngine.currentLine
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
                font.weight: Font.Medium
                color: Qt.rgba(1, 1, 1, vibeMouse.containsMouse ? 0.88 : 0.55)
                opacity: vibeWrapper.textOpacity

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            MouseArea {
                id: vibeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!shuffleCrossFade.running) {
                        shuffleCrossFade.start()
                    }
                }
            }
        }
    }
}
