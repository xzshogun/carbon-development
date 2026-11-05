import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../Singletons"

/**
 * OverviewMod.qml:
 * Carbon Top Deck Filmstrip + Live Stage Workspace Switcher
 *
 * Implements:
 *   1. Pitch-black #040406 backdrop (opacity: 0.92) with subtle 4-edge inward Matugen primary bloom.
 *   2. Top Deck Filmstrip (height: 168): Centered horizontal glass dock with workspace thumbnails 1..10
 *      and miniature proportional window layout rectangles.
 *   3. Live Exploded Center Stage: Dynamic Hyprland Dwindle Grid reflowing windows with OutExpo transitions.
 *   4. 60FPS Spring Drag-and-Drop Proxy with velocity banking tilt and magnetic drop execution.
 *   5. Full Matugen dynamic palette binding (Theme.m3primary, Theme.m3surface, Theme.font).
 */
Item {
    id: root

    property bool open: false
    signal requestClose()

    // ── Matugen Dynamic Palette Binding ─────────────────────────────────
    readonly property color accentColor: Theme.m3primary || Theme.accent || Qt.rgba(0.46, 0.82, 0.98, 1.0)
    readonly property color surfaceColor: Theme.m3surface || Theme.bg || Qt.rgba(0.08, 0.08, 0.12, 0.90)
    readonly property color textColor: Theme.m3onSurface || Theme.fg || Qt.color("#ffffff")
    readonly property color textDimColor: Theme.m3onSurfaceVariant || Theme.fgDim || Qt.rgba(1, 1, 1, 0.65)
    readonly property string mainFont: Theme.font || "Plus Jakarta Sans, sans-serif"

    // ── Live Workspace & Window Data ────────────────────────────────────
    property var workspacesList: []
    property int activeWsId: 1
    property int selectedWorkspaceId: 1
    property int hoveredWorkspaceId: -1
    property int monitorWidth: 1366
    property int monitorHeight: 768

    // ── Drag & Drop Physics State ───────────────────────────────────────
    property bool isDragging: false
    property var draggingWindow: null // { address, title, class, appName, icon, sourceWsId, originX, originY }
    property real targetMouseX: 0.0
    property real targetMouseY: 0.0
    property bool isDropping: false

    // ── Smooth Entrance & Exit Transitions ──────────────────────────────
    property real enterProgress: 0.0
    property real exitProgress: 0.0
    property bool isClosing: false

    ParallelAnimation {
        id: enterAnim
        NumberAnimation {
            target: root
            property: "enterProgress"
            from: 0.0
            to: 1.0
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation {
            target: root
            property: "exitProgress"
            from: 0.0
            to: 1.0
            duration: 180
            easing.type: Easing.InCubic
        }
        onFinished: {
            root.isClosing = false
            root.exitProgress = 0.0
            root.enterProgress = 0.0
            root.requestClose()
        }
    }

    function closeWithAnimation() {
        if (root.isClosing) return
        root.isClosing = true
        exitAnim.restart()
    }

    // ── Data Acquisition Process ────────────────────────────────────────
    Process {
        id: dataProbe
        command: ["python3", (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/carbon-overview-data.py"]
        stdout: StdioCollector {
            id: dataCol
            waitForEnd: true
        }
        onExited: (exitCode, exitStatus) => {
            try {
                var txt = String(dataCol.text).trim()
                if (txt.length > 0) {
                    var parsed = JSON.parse(txt)
                    root.activeWsId = parsed.activeWorkspace || 1
                    if (parsed.monitor) {
                        root.monitorWidth = parsed.monitor.width || 1366
                        root.monitorHeight = parsed.monitor.height || 768
                    }
                    root.workspacesList = parsed.workspaces || []

                    // On initial open, default selected workspace to currently active workspace
                    if (root.enterProgress < 0.1 && !root.isDragging) {
                        root.selectedWorkspaceId = root.activeWsId
                    }
                }
            } catch (e) {
                console.log("[OverviewMod] Data parse error:", e)
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 1200
        repeat: true
        running: root.open && !root.isDragging
        onTriggered: {
            if (!dataProbe.running) dataProbe.running = true
        }
    }

    Process {
        id: moveProc
        onExited: (exitCode, exitStatus) => {
            pollTimer.restart()
            if (!dataProbe.running) dataProbe.running = true
        }
    }

    Component.onCompleted: {
        root.cancelDrag()
        if (root.open) {
            root.isClosing = false
            root.exitProgress = 0.0
            enterAnim.restart()
            if (!dataProbe.running) dataProbe.running = true
            root.forceActiveFocus()
        }
    }

    onOpenChanged: {
        root.cancelDrag()
        if (root.open) {
            root.isClosing = false
            root.exitProgress = 0.0
            enterAnim.restart()
            if (!dataProbe.running) dataProbe.running = true
            root.forceActiveFocus()
        }
    }

    // ── Hyprland Action Helpers ─────────────────────────────────────────
    function jumpToWorkspace(wid) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + wid + "\" })")
        root.closeWithAnimation()
    }

    function focusWindow(wid, addr) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + wid + "\" })")
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + addr + "\" })")
        root.closeWithAnimation()
    }

    function closeWindow(addr) {
        Hyprland.dispatch("hl.dsp.window.close({ window = \"address:" + addr + "\" })")
        pollTimer.restart()
        if (!dataProbe.running) dataProbe.running = true
    }

    function moveWindowToWorkspace(addr, targetWid) {
        var dispatchCmd = "hl.dsp.window.move({ workspace = " + targetWid + ", window = 'address:" + addr + "', silent = true })"
        Hyprland.dispatch(dispatchCmd)
        moveProc.command = ["hyprctl", "dispatch", dispatchCmd]
        moveProc.running = true

        // Optimistic UI update: instantly move window in local state
        var foundWin = null
        var newWsList = JSON.parse(JSON.stringify(root.workspacesList))
        for (var i = 0; i < newWsList.length; i++) {
            var ws = newWsList[i]
            if (ws.windows) {
                for (var j = 0; j < ws.windows.length; j++) {
                    if (ws.windows[j].address === addr) {
                        foundWin = ws.windows.splice(j, 1)[0]
                        break
                    }
                }
            }
            if (foundWin) break
        }

        if (foundWin) {
            var targetWs = null
            for (var k = 0; k < newWsList.length; k++) {
                if (newWsList[k].id === targetWid) {
                    targetWs = newWsList[k]
                    break
                }
            }
            if (targetWs) {
                if (!targetWs.windows) targetWs.windows = []
                targetWs.windows.push(foundWin)
            } else {
                newWsList.push({
                    id: targetWid,
                    name: "Workspace " + targetWid,
                    isActive: (targetWid === root.activeWsId),
                    windows: [foundWin]
                })
                newWsList.sort(function(a, b) { return a.id - b.id })
            }
            root.workspacesList = newWsList
        }
    }

    function getWindowsForWorkspace(wid) {
        for (var i = 0; i < root.workspacesList.length; i++) {
            if (root.workspacesList[i].id === wid) {
                return root.workspacesList[i].windows || []
            }
        }
        return []
    }

    // ── Dwindle Grid Layout Algorithm ───────────────────────────────────
    function getWindowCardGeometry(index, count, areaW, areaH) {
        var margin = 20
        var gap = 16
        var w = Math.max(100, areaW - margin * 2)
        var h = Math.max(100, areaH - margin * 2)

        if (count <= 1) {
            return { x: margin, y: margin, width: w, height: h }
        }
        if (count === 2) {
            var cardW = (w - gap) / 2
            return {
                x: margin + index * (cardW + gap),
                y: margin,
                width: cardW,
                height: h
            }
        }
        if (count === 3) {
            var masterW = (w - gap) * 0.52
            var stackW = (w - gap) * 0.48
            var stackH = (h - gap) / 2
            if (index === 0) {
                return { x: margin, y: margin, width: masterW, height: h }
            } else if (index === 1) {
                return { x: margin + masterW + gap, y: margin, width: stackW, height: stackH }
            } else {
                return { x: margin + masterW + gap, y: margin + stackH + gap, width: stackW, height: stackH }
            }
        }
        if (count === 4) {
            var cW = (w - gap) / 2
            var cH = (h - gap) / 2
            var col = index % 2
            var row = Math.floor(index / 2)
            return {
                x: margin + col * (cW + gap),
                y: margin + row * (cH + gap),
                width: cW,
                height: cH
            }
        }
        // 5+ windows: balanced grid
        var cols = Math.min(4, Math.ceil(count / 2))
        var rows = Math.ceil(count / cols)
        var gridW = (w - (cols - 1) * gap) / cols
        var gridH = (h - (rows - 1) * gap) / rows
        var c = index % cols
        var r = Math.floor(index / cols)
        return {
            x: margin + c * (gridW + gap),
            y: margin + r * (gridH + gap),
            width: gridW,
            height: gridH
        }
    }

    // ── Drag & Drop Management ──────────────────────────────────────────
    function startDrag(winData, srcWsId, startX, startY, origX, origY) {
        root.isDropping = false
        root.draggingWindow = {
            address: winData.address,
            title: winData.title || "",
            class: winData.class || "",
            appName: winData.appName || winData.class || "App",
            icon: winData.icon || "",
            sourceWsId: srcWsId,
            originX: origX,
            originY: origY
        }
        root.targetMouseX = startX
        root.targetMouseY = startY
        dragProxy.x = startX - dragProxy.width / 2
        dragProxy.y = startY - dragProxy.height / 2
        root.isDragging = true
        root.hoveredWorkspaceId = -1
    }

    function cancelDrag() {
        root.isDragging = false
        root.isDropping = false
        root.draggingWindow = null
        root.hoveredWorkspaceId = -1
    }

    function executeDrop() {
        if (!root.isDragging || !root.draggingWindow) return
        var targetWid = root.hoveredWorkspaceId
        var winAddr = root.draggingWindow.address
        var srcWid = root.draggingWindow.sourceWsId

        if (targetWid > 0 && targetWid !== srcWid) {
            // Magnetic drop into top filmstrip card
            root.isDropping = true
            root.moveWindowToWorkspace(winAddr, targetWid)
            dropSnapAnim.restart()
        } else {
            // Spring back to origin card
            root.cancelDrag()
        }
    }

    // ── Keyboard Navigation ─────────────────────────────────────────────
    focus: root.open
    Keys.onEscapePressed: (event) => {
        event.accepted = true
        root.closeWithAnimation()
    }
    Keys.onLeftPressed: (event) => {
        event.accepted = true
        root.cycleWorkspace(-1)
    }
    Keys.onRightPressed: (event) => {
        event.accepted = true
        root.cycleWorkspace(1)
    }
    Keys.onTabPressed: (event) => {
        event.accepted = true
        root.cycleWorkspace(1)
    }
    Keys.onBacktabPressed: (event) => {
        event.accepted = true
        root.cycleWorkspace(-1)
    }
    Keys.onReturnPressed: (event) => {
        event.accepted = true
        root.jumpToWorkspace(root.selectedWorkspaceId)
    }
    Keys.onEnterPressed: (event) => {
        event.accepted = true
        root.jumpToWorkspace(root.selectedWorkspaceId)
    }

    function cycleWorkspace(step) {
        var count = Math.max(10, root.workspacesList.length)
        var nextId = root.selectedWorkspaceId + step
        if (nextId < 1) nextId = count
        if (nextId > count) nextId = 1
        root.selectedWorkspaceId = nextId
    }

    // ── 1. Pitch-Black #040406 Backdrop with 4-Edge Matugen Bloom ───────
    Rectangle {
        id: pitchBlackBg
        anchors.fill: parent
        z: 0
        color: "#040406"
        opacity: 0.92 * root.enterProgress * (1.0 - root.exitProgress)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeWithAnimation()
        }
    }

    // Edge Gradient Inward Blooms
    Item {
        id: ambientEdgeGlows
        anchors.fill: parent
        z: 1
        opacity: root.enterProgress * (1.0 - root.exitProgress)

        // Top edge bloom
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 52
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        // Bottom edge bloom
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 52
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22) }
            }
        }
        // Left edge bloom
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: 52
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        // Right edge bloom
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 52
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22) }
            }
        }
    }

    // ── 2. Top Deck Filmstrip (Top 24%, height: 168, anchored at top) ────
    Item {
        id: topDeckContainer
        anchors.top: parent.top
        anchors.topMargin: 24
        anchors.left: parent.left
        anchors.right: parent.right
        height: 168
        z: 20
        opacity: root.enterProgress * (1.0 - root.exitProgress)
        transformOrigin: Item.Top
        scale: 0.95 + 0.05 * root.enterProgress

        // Centered Horizontal Glass Dock
        Rectangle {
            id: filmstripDock
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            height: 168
            width: Math.min(parent.width - 48, filmstripRow.width + 40)
            radius: 18
            color: Qt.rgba(0.06, 0.06, 0.08, 0.82)
            border.width: 1
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25)
            clip: true

            Flickable {
                id: filmstripFlickable
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                contentWidth: filmstripRow.width
                contentHeight: height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                interactive: !root.isDragging

                Row {
                    id: filmstripRow
                    spacing: 14
                    anchors.verticalCenter: parent.verticalCenter

                    // Workspaces 1..10 thumbnails
                    Repeater {
                        model: 10

                        delegate: Rectangle {
                            id: wsCard
                            readonly property int wsId: index + 1
                            readonly property bool isCurrent: (root.selectedWorkspaceId === wsId)
                            readonly property bool isActiveWs: (root.activeWsId === wsId)
                            readonly property bool isDropTarget: (root.isDragging && root.hoveredWorkspaceId === wsId)
                            readonly property var wsWindows: root.getWindowsForWorkspace(wsId)

                            width: 186
                            height: 124
                            radius: 12

                            // Cairo translucent glass-tape highlight style
                            color: isDropTarget
                                   ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                                   : (isCurrent
                                      ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.38)
                                      : Qt.rgba(0.12, 0.13, 0.17, 0.65))

                            border.width: (isDropTarget || isCurrent) ? 2 : 1
                            border.color: (isDropTarget || isCurrent)
                                          ? Qt.lighter(root.accentColor, 1.35)
                                          : Qt.rgba(1, 1, 1, 0.08)

                            scale: isDropTarget ? 1.08 : (isCurrent ? 1.03 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 180 } }
                            Behavior on border.color { ColorAnimation { duration: 180 } }

                            // Card Header: Index pill badge + window count
                            RowLayout {
                                id: cardHeader
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 8
                                height: 20

                                Rectangle {
                                    width: 30
                                    height: 18
                                    radius: 9
                                    color: isCurrent ? root.accentColor : Qt.rgba(1, 1, 1, 0.12)

                                    Text {
                                        anchors.centerIn: parent
                                        text: wsCard.wsId < 10 ? ("0" + wsCard.wsId) : String(wsCard.wsId)
                                        font.family: root.mainFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: isCurrent ? (Theme.m3onPrimary || "#000000") : root.textColor
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Active workspace live indicator dot
                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: root.accentColor
                                    visible: wsCard.isActiveWs
                                }

                                Text {
                                    text: wsCard.wsWindows.length > 0 ? (wsCard.wsWindows.length + " win") : ""
                                    font.family: root.mainFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: root.textDimColor
                                    visible: text.length > 0
                                }
                            }

                            // Live miniature proportional preview area
                            Rectangle {
                                id: miniPreviewArea
                                anchors.top: cardHeader.bottom
                                anchors.topMargin: 4
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                radius: 8
                                z: 2
                                color: Qt.rgba(0.04, 0.04, 0.06, 0.55)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.05)
                                clip: true

                                // Miniature preview area background click & fallback drag
                                MouseArea {
                                    id: miniPreviewBgMouse
                                    anchors.fill: parent
                                    z: 0
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true

                                    property real pressX: 0
                                    property real pressY: 0
                                    property bool dragInitiated: false

                                    onPressed: (mouse) => {
                                        pressX = mouse.x
                                        pressY = mouse.y
                                        dragInitiated = false
                                    }

                                    onPositionChanged: (mouse) => {
                                        if (pressed) {
                                            var dx = mouse.x - pressX
                                            var dy = mouse.y - pressY
                                            var distSq = dx * dx + dy * dy

                                            var pt = miniPreviewBgMouse.mapToItem(root, mouse.x, mouse.y)
                                            root.targetMouseX = pt.x
                                            root.targetMouseY = pt.y

                                            if (!dragInitiated && distSq > 36 && wsCard.wsWindows.length > 0) {
                                                dragInitiated = true
                                                var firstWin = wsCard.wsWindows[0]
                                                var origPt = miniPreviewArea.mapToItem(root, 0, 0)
                                                root.startDrag(firstWin, wsCard.wsId, pt.x, pt.y, origPt.x, origPt.y)
                                            }

                                            if (root.isDragging) {
                                                root.hitTestTopFilmstrip(pt.x, pt.y)
                                            }
                                        }
                                    }

                                    onReleased: (mouse) => {
                                        if (dragInitiated) {
                                            dragInitiated = false
                                            root.executeDrop()
                                        } else {
                                            root.selectedWorkspaceId = wsCard.wsId
                                        }
                                    }

                                    onDoubleClicked: {
                                        if (!dragInitiated) {
                                            root.jumpToWorkspace(wsCard.wsId)
                                        }
                                    }

                                    onCanceled: {
                                        if (dragInitiated) {
                                            dragInitiated = false
                                            root.cancelDrag()
                                        }
                                    }
                                }

                                // Miniature Proportional Window Rectangles (App Previews)
                                Repeater {
                                    model: wsCard.wsWindows

                                    delegate: Rectangle {
                                        id: miniWinRect
                                        z: 1
                                        readonly property var win: modelData
                                        readonly property real pW: miniPreviewArea.width
                                        readonly property real pH: miniPreviewArea.height
                                        readonly property bool isBeingDragged: (root.isDragging && root.draggingWindow && root.draggingWindow.address === win.address)

                                        x: {
                                            if (win.at && root.monitorWidth > 0) {
                                                return Math.max(2, Math.min(pW - width - 2, (win.at[0] / root.monitorWidth) * pW))
                                            }
                                            return 4 + (index % 3) * 36
                                        }
                                        y: {
                                            if (win.at && root.monitorHeight > 0) {
                                                return Math.max(2, Math.min(pH - height - 2, (win.at[1] / root.monitorHeight) * pH))
                                            }
                                            return 4 + Math.floor(index / 3) * 24
                                        }
                                        width: {
                                            if (win.size && root.monitorWidth > 0) {
                                                return Math.max(18, Math.min(pW - 4, (win.size[0] / root.monitorWidth) * pW))
                                            }
                                            return Math.max(20, (pW - 12) / Math.max(1, wsCard.wsWindows.length))
                                        }
                                        height: {
                                            if (win.size && root.monitorHeight > 0) {
                                                return Math.max(12, Math.min(pH - 4, (win.size[1] / root.monitorHeight) * pH))
                                            }
                                            return Math.max(14, pH - 8)
                                        }
                                        radius: 4
                                        color: isBeingDragged
                                               ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.20)
                                               : ((wsCard.isCurrent || wsCard.isDropTarget || miniWinMouse.containsMouse)
                                                  ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                                                  : Qt.rgba(1, 1, 1, 0.16))
                                        border.width: (isBeingDragged || miniWinMouse.containsMouse) ? 1.5 : 1
                                        border.color: (isBeingDragged || miniWinMouse.containsMouse)
                                                      ? Qt.lighter(root.accentColor, 1.30)
                                                      : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.60)

                                        scale: isBeingDragged ? 0.90 : (miniWinMouse.containsMouse ? 1.08 : 1.0)
                                        opacity: isBeingDragged ? 0.35 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                        Behavior on opacity { NumberAnimation { duration: 140 } }

                                        Image {
                                            anchors.centerIn: parent
                                            width: Math.min(14, Math.min(parent.width - 2, parent.height - 2))
                                            height: width
                                            source: Quickshell.iconPath(win.icon || win.class || "", "application-x-executable")
                                            fillMode: Image.PreserveAspectFit
                                            opacity: 0.90
                                            visible: width >= 8
                                        }

                                        // Drag-and-drop MouseArea on the app preview
                                        MouseArea {
                                            id: miniWinMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: dragInitiated ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                            preventStealing: true

                                            property real pressX: 0
                                            property real pressY: 0
                                            property bool dragInitiated: false

                                            onPressed: (mouse) => {
                                                pressX = mouse.x
                                                pressY = mouse.y
                                                dragInitiated = false
                                            }

                                            onPositionChanged: (mouse) => {
                                                if (pressed) {
                                                    var dx = mouse.x - pressX
                                                    var dy = mouse.y - pressY
                                                    var distSq = dx * dx + dy * dy

                                                    var pt = miniWinMouse.mapToItem(root, mouse.x, mouse.y)
                                                    root.targetMouseX = pt.x
                                                    root.targetMouseY = pt.y

                                                    if (!dragInitiated && distSq > 36) {
                                                        dragInitiated = true
                                                        var origPt = miniWinRect.mapToItem(root, 0, 0)
                                                        root.startDrag(win, wsCard.wsId, pt.x, pt.y, origPt.x, origPt.y)
                                                    }

                                                    if (root.isDragging) {
                                                        root.hitTestTopFilmstrip(pt.x, pt.y)
                                                    }
                                                }
                                            }

                                            onReleased: (mouse) => {
                                                if (dragInitiated) {
                                                    dragInitiated = false
                                                    root.executeDrop()
                                                } else {
                                                    root.selectedWorkspaceId = wsCard.wsId
                                                }
                                            }

                                            onDoubleClicked: (mouse) => {
                                                if (!dragInitiated) {
                                                    root.focusWindow(wsCard.wsId, win.address)
                                                }
                                            }

                                            onCanceled: {
                                                if (dragInitiated) {
                                                    dragInitiated = false
                                                    root.cancelDrag()
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Empty"
                                    font.family: root.mainFont
                                    font.pixelSize: 10
                                    color: Qt.rgba(1, 1, 1, 0.25)
                                    visible: wsCard.wsWindows.length === 0
                                }
                            }

                            // Card Click MouseArea (Card Header & Edges)
                            MouseArea {
                                anchors.fill: parent
                                z: 1
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedWorkspaceId = wsCard.wsId
                                }
                                onDoubleClicked: {
                                    root.jumpToWorkspace(wsCard.wsId)
                                }
                            }
                        }
                    }

                    // Empty "+" Workspace Creator Card
                    Rectangle {
                        id: addWsCard
                        width: 72
                        height: 124
                        radius: 12
                        color: Qt.rgba(0.08, 0.09, 0.12, 0.50)
                        border.width: 1
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.20)

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.family: root.mainFont
                            font.pixelSize: 24
                            font.weight: Font.Light
                            color: root.accentColor
                            opacity: 0.70
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedWorkspaceId = 10
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 3. Live Exploded Center Stage (Bottom 76%, Dwindle Grid) ────────
    Item {
        id: centerStage
        anchors.top: topDeckContainer.bottom
        anchors.topMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.left: parent.left
        anchors.leftMargin: 36
        anchors.right: parent.right
        anchors.rightMargin: 36
        z: 10
        opacity: root.enterProgress * (1.0 - root.exitProgress)

        // Stage Workspace Title Pill Header
        RowLayout {
            id: stageHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: 16
            spacing: 12
            height: 32

            Rectangle {
                height: 28
                width: stageTitleText.contentWidth + 24
                radius: 14
                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.40)

                Text {
                    id: stageTitleText
                    anchors.centerIn: parent
                    text: "WORKSPACE 0" + root.selectedWorkspaceId
                    font.family: root.mainFont
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                    color: root.accentColor
                }
            }

            Text {
                readonly property var wins: root.getWindowsForWorkspace(root.selectedWorkspaceId)
                text: wins.length + (wins.length === 1 ? " ACTIVE WINDOW" : " ACTIVE WINDOWS")
                font.family: root.mainFont
                font.pixelSize: 12
                font.weight: Font.Medium
                color: root.textDimColor
            }
        }

        // Live Window Grid Stage Area
        Item {
            id: centerStageArea
            anchors.top: stageHeader.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            readonly property var currentWindows: root.getWindowsForWorkspace(root.selectedWorkspaceId)

            // Empty workspace placeholder
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: centerStageArea.currentWindows.length === 0

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64
                    height: 64
                    radius: 32
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)

                    Text {
                        anchors.centerIn: parent
                        text: "󱂬"
                        font.family: Theme.fontIcon || root.mainFont
                        font.pixelSize: 26
                        color: root.textDimColor
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No active windows on Workspace " + root.selectedWorkspaceId
                    font.family: root.mainFont
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: root.textDimColor
                }
            }

            // Window Cards with Dynamic Dwindle Reflow
            Repeater {
                model: centerStageArea.currentWindows

                delegate: Item {
                    id: windowCardDelegate
                    readonly property var win: modelData
                    readonly property var geom: root.getWindowCardGeometry(index, centerStageArea.currentWindows.length, centerStageArea.width, centerStageArea.height)
                    readonly property bool isBeingDragged: (root.isDragging && root.draggingWindow && root.draggingWindow.address === win.address)

                    x: geom.x
                    y: geom.y
                    width: geom.width
                    height: geom.height
                    z: 5

                    // Smooth Dwindle Grid reflow animations
                    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
                    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
                    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
                    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    // In-place ghost origin slot when dragged
                    opacity: isBeingDragged ? 0.18 : 1.0

                    Rectangle {
                        id: cardBody
                        anchors.fill: parent
                        radius: 14
                        color: cardMouse.containsMouse ? Qt.rgba(0.10, 0.11, 0.16, 0.94) : Qt.rgba(0.08, 0.09, 0.12, 0.88)
                        border.width: 1
                        border.color: cardMouse.containsMouse
                                      ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.55)
                                      : Qt.rgba(1, 1, 1, 0.08)

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        // Card Header: Icon, Title, and Close Button
                        RowLayout {
                            id: winCardHeader
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 12
                            height: 28
                            z: 2

                            Image {
                                width: 22
                                height: 22
                                source: Quickshell.iconPath(win.icon || win.class || "", "application-x-executable")
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                text: win.appName || win.class || "App"
                                font.family: root.mainFont
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: root.textColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Sleek close button
                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: closeMouse.containsMouse ? "#e05353" : Qt.rgba(1, 1, 1, 0.10)
                                z: 3

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    font.family: root.mainFont
                                    font.pixelSize: 16
                                    font.weight: Font.Bold
                                    color: closeMouse.containsMouse ? "#ffffff" : root.textColor
                                }

                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.closeWindow(win.address)
                                    }
                                }
                            }
                        }

                        // Card Center: Large App Icon + Centered Window Title
                        Column {
                            anchors.centerIn: parent
                            spacing: 12
                            width: parent.width - 40

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 72
                                height: 72
                                radius: 20
                                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
                                border.width: 1
                                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25)

                                Image {
                                    anchors.centerIn: parent
                                    width: 48
                                    height: 48
                                    source: Quickshell.iconPath(win.icon || win.class || "", "application-x-executable")
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                text: win.title || win.appName || "Window"
                                font.family: root.mainFont
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: root.textColor
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }

                        // Bottom Status Tag Pills
                        Row {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.margins: 12
                            spacing: 6

                            Rectangle {
                                height: 18
                                width: floatText.contentWidth + 12
                                radius: 9
                                color: Qt.rgba(1, 1, 1, 0.08)
                                visible: Boolean(win.floating)

                                Text {
                                    id: floatText
                                    anchors.centerIn: parent
                                    text: "Floating"
                                    font.family: root.mainFont
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: root.textDimColor
                                }
                            }

                            Rectangle {
                                height: 18
                                width: fsText.contentWidth + 12
                                radius: 9
                                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.20)
                                visible: Boolean(win.fullscreen)

                                Text {
                                    id: fsText
                                    anchors.centerIn: parent
                                    text: "Fullscreen"
                                    font.family: root.mainFont
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: root.accentColor
                                }
                            }
                        }

                        // Interactive MouseArea for Click-to-Focus and Spring-Drag
                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: !root.isDragging
                            cursorShape: root.isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                            property real pressX: 0.0
                            property real pressY: 0.0
                            property bool dragInitiated: false

                            onPressed: (mouse) => {
                                dragInitiated = false
                                pressX = mouse.x
                                pressY = mouse.y
                            }

                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    var dx = mouse.x - pressX
                                    var dy = mouse.y - pressY
                                    var distSq = dx * dx + dy * dy

                                    var pt = cardMouse.mapToItem(root, mouse.x, mouse.y)
                                    root.targetMouseX = pt.x
                                    root.targetMouseY = pt.y

                                    if (!dragInitiated && distSq > 64) {
                                        dragInitiated = true
                                        var origPt = windowCardDelegate.mapToItem(root, 0, 0)
                                        root.startDrag(win, root.selectedWorkspaceId, pt.x, pt.y, origPt.x, origPt.y)
                                    }

                                    // Hit test top deck filmstrip
                                    if (root.isDragging) {
                                        root.hitTestTopFilmstrip(pt.x, pt.y)
                                    }
                                }
                            }

                            onReleased: (mouse) => {
                                if (dragInitiated) {
                                    dragInitiated = false
                                    root.executeDrop()
                                } else {
                                    root.focusWindow(root.selectedWorkspaceId, win.address)
                                }
                            }

                            onCanceled: {
                                if (dragInitiated) {
                                    dragInitiated = false
                                    root.cancelDrag()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Hit-Testing Engine for Top Deck Filmstrip & Center Stage ────────
    function hitTestTopFilmstrip(cursorX, cursorY) {
        var hoveredId = -1
        for (var i = 0; i < 10; i++) {
            var item = filmstripRow.children[i]
            if (item) {
                var pt = item.mapFromItem(root, cursorX, cursorY)
                if (pt.x >= 0 && pt.x <= item.width && pt.y >= 0 && pt.y <= item.height) {
                    hoveredId = i + 1
                    break
                }
            }
        }
        // If not hovering over a filmstrip card, check if cursor is over the center stage
        if (hoveredId === -1 && centerStage) {
            var stagePt = centerStage.mapFromItem(root, cursorX, cursorY)
            if (stagePt.x >= 0 && stagePt.x <= centerStage.width && stagePt.y >= 0 && stagePt.y <= centerStage.height) {
                hoveredId = root.selectedWorkspaceId
            }
        }
        root.hoveredWorkspaceId = hoveredId
    }

    // ── 4. Floating Drag Proxy (z: 500) with 60FPS Velocity Tilt ────────
    Item {
        id: dragProxy
        z: 500
        visible: root.isDragging
        width: 280
        height: 175

        readonly property bool isOverFilmstrip: (root.targetMouseY < topDeckContainer.y + topDeckContainer.height + 40)

        scale: isOverFilmstrip ? 0.68 : 1.06
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        // 60FPS Spring Position & Banking Tilt Physics Driver
        Timer {
            id: physicsTimer
            interval: 16
            running: root.isDragging && !root.isDropping
            repeat: true
            onTriggered: {
                var targetX = root.targetMouseX - dragProxy.width / 2
                var targetY = root.targetMouseY - dragProxy.height / 2

                var vx = targetX - dragProxy.x
                dragProxy.x += vx * 0.32
                dragProxy.y += (targetY - dragProxy.y) * 0.32

                // Velocity banking tilt (-8 to +8 degrees)
                dragProxy.rotation = Math.max(-8, Math.min(8, vx * 0.18))
            }
        }

        ParallelAnimation {
            id: dropSnapAnim
            NumberAnimation {
                target: dragProxy
                property: "scale"
                to: 0.25
                duration: 180
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: dragProxy
                property: "opacity"
                to: 0.0
                duration: 180
                easing.type: Easing.OutCubic
            }
            onFinished: {
                root.cancelDrag()
                dragProxy.opacity = 1.0
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.48)
            border.width: 2
            border.color: Qt.lighter(root.accentColor, 1.40)

            Column {
                anchors.centerIn: parent
                spacing: 10
                width: parent.width - 32

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48
                    height: 48
                    source: Quickshell.iconPath((root.draggingWindow ? root.draggingWindow.icon : "") || "", "application-x-executable")
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: root.draggingWindow ? (root.draggingWindow.title || root.draggingWindow.appName) : ""
                    font.family: root.mainFont
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                // Dynamic Action Pill Badge
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 24
                    width: actionPillText.contentWidth + 20
                    radius: 12
                    color: root.hoveredWorkspaceId > 0 ? root.accentColor : Qt.rgba(0, 0, 0, 0.60)

                    Text {
                        id: actionPillText
                        anchors.centerIn: parent
                        text: {
                            if (root.hoveredWorkspaceId > 0) {
                                var prefix = root.hoveredWorkspaceId < 10 ? "0" : ""
                                if (centerStage && root.targetMouseY >= centerStage.y) {
                                    return "DROP TO STAGE (WS " + prefix + root.hoveredWorkspaceId + ")"
                                }
                                return "DROP TO WORKSPACE " + prefix + root.hoveredWorkspaceId
                            }
                            return "DRAGGING WINDOW"
                        }
                        font.family: root.mainFont
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        color: root.hoveredWorkspaceId > 0 ? (Theme.m3onPrimary || "#000000") : "#ffffff"
                    }
                }
            }
        }
    }
}
