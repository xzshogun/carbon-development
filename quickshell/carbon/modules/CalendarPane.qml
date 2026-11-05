import QtQuick
import QtQuick.Layouts
import "../Singletons"

/**
 * Carbon calendar pane — a compact month widget for the quick-settings panel.
 * Monday-first week, today ringed by the accent, sibling-month days dimmed.
 */
Item {
    id: root

    readonly property var now: new Date()

    property int year: 0
    property int month: 0

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"]
    readonly property var weekdayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    implicitWidth: 320
    implicitHeight: 292

    ListModel { id: days }

    Component.onCompleted: {
        root.year = root.now.getFullYear()
        root.month = root.now.getMonth()
    }

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
    function today() {
        root.year = root.now.getFullYear()
        root.month = root.now.getMonth()
    }

    onMonthChanged: root.rebuild()
    onYearChanged: root.rebuild()

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: navPrevHov.hovered ? Theme.bgHover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "\u2039"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(20)
                    color: Theme.fgDim
                }
                MouseArea {
                    id: navPrevHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.prev()
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                horizontalAlignment: Text.AlignHCenter
                text: root.monthNames[root.month] + "  " + root.year
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(18)
                font.weight: Font.Bold
                color: Theme.fg
            }

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: navNextHov.hovered ? Theme.bgHover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "\u203A"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(20)
                    color: Theme.fgDim
                }
                MouseArea {
                    id: navNextHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.next()
                }
            }
        }

        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            Repeater {
                model: root.weekdayNames
                delegate: Text {
                    required property string modelData
                    width: 45
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.Bold
                    color: Theme.fgFaint
                }
            }
        }

        Grid {
            columns: 7
            Layout.preferredWidth: 315
            Repeater {
                model: days
                delegate: Rectangle {
                    required property var modelData
                    width: 45
                    height: 32
                    radius: 10
                    color: modelData.today ? Theme.accent
                         : (hov.hovered ? Theme.bgHover : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: modelData.day
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(14)
                        color: modelData.today ? "#0e0e12" : Theme.fgDim
                        opacity: modelData.same ? (modelData.today ? 1 : 0.9) : 0.4
                    }
                    MouseArea {
                        id: hov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.today()
                    }
                }
            }
        }
    }
}