import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import "../Singletons"

/**
 * CalendarPopup: Ultra-compact, sleek month calendar card appearing directly below the dynamic island.
 * Scaled down to a small, refined footprint as requested.
 */
Item {
    id: root

    property bool open: false
    property string barEdge: "top"
    property bool anyHover: false

    signal closeRequested()

    implicitWidth: 216
    implicitHeight: 206
    width: 216
    height: 206
    clip: true

    readonly property var now: new Date()
    property int year: now.getFullYear()
    property int month: now.getMonth()

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"]
    readonly property var weekdayNames: ["M", "T", "W", "T", "F", "S", "S"]

    ListModel { id: days }

    Component.onCompleted: rebuild()

    function rebuild() {
        days.clear()
        const first = new Date(root.year, root.month, 1)
        const startDay = (first.getDay() + 6) % 7
        const dim = new Date(root.year, root.month + 1, 0).getDate()
        const prevDim = new Date(root.year, root.month, 0).getDate()
        const t = new Date()
        for (let i = 0; i < 42; i++) {
            let d
            let m = root.month
            let yy = root.year
            let same = true
            if (i < startDay) {
                d = prevDim - startDay + i + 1
                m = m - 1
                same = false
            } else if (i >= startDay + dim) {
                d = i - startDay - dim + 1
                m = m + 1
                same = false
            } else {
                d = i - startDay + 1
            }
            if (m < 0) { m = 11; yy-- }
            if (m > 11) { m = 0; yy++ }
            const today = same && d === t.getDate() && m === t.getMonth() && yy === t.getFullYear()
            days.append({ day: d, same: same, today: today })
        }
    }

    function prev() {
        if (root.month === 0) { root.month = 11; root.year-- } else { root.month-- }
    }
    function next() {
        if (root.month === 11) { root.month = 0; root.year++ } else { root.month++ }
    }

    onMonthChanged: root.rebuild()
    onYearChanged: root.rebuild()

    property bool animatingOut: false
    onOpenChanged: {
        if (root.open) {
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
            layer.enabled: true
            layer.smooth: true
            preferredRendererType: Shape.CurveRenderer

            // 1. Fill background (Seamlessly attached: square top, rounded bottom)
            ShapePath {
                fillColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.shellOpacity)
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0; startY: 0
                PathLine { x: card.width; y: 0 }
                PathLine { x: card.width; y: card.height - 20 }
                PathArc { x: card.width - 20; y: card.height; radiusX: 20; radiusY: 20 }
                PathLine { x: 20; y: card.height }
                PathArc { x: 0; y: card.height - 20; radiusX: 20; radiusY: 20 }
                PathLine { x: 0; y: 0 }
            }

            // 2. Continuous stroke (Right, Bottom, Left - NO stroke on top edge to blend seamlessly into the bar)
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.open ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.45) : Theme.outline
                strokeWidth: 1
                startX: card.width; startY: 0
                PathLine { x: card.width; y: card.height - 20 }
                PathArc { x: card.width - 20; y: card.height; radiusX: 20; radiusY: 20 }
                PathLine { x: 20; y: card.height }
                PathArc { x: 0; y: card.height - 20; radiusX: 20; radiusY: 20 }
                PathLine { x: 0; y: 0 }
            }
        }

        opacity: root.open ? 1.0 : 0.0
        y: root.open ? 0 : (root.barEdge === "bottom" ? height : -height)

        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? 180 : 140
                easing.bezierCurve: Theme.animCurves.expressiveDefaultEffects
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: root.open ? 240 : 160
                easing.bezierCurve: root.open ? Theme.animCurves.expressiveDefaultSpatial : Theme.animCurves.standardAccel
            }
        }

        /* Ambient inner border glow */
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4
            opacity: root.open ? 1.0 : 0.0
            y: root.open ? 0 : 8
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            /* ── Month & Navigation Header ── */
            Row {
                width: parent.width
                height: 22

                /* Prev button */
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: prevHov.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "chevron_left"
                        font.family: Theme.fontIcon
                        font.pixelSize: 15
                        color: Theme.fgDim
                    }
                    MouseArea {
                        id: prevHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.prev()
                    }
                }

                /* Month & Year Title */
                Text {
                    width: parent.width - 40
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: root.monthNames[root.month] + " " + root.year
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(11)
                    font.bold: true
                    color: Theme.fg
                }

                /* Next button */
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: nextHov.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "chevron_right"
                        font.family: Theme.fontIcon
                        font.pixelSize: 15
                        color: Theme.fgDim
                    }
                    MouseArea {
                        id: nextHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.next()
                    }
                }
            }

            /* ── Weekday Labels ── */
            Row {
                width: parent.width
                height: 14

                Repeater {
                    model: root.weekdayNames
                    Text {
                        width: parent.width / 7
                        height: parent.height
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(9)
                        font.bold: true
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                    }
                }
            }

            /* ── Days Grid ── */
            Grid {
                id: daysGrid
                width: parent.width
                columns: 7
                rowSpacing: 1
                columnSpacing: 0

                Repeater {
                    model: days
                    Item {
                        width: daysGrid.width / 7
                        height: 22

                        Rectangle {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            radius: 10
                            color: model.today ? Theme.accent : (dayHov.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: String(model.day)
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(10)
                                font.bold: model.today || model.same
                                color: model.today ? "#000000" : (model.same ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.25))
                            }
                        }

                        MouseArea {
                            id: dayHov
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
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
