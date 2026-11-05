import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * CarbonCalendar: Modern, sleek, modular calendar UI for Carbon Shell & Nucleus Hub.
 *
 * Designed for full customizability:
 * Tweak the customization properties below to easily change colors,
 * sizing, rounding, fonts, and layout!
 */
Item {
    id: root

    // =========================================================================
    //  CUSTOMIZATION SETTINGS - Tweak these to style your calendar!
    // =========================================================================

    // Sizing & Geometry
    property int cardWidth: 410
    property int cardHeight: 540
    property real cardRadius: 22
    property real dayRadius: 10
    property int dayCellSize: 40

    // Palette & Colors (defaults automatically sync with your system theme)
    property color cardBg: Qt.rgba(19/255, 19/255, 24/255, 0.95)
    property color cardBorderColor: Qt.alpha(Theme.fg, 0.12)
    property real cardBorderWidth: 1.0

    property color accentColor: Theme.accent
    property color accentLitColor: Theme.accentLit
    property color textColor: Theme.fg
    property color textDimColor: Theme.fgDim
    property color textFaintColor: Theme.fgFaint

    property color todayBg: Theme.accent
    property color todayFg: Theme.isDark ? "#111116" : "#ffffff"

    property color selectedBg: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
    property color selectedBorder: Theme.accent

    property color hoverBg: Qt.alpha(Theme.fg, 0.08)

    // Typography
    property string titleFontFamily: "Valley Sans"
    property string bodyFontFamily: "Valley Sans"
    property string iconFontFamily: Theme.fontIcon

    // =========================================================================
    //  STATE & SIGNALS
    // =========================================================================
    property bool open: false
    signal closeRequested()

    readonly property var now: new Date()
    property int currentYear: now.getFullYear()
    property int currentMonth: now.getMonth() // 0-indexed (0 = Jan)
    property int selectedDay: now.getDate()
    property int selectedMonth: now.getMonth()
    property int selectedYear: now.getFullYear()

    property var monthEvents: ({}) // Loaded from carbon-calendar.py

    // Event editing state
    property bool isEditingEvent: false
    property string editingEventId: ""
    property string editingTitle: ""
    property string editingTime: ""
    property string editingDesc: ""

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var weekdayShortNames: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    // Days model for the 6x7 grid
    ListModel { id: daysModel }

    readonly property string calScript: {
        const home = Quickshell.env("HOME") || ""
        const carbonDir = Quickshell.env("CARBON_CONFIG_DIR") || (home + "/.config/carbon")
        return carbonDir + "/scripts/carbon-calendar.py"
    }

    Component.onCompleted: {
        rebuildGrid()
        fetchEvents()
    }

    onCurrentMonthChanged: {
        rebuildGrid()
        fetchEvents()
    }

    onCurrentYearChanged: {
        rebuildGrid()
        fetchEvents()
    }

    onOpenChanged: {
        if (open) {
            isEditingEvent = false
            editingEventId = ""
            calendarCard.forceActiveFocus()
            fetchEvents()
        }
    }

    // =========================================================================
    //  GRID & CALENDAR LOGIC
    // =========================================================================
    function rebuildGrid() {
        daysModel.clear()
        const firstDay = new Date(root.currentYear, root.currentMonth, 1)
        // Monday = 0, Sunday = 6
        const startOffset = (firstDay.getDay() + 6) % 7
        const daysInCurrent = new Date(root.currentYear, root.currentMonth + 1, 0).getDate()
        const daysInPrev = new Date(root.currentYear, root.currentMonth, 0).getDate()

        const todayObj = new Date()

        for (let i = 0; i < 42; i++) {
            let dayNum
            let monthOffset = 0 // -1 = prev, 0 = curr, 1 = next
            let isCurrentMonth = true

            if (i < startOffset) {
                dayNum = daysInPrev - startOffset + i + 1
                monthOffset = -1
                isCurrentMonth = false
            } else if (i >= startOffset + daysInCurrent) {
                dayNum = i - startOffset - daysInCurrent + 1
                monthOffset = 1
                isCurrentMonth = false
            } else {
                dayNum = i - startOffset + 1
                monthOffset = 0
                isCurrentMonth = true
            }

            let cellYear = root.currentYear
            let cellMonth = root.currentMonth + monthOffset
            if (cellMonth < 0) { cellMonth = 11; cellYear-- }
            if (cellMonth > 11) { cellMonth = 0; cellYear++ }

            const isToday = (dayNum === todayObj.getDate() && cellMonth === todayObj.getMonth() && cellYear === todayObj.getFullYear())
            const isSelected = (dayNum === root.selectedDay && cellMonth === root.selectedMonth && cellYear === root.selectedYear)

            const dateKey = cellYear + "-" + String(cellMonth + 1).padStart(2, "0") + "-" + String(dayNum).padStart(2, "0")

            daysModel.append({
                day: dayNum,
                month: cellMonth,
                year: cellYear,
                isCurrentMonth: isCurrentMonth,
                isToday: isToday,
                dateKey: dateKey
            })
        }
    }

    function prevMonth() {
        if (root.currentMonth === 0) {
            root.currentMonth = 11
            root.currentYear--
        } else {
            root.currentMonth--
        }
    }

    function nextMonth() {
        if (root.currentMonth === 11) {
            root.currentMonth = 0
            root.currentYear++
        } else {
            root.currentMonth++
        }
    }

    function jumpToToday() {
        const d = new Date()
        root.selectedDay = d.getDate()
        root.selectedMonth = d.getMonth()
        root.selectedYear = d.getFullYear()
        root.currentMonth = d.getMonth()
        root.currentYear = d.getFullYear()
        rebuildGrid()
    }

    // =========================================================================
    //  EVENT PROCESSORS (LOAD, ADD, EDIT, DELETE)
    // =========================================================================
    Process {
        id: eventProc
        command: ["python3", root.calScript, "--get-month", String(root.currentYear), String(root.currentMonth + 1)]
        stdout: StdioCollector {
            id: eventCollector
            waitForEnd: true
        }
        onExited: {
            try {
                const text = String(eventCollector.text).trim()
                if (text.length > 2) {
                    root.monthEvents = JSON.parse(text)
                } else {
                    root.monthEvents = ({})
                }
            } catch (err) {
                root.monthEvents = ({})
            }
        }
    }

    Process {
        id: addProc
        stdout: StdioCollector { waitForEnd: true }
        onExited: {
            fetchEvents()
            root.isEditingEvent = false
            root.editingEventId = ""
        }
    }

    Process {
        id: editProc
        stdout: StdioCollector { waitForEnd: true }
        onExited: {
            fetchEvents()
            root.isEditingEvent = false
            root.editingEventId = ""
        }
    }

    Process {
        id: deleteProc
        stdout: StdioCollector { waitForEnd: true }
        onExited: {
            fetchEvents()
        }
    }

    function fetchEvents() {
        if (!eventProc.running) {
            eventProc.command = ["python3", root.calScript, "--get-month", String(root.currentYear), String(root.currentMonth + 1)]
            eventProc.running = true
        }
    }

    function getSelectedDateKey() {
        return root.selectedYear + "-" + String(root.selectedMonth + 1).padStart(2, "0") + "-" + String(root.selectedDay).padStart(2, "0")
    }

    function getSelectedEvents() {
        const key = getSelectedDateKey()
        if (root.monthEvents && root.monthEvents[key] && Array.isArray(root.monthEvents[key])) {
            return root.monthEvents[key]
        }
        return []
    }

    function formatSelectedBanner() {
        const d = new Date(root.selectedYear, root.selectedMonth, root.selectedDay)
        const weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return weekdays[d.getDay()] + ", " + root.monthNames[root.selectedMonth] + " " + root.selectedDay + ", " + root.selectedYear
    }

    function startAddEvent() {
        root.editingEventId = ""
        root.editingTitle = ""
        root.editingTime = ""
        root.editingDesc = ""
        root.isEditingEvent = true
        titleInput.text = ""
        timeInput.text = ""
        titleInput.forceActiveFocus()
    }

    function startEditEvent(ev) {
        if (!ev || !ev.is_user) return
        root.editingEventId = ev.id || ""
        root.editingTitle = ev.title || ""
        root.editingTime = (ev.time && ev.time !== "All day") ? ev.time : ""
        root.editingDesc = ev.desc || ""
        root.isEditingEvent = true
        titleInput.text = root.editingTitle
        timeInput.text = root.editingTime
        titleInput.forceActiveFocus()
    }

    function cancelEditing() {
        root.isEditingEvent = false
        root.editingEventId = ""
        calendarCard.forceActiveFocus()
    }

    function saveEvent() {
        const title = titleInput.text.trim()
        if (!title) return
        const timeVal = timeInput.text.trim() || "All day"
        const dateKey = getSelectedDateKey()

        if (root.editingEventId) {
            // Edit existing user event
            if (!editProc.running) {
                editProc.command = ["python3", root.calScript, "--edit", root.editingEventId, "--title", title, "--time", timeVal]
                editProc.running = true
            }
        } else {
            // Add new user event
            if (!addProc.running) {
                addProc.command = ["python3", root.calScript, "--add", dateKey, title, "--time", timeVal]
                addProc.running = true
            }
        }
    }

    function deleteEvent(evId) {
        if (!evId) return
        if (!deleteProc.running) {
            deleteProc.command = ["python3", root.calScript, "--delete", evId]
            deleteProc.running = true
        }
    }

    // =========================================================================
    //  UI LAYOUT
    // =========================================================================
    anchors.fill: parent
    visible: root.open || (backdropRect.opacity > 0.01)
    enabled: root.open

    // Dismiss backdrop
    Rectangle {
        id: backdropRect
        anchors.fill: parent
        color: "#90000000"
        opacity: root.open ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: {
                if (root.isEditingEvent) {
                    root.cancelEditing()
                } else {
                    root.closeRequested()
                }
            }
        }
    }

    // Main Calendar Card
    Rectangle {
        id: calendarCard
        anchors.centerIn: parent
        width: root.cardWidth
        height: root.cardHeight
        radius: root.cardRadius
        color: root.cardBg
        border.color: root.cardBorderColor
        border.width: root.cardBorderWidth
        clip: true

        // Entrance animation: Aesthetic OutBack scale + upward lift glide
        scale: root.open ? 1.0 : 0.88
        opacity: root.open ? 1.0 : 0.0
        transform: Translate {
            y: root.open ? 0 : 26
            Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.16 } }
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        // Keyboard focus
        focus: root.open
        Keys.onEscapePressed: {
            if (root.isEditingEvent) {
                root.cancelEditing()
            } else {
                root.closeRequested()
            }
        }
        Keys.onLeftPressed: {
            if (!root.isEditingEvent) root.prevMonth()
        }
        Keys.onRightPressed: {
            if (!root.isEditingEvent) root.nextMonth()
        }

        // Card Drop Shadow Glow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: root.cardRadius + 1
            color: "transparent"
            border.color: Qt.alpha(root.accentColor, 0.22)
            border.width: 1
            z: -1
        }

        // Prevent click propagation to backdrop
        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // ── 1. HEADER (Title, Month Nav & Close) ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Month & Year title
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: root.monthNames[root.currentMonth]
                        font.family: root.titleFontFamily
                        font.pixelSize: 20
                        font.bold: true
                        color: root.textColor
                    }

                    Text {
                        text: String(root.currentYear)
                        font.family: root.bodyFontFamily
                        font.pixelSize: 12
                        color: root.accentColor
                        font.weight: Font.DemiBold
                    }
                }

                // "Today" Button
                Rectangle {
                    height: 28
                    width: todayTxt.implicitWidth + 16
                    radius: 14
                    color: todayBtnMouse.containsMouse ? Qt.alpha(root.accentColor, 0.20) : Qt.alpha(Theme.fg, 0.06)
                    border.color: Qt.alpha(root.accentColor, 0.35)
                    border.width: 1

                    Text {
                        id: todayTxt
                        anchors.centerIn: parent
                        text: "Today"
                        font.family: root.bodyFontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: todayBtnMouse.containsMouse ? root.accentLitColor : root.textColor
                    }

                    MouseArea {
                        id: todayBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.jumpToToday()
                    }
                }

                // Previous Month Arrow
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: prevMouse.containsMouse ? root.hoverBg : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "chevron_left"
                        font.family: root.iconFontFamily
                        font.pixelSize: 18
                        color: prevMouse.containsMouse ? root.accentLitColor : root.textDimColor
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.prevMonth()
                    }
                }

                // Next Month Arrow
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: nextMouse.containsMouse ? root.hoverBg : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "chevron_right"
                        font.family: root.iconFontFamily
                        font.pixelSize: 18
                        color: nextMouse.containsMouse ? root.accentLitColor : root.textDimColor
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextMonth()
                    }
                }

                // Close Button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: closeMouse.containsMouse ? Qt.alpha("#ff5555", 0.18) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        font.family: root.iconFontFamily
                        font.pixelSize: 16
                        color: closeMouse.containsMouse ? "#ff6b6b" : root.textDimColor
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            // ── 2. WEEKDAY LABELS ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: root.weekdayShortNames
                    delegate: Item {
                        Layout.fillWidth: true
                        height: 18

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.family: root.bodyFontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: (index >= 5) ? root.accentColor : root.textFaintColor
                        }
                    }
                }
            }

            // ── 3. 42-DAY MONTH GRID ──
            Grid {
                id: monthGrid
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 3
                columnSpacing: 4

                readonly property real cellWidth: (monthGrid.width - (6 * columnSpacing)) / 7
                readonly property real cellHeight: 33

                Repeater {
                    model: daysModel
                    delegate: Item {
                        width: monthGrid.cellWidth
                        height: monthGrid.cellHeight

                        readonly property bool isSelectedDay: (model.day === root.selectedDay && model.month === root.selectedMonth && model.year === root.selectedYear)
                        readonly property bool hasEvents: Boolean(root.monthEvents && root.monthEvents[model.dateKey] && root.monthEvents[model.dateKey].length > 0)

                        Rectangle {
                            id: dayCellBg
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height + 4)
                            height: parent.height
                            radius: root.dayRadius

                            // Background color logic
                            color: {
                                if (model.isToday) return root.todayBg
                                if (isSelectedDay) return root.selectedBg
                                if (dayMouse.containsMouse) return root.hoverBg
                                return "transparent"
                            }

                            border.color: {
                                if (isSelectedDay && !model.isToday) return root.selectedBorder
                                if (model.isToday) return root.accentLitColor
                                return "transparent"
                            }
                            border.width: (isSelectedDay || model.isToday) ? 1.5 : 0

                            scale: dayMouse.pressed ? 0.92 : (dayMouse.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 1

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: String(model.day)
                                    font.family: root.bodyFontFamily
                                    font.pixelSize: model.isToday ? 12 : 11
                                    font.bold: model.isToday || isSelectedDay
                                    color: {
                                        if (model.isToday) return root.todayFg
                                        if (!model.isCurrentMonth) return root.textFaintColor
                                        if (isSelectedDay) return root.accentLitColor
                                        return root.textColor
                                    }
                                }

                                // Event indicator dot
                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 4
                                    height: 4
                                    radius: 2
                                    visible: hasEvents
                                    color: model.isToday ? root.todayFg : root.accentColor
                                }
                            }

                            MouseArea {
                                id: dayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedDay = model.day
                                    root.selectedMonth = model.month
                                    root.selectedYear = model.year
                                    if (model.month !== root.currentMonth) {
                                        root.currentMonth = model.month
                                        root.currentYear = model.year
                                    }
                                    if (root.isEditingEvent) {
                                        root.cancelEditing()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(Theme.fg, 0.08)
            }

            // ── 4. SELECTED DATE DETAILS & EVENTS SECTION ──
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                // Section Header: Date label on left, "+ Add" button on right
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "event"
                        font.family: root.iconFontFamily
                        font.pixelSize: 14
                        color: root.accentColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.formatSelectedBanner()
                        font.family: root.bodyFontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: root.textColor
                        elide: Text.ElideRight
                    }

                    // "+ Add" event button (visible when not editing)
                    Rectangle {
                        visible: !root.isEditingEvent
                        height: 24
                        width: addBtnRow.implicitWidth + 14
                        radius: 12
                        color: addBtnMouse.containsMouse ? Qt.alpha(root.accentColor, 0.22) : Qt.alpha(Theme.fg, 0.06)
                        border.color: Qt.alpha(root.accentColor, 0.40)
                        border.width: 1

                        RowLayout {
                            id: addBtnRow
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                text: "add"
                                font.family: root.iconFontFamily
                                font.pixelSize: 13
                                color: root.accentLitColor
                            }

                            Text {
                                text: "Add"
                                font.family: root.bodyFontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: root.textColor
                            }
                        }

                        MouseArea {
                            id: addBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.startAddEvent()
                        }
                    }
                }

                // ── Inline Event Editor (Add / Edit) ──
                Rectangle {
                    visible: root.isEditingEvent
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: Qt.alpha(Theme.fg, 0.04)
                    border.color: Qt.alpha(root.accentColor, 0.35)
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: root.editingEventId ? "Edit Event" : "New Event"
                            font.family: root.bodyFontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: root.accentLitColor
                        }

                        // Title Input
                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: 8
                            color: Qt.alpha(Theme.fg, 0.06)
                            border.color: titleInput.activeFocus ? root.accentColor : Qt.alpha(Theme.fg, 0.12)
                            border.width: 1

                            TextInput {
                                id: titleInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: root.bodyFontFamily
                                font.pixelSize: 11
                                color: root.textColor
                                selectByMouse: true
                                Keys.onReturnPressed: root.saveEvent()
                                Keys.onEscapePressed: root.cancelEditing()

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Event title..."
                                    font.family: root.bodyFontFamily
                                    font.pixelSize: 11
                                    color: root.textFaintColor
                                    visible: !titleInput.text && !titleInput.activeFocus
                                }
                            }
                        }

                        // Time Input
                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            radius: 8
                            color: Qt.alpha(Theme.fg, 0.06)
                            border.color: timeInput.activeFocus ? root.accentColor : Qt.alpha(Theme.fg, 0.12)
                            border.width: 1

                            TextInput {
                                id: timeInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: root.bodyFontFamily
                                font.pixelSize: 11
                                color: root.textColor
                                selectByMouse: true
                                Keys.onReturnPressed: root.saveEvent()
                                Keys.onEscapePressed: root.cancelEditing()

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Time (e.g. 15:00 or All day)..."
                                    font.family: root.bodyFontFamily
                                    font.pixelSize: 11
                                    color: root.textFaintColor
                                    visible: !timeInput.text && !timeInput.activeFocus
                                }
                            }
                        }

                        // Action Buttons: Save & Cancel
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Item { Layout.fillWidth: true }

                            // Cancel Button
                            Rectangle {
                                height: 26
                                width: cancelTxt.implicitWidth + 16
                                radius: 13
                                color: cancelMouse.containsMouse ? Qt.alpha(Theme.fg, 0.12) : Qt.alpha(Theme.fg, 0.06)

                                Text {
                                    id: cancelTxt
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    font.family: root.bodyFontFamily
                                    font.pixelSize: 10
                                    color: root.textColor
                                }

                                MouseArea {
                                    id: cancelMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cancelEditing()
                                }
                            }

                            // Save Button
                            Rectangle {
                                height: 26
                                width: saveTxt.implicitWidth + 18
                                radius: 13
                                color: root.accentColor
                                opacity: saveMouse.containsMouse ? 0.85 : 1.0

                                Text {
                                    id: saveTxt
                                    anchors.centerIn: parent
                                    text: "Save"
                                    font.family: root.bodyFontFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: root.todayFg
                                }

                                MouseArea {
                                    id: saveMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.saveEvent()
                                }
                            }
                        }
                    }
                }

                // ── Events List (Visible when NOT editing) ──
                ListView {
                    id: eventsList
                    visible: !root.isEditingEvent
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: root.getSelectedEvents()

                    delegate: Rectangle {
                        width: eventsList.width
                        height: 32
                        radius: 8
                        color: Qt.alpha(Theme.fg, 0.04)
                        border.color: Qt.alpha(Theme.fg, 0.07)
                        border.width: 1

                        readonly property bool isUserEvent: Boolean(modelData.is_user === true)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                text: modelData.icon || "📌"
                                font.pixelSize: 12
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.title || "Event"
                                font.family: root.bodyFontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.textColor
                                elide: Text.ElideRight
                            }

                            Text {
                                text: modelData.time || ""
                                font.family: root.bodyFontFamily
                                font.pixelSize: 10
                                color: root.accentColor
                                visible: (modelData.time && modelData.time !== "All day")
                            }

                            // Read-only indicator for festivals / holidays
                            Rectangle {
                                visible: !isUserEvent
                                height: 18
                                width: festTagTxt.implicitWidth + 10
                                radius: 9
                                color: Qt.alpha(root.accentColor, 0.12)

                                Text {
                                    id: festTagTxt
                                    anchors.centerIn: parent
                                    text: modelData.category ? (modelData.category.charAt(0).toUpperCase() + modelData.category.slice(1)) : "Holiday"
                                    font.family: root.bodyFontFamily
                                    font.pixelSize: 9
                                    color: root.accentLitColor
                                }
                            }

                            // Edit Button (ONLY for user events)
                            Rectangle {
                                visible: isUserEvent
                                width: 22
                                height: 22
                                radius: 11
                                color: editMouse.containsMouse ? Qt.alpha(root.accentColor, 0.22) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "edit"
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 13
                                    color: editMouse.containsMouse ? root.accentLitColor : root.textDimColor
                                }

                                MouseArea {
                                    id: editMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.startEditEvent(modelData)
                                }
                            }

                            // Delete Button (ONLY for user events)
                            Rectangle {
                                visible: isUserEvent
                                width: 22
                                height: 22
                                radius: 11
                                color: delMouse.containsMouse ? Qt.alpha("#ff5555", 0.20) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "delete"
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 13
                                    color: delMouse.containsMouse ? "#ff6b6b" : root.textDimColor
                                }

                                MouseArea {
                                    id: delMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.deleteEvent(modelData.id)
                                }
                            }
                        }
                    }

                    // Empty state if no events
                    Text {
                        anchors.centerIn: parent
                        text: "No festivals or events scheduled"
                        font.family: root.bodyFontFamily
                        font.pixelSize: 11
                        color: root.textFaintColor
                        visible: eventsList.count === 0
                    }
                }
            }
        }
    }
}
