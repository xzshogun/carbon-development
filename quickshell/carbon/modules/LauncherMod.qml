import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * Carbon Launcher: Niagara Launcher style animated application search & browser.
 * Features:
 * - 2D Interactive Draggable Niagara Alphabet Wave Bar (#, A-Z) with dynamic Gaussian stretch
 * - Freely draggable letter bubble chip following pointer anywhere horizontally & vertically
 * - Gaussian liquid wave pulling letters under and around the region into the screen
 * - Spring pop-out launch animation with OutBack overshoot and bezel origin scaling
 * - Clean Niagara section separators (A, B, C...)
 * - Real-time fuzzy app search with keyboard navigation (Up/Down/Enter/Esc)
 * - Built-in command mode (prefixed with ">")
 * - Seamless edge notch connection docking against the screen bezel
 */
Item {
    id: root

    property bool open: false
    signal closeRequested()
    readonly property string home: Quickshell.env("HOME") || ""

    readonly property var cardItem: card
    readonly property bool animatingOut: !root.open && (root.opacity > 0.005 || xAnim.running || scaleAnim.running || opacityAnim.running)

    property string mode: "apps"
    property var allApps: []
    property var letterMap: ({})
    property var activeLettersSet: ({})
    property var letterCounts: ({})
    property var letterOffsets: ({})

    readonly property var alphabet: [
        "#", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
        "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
    ]

    /* ====== Actions (Command Mode ">") ====== */
    readonly property var actions: [
        {
            "id": "wallpaper",
            "name": "Change Wallpaper",
            "desc": "Open the Carbon Wallpaper Picker",
            "glyph": "wallpaper",
            "run": () => {
                root.closeRequested()
                Quickshell.execDetached(["sh", root.home + "/.config/hypr/scripts/carbon-ipc.sh", "wallpaper"])
            }
        },
        {
            "id": "config",
            "name": "Carbon Settings",
            "desc": "Open Carbon Config & Keybind Editor",
            "glyph": "settings",
            "run": () => {
                root.closeRequested()
                Quickshell.execDetached(["python3", root.home + "/.config/hypr/scripts/carbon-config-editor.py"])
            }
        },
        {
            "id": "terminal",
            "name": "Open Terminal",
            "desc": "Launch default terminal emulator",
            "glyph": "terminal",
            "run": () => {
                root.closeRequested()
                Quickshell.execDetached(["kitty"])
            }
        },
        {
            "id": "lock",
            "name": "Lock Screen",
            "desc": "Lock the desktop session with Carbon Lock",
            "glyph": "lock",
            "run": () => {
                root.closeRequested()
                Quickshell.execDetached(["sh", root.home + "/.config/hypr/scripts/carbon-ipc.sh", "lock"])
            }
        },
        {
            "id": "suspend",
            "name": "Suspend System",
            "desc": "Suspend the computer to sleep",
            "glyph": "bedtime",
            "run": () => {
                root.closeRequested()
                Quickshell.execDetached(["systemctl", "suspend"])
            }
        },
        {
            "id": "logout",
            "name": "Log Out",
            "desc": "Exit current desktop session",
            "glyph": "logout",
            "run": () => {
                root.closeRequested()
                Quickshell.execDetached(["sh", "-c", "command -v wlogout >/dev/null && wlogout || hyprctl dispatch exit"])
            }
        }
    ]

    ListModel {
        id: appModel
    }

    ListModel {
        id: actionModel
    }

    function refresh() {
        const raw = searchField.text.trim();
        if (raw.startsWith(">")) {
            root.mode = "actions";
            const needle = raw.slice(1).trim().toLowerCase();
            actionModel.clear();
            for (const a of root.actions) {
                if (!needle || a.name.toLowerCase().includes(needle) || a.id.includes(needle)) {
                    actionModel.append({ "action": a });
                }
            }
            resultsList.currentIndex = actionModel.count > 0 ? 0 : -1;
        } else {
            root.mode = "apps";
            const needle = raw.toLowerCase();
            appModel.clear();

            if (needle.length === 0) {
                // Niagara full alphabetical listing
                let lastLetter = "";
                const newLetterMap = {};
                const newActiveSet = {};
                const newCounts = {};
                const newLetterOffsets = {};
                let runningY = 0;

                for (let i = 0; i < root.allApps.length; i++) {
                    const e = root.allApps[i];
                    const rawChar = (e.name || "").trim().charAt(0).toUpperCase();
                    const letter = (rawChar >= 'A' && rawChar <= 'Z') ? rawChar : "#";
                    const isFirst = (letter !== lastLetter);

                    if (isFirst) {
                        lastLetter = letter;
                        newLetterMap[letter] = i;
                        newActiveSet[letter] = true;
                        newLetterOffsets[letter] = runningY;
                    }

                    newCounts[letter] = (newCounts[letter] || 0) + 1;
                    runningY += isFirst ? 72 : 44;

                    appModel.append({
                        "entry": e,
                        "firstLetter": letter,
                        "isFirstOfLetter": isFirst
                    });
                }

                // Fill gaps so scrubbing through letters with no apps glides seamlessly
                let lastKnownY = 0;
                for (let a = 0; a < root.alphabet.length; a++) {
                    let ch = root.alphabet[a];
                    if (newLetterOffsets[ch] !== undefined) {
                        lastKnownY = newLetterOffsets[ch];
                    } else {
                        newLetterOffsets[ch] = lastKnownY;
                    }
                }

                root.letterMap = newLetterMap;
                root.activeLettersSet = newActiveSet;
                root.letterCounts = newCounts;
                root.letterOffsets = newLetterOffsets;
            } else {
                // Filtered search results
                const matched = [];
                for (const e of root.allApps) {
                    const name = (e.name || "").toLowerCase();
                    let score = -1;
                    if (name.startsWith(needle)) score = 0;
                    else if (name.includes(needle)) score = 1;
                    else if ((e.genericName || "").toLowerCase().includes(needle)) score = 2;
                    else if ((e.comment || "").toLowerCase().includes(needle)) score = 3;
                    if (score >= 0) matched.push({ "e": e, "score": score });
                }
                matched.sort((a, b) => a.score - b.score || a.e.name.localeCompare(b.e.name));

                for (let i = 0; i < matched.length; i++) {
                    appModel.append({
                        "entry": matched[i].e,
                        "firstLetter": "",
                        "isFirstOfLetter": false
                    });
                }
            }
            resultsList.currentIndex = appModel.count > 0 ? 0 : -1;
        }
    }

    function launchEntry(entry) {
        if (!entry) return;
        if (entry.runInTerminal)
            Quickshell.execDetached(["kitty", "-e", "sh", "-c", entry.command.join(" ")]);
        else
            entry.execute();
        root.closeRequested();
    }

    function loadApps() {
        const values = DesktopEntries.applications.values || [];
        const list = [];
        for (let i = 0; i < values.length; i++) {
            const e = values[i];
            if (e.noDisplay || !e.name || !e.command || e.command.length === 0) continue;
            list.push(e);
        }
        list.sort((a, b) => a.name.localeCompare(b.name));
        root.allApps = list;
        root.refresh();
    }

    function resetToApps() {
        root.mode = "apps";
        searchField.text = "";
        root.refresh();
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.loadApps();
        }
    }

    Component.onCompleted: {
        root.loadApps();
    }

    onOpenChanged: {
        if (root.open) {
            searchField.text = "";
            root.loadApps();
            openTimer.restart();
        }
    }

    onVisibleChanged: {
        if (root.visible && root.open) {
            searchField.text = "";
            root.loadApps();
            openTimer.restart();
        }
    }

    Timer {
        id: openTimer
        interval: 110
        onTriggered: searchField.forceActiveFocus()
    }

    /* Edge docking & notch geometry */
    property string barEdge: "top"
    readonly property string attachedEdge: (root.barEdge === "right") ? "right" : "left"

    readonly property real filletRadius: 20
    readonly property real cornerRadius: 16

    readonly property string notchFillPath: {
        const w = root.width
        const h = root.height
        const rf = root.filletRadius
        const rc = root.cornerRadius
        if (root.attachedEdge === "left") {
            return `M 0 0 A ${rf} ${rf} 0 0 0 ${rf} ${rf} L ${w - rc} ${rf} A ${rc} ${rc} 0 0 1 ${w} ${rf + rc} L ${w} ${h - (rf + rc)} A ${rc} ${rc} 0 0 1 ${w - rc} ${h - rf} L ${rf} ${h - rf} A ${rf} ${rf} 0 0 0 0 ${h} Z`
        } else {
            return `M ${w} 0 A ${rf} ${rf} 0 0 1 ${w - rf} ${rf} L ${rc} ${rf} A ${rc} ${rc} 0 0 0 0 ${rf + rc} L 0 ${h - (rf + rc)} A ${rc} ${rc} 0 0 0 ${rc} ${h - rf} L ${w - rf} ${h - rf} A ${rf} ${rf} 0 0 1 ${w} ${h} Z`
        }
    }

    readonly property string notchStrokePath: {
        const w = root.width
        const h = root.height
        const rf = root.filletRadius
        const rc = root.cornerRadius
        if (root.attachedEdge === "left") {
            return `M 0 0 A ${rf} ${rf} 0 0 0 ${rf} ${rf} L ${w - rc} ${rf} A ${rc} ${rc} 0 0 1 ${w} ${rf + rc} L ${w} ${h - (rf + rc)} A ${rc} ${rc} 0 0 1 ${w - rc} ${h - rf} L ${rf} ${h - rf} A ${rf} ${rf} 0 0 0 0 ${h}`
        } else {
            return `M ${w} 0 A ${rf} ${rf} 0 0 1 ${w - rf} ${rf} L ${rc} ${rf} A ${rc} ${rc} 0 0 0 0 ${rf + rc} L 0 ${h - (rf + rc)} A ${rc} ${rc} 0 0 0 ${rc} ${h - rf} L ${w - rf} ${h - rf} A ${rf} ${rf} 0 0 1 ${w} ${h}`
        }
    }

    width: 340
    height: Math.min(640, parent ? Math.round(parent.height * 0.76) : 640)

    x: {
        if (!parent) return 0
        if (root.attachedEdge === "left") {
            return root.open ? 0 : (-width - 32)
        } else {
            return root.open ? (parent.width - width) : (parent.width + 32)
        }
    }
    y: parent ? Math.round((parent.height - height) / 2) : 0

    scale: root.open ? 1.0 : 0.88
    transformOrigin: root.attachedEdge === "left" ? Item.Left : Item.Right
    opacity: root.open ? 1.0 : 0.0

    Behavior on x {
        NumberAnimation {
            id: xAnim
            duration: root.open ? 340 : 200
            easing.type: root.open ? Easing.OutBack : Easing.InQuad
            easing.overshoot: root.open ? 1.35 : 1.0
        }
    }
    Behavior on scale {
        NumberAnimation {
            id: scaleAnim
            duration: root.open ? 340 : 180
            easing.type: root.open ? Easing.OutBack : Easing.InQuad
            easing.overshoot: root.open ? 1.35 : 1.0
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation {
            id: opacityAnim
            duration: root.open ? 220 : 180
            easing.type: root.open ? Easing.OutQuad : Easing.InQuad
        }
    }

    /* Background Card with Bezel Concave Fillet */
    Shape {
        id: card
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false
        layer.enabled: true
        layer.smooth: true

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Theme.bg
            PathSvg { path: root.notchFillPath }
        }

        ShapePath {
            strokeWidth: 1.2
            strokeColor: Qt.alpha(Theme.outline, 0.45)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.notchStrokePath }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }
    }

    /* Top Search Input Box with bounce animation */
    Rectangle {
        id: searchBox
        anchors.top: parent.top
        anchors.topMargin: root.filletRadius + (root.open ? 8 : 0)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 38
        radius: 12
        color: Theme.bgAlt
        border.color: searchField.activeFocus ? Theme.accent : Theme.outline
        border.width: searchField.activeFocus ? 1.5 : 1
        scale: root.open ? 1.0 : 0.92
        opacity: root.open ? 1.0 : 0.0

        Behavior on anchors.topMargin { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Behavior on border.color { ColorAnimation { duration: 160 } }

        /* Ambient glowing search halo */
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 6
            height: parent.height + 6
            radius: parent.radius + 3
            color: "transparent"
            border.color: Qt.alpha(Theme.accent, searchField.activeFocus ? 0.35 : 0.0)
            border.width: 1.5
            opacity: searchField.activeFocus ? 1.0 : 0.0
            scale: searchField.activeFocus ? 1.0 : 0.96
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 180 } }
            z: -1
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "search"
            font.family: Theme.fontIcon
            font.pixelSize: 16
            color: searchField.activeFocus ? Theme.accent : Theme.fgDim
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 34
            anchors.verticalCenter: parent.verticalCenter
            text: "Search apps — type \">\" for commands"
            color: Theme.fgFaint
            font.family: Theme.font
            font.pixelSize: Theme.fontPx(12)
            visible: searchField.text.length === 0
        }

        TextInput {
            id: searchField
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 34
            anchors.rightMargin: 12
            color: Theme.fg
            clip: true
            font.family: Theme.font
            font.pixelSize: Theme.fontPx(13)
            selectByMouse: true
            onTextChanged: root.refresh()
            onAccepted: {
                const it = resultsList.currentItem;
                if (!it) return;
                if (root.mode === "actions")
                    it.action.run();
                else
                    root.launchEntry(it.entry);
            }
            Keys.onDownPressed: resultsList.incrementCurrentIndex()
            Keys.onUpPressed: resultsList.decrementCurrentIndex()
            Keys.onEscapePressed: {
                if (searchField.text.length > 0)
                    searchField.text = ""
                else
                    root.closeRequested()
            }
        }
    }

    /* Pinned / Frequent Quick-Access Apps Row */
    Row {
        id: pinnedAppsRow
        anchors.top: searchBox.bottom
        anchors.topMargin: searchField.text.length === 0 ? 8 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: searchField.text.length === 0 ? 30 : 0
        spacing: 6
        visible: height > 0
        opacity: searchField.text.length === 0 ? 1.0 : 0.0
        clip: true

        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on anchors.topMargin { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

        Repeater {
            model: [
                { name: "Terminal", icon: "terminal", appIcon: "kitty", cmd: "kitty" },
                { name: "Browser",  icon: "public",   appIcon: "firefox", cmd: "brave || firefox || google-chrome-stable" },
                { name: "Files",    icon: "folder",   appIcon: "org.gnome.Nautilus", cmd: "nautilus || dolphin" },
                { name: "Discord",  icon: "forum",    appIcon: "discord", cmd: "discord" },
                { name: "Code",     icon: "code",     appIcon: "com.visualstudio.code.oss", cmd: "code || vscodium" },
                { name: "Config",   icon: "settings", appIcon: "carbon-settings", cmd: "carbon-config-editor || python3 " + root.home + "/.config/hypr/scripts/carbon-config-editor.py" }
            ]

            delegate: Rectangle {
                id: pinnedChip
                required property var modelData
                required property int index

                width: (pinnedAppsRow.width - (5 * pinnedAppsRow.spacing)) / 6
                height: 28
                radius: 8
                color: chipMouse.containsMouse ? Qt.alpha(Theme.accent, 0.20) : Qt.alpha(Theme.fg, 0.06)
                border.color: chipMouse.containsMouse ? Qt.alpha(Theme.accent, 0.50) : Qt.alpha(Theme.outline, 0.35)
                border.width: 1
                scale: chipMouse.containsMouse ? 1.06 : 1.0
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on border.color { ColorAnimation { duration: 100 } }

                Image {
                    id: chipAppIcon
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: pinnedChip.modelData.appIcon ? Quickshell.iconPath(pinnedChip.modelData.appIcon, "") : ""
                    sourceSize: Qt.size(36, 36)
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: chipAppIcon.status !== Image.Ready
                    text: pinnedChip.modelData.icon
                    font.family: Theme.fontIcon
                    font.pixelSize: 16
                    color: chipMouse.containsMouse ? Theme.accent : Theme.fgDim
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closeRequested()
                        Quickshell.execDetached(["sh", "-c", pinnedChip.modelData.cmd])
                    }
                }
            }
        }
    }

    /* Application & Command Results List */
    ListView {
        id: resultsList
        anchors.top: pinnedAppsRow.bottom
        anchors.topMargin: searchField.text.length === 0 ? 6 : 8
        anchors.bottom: quickActionsRow.top
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.attachedEdge === "right" ? (searchField.text.length === 0 ? 36 : 12) : 12
        anchors.rightMargin: root.attachedEdge === "left" ? (searchField.text.length === 0 ? 36 : 12) : 12
        clip: true
        model: root.mode === "apps" ? appModel : actionModel
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: true
        scale: root.open ? 1.0 : 0.95

        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on anchors.leftMargin { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on anchors.rightMargin { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        delegate: Item {
            id: rowItem
            width: resultsList.width
            property var entry: model.entry ?? null
            property var action: model.action ?? null
            readonly property bool isAction: root.mode === "actions"
            readonly property bool showSectionHeader: (root.mode === "apps" && searchField.text.length === 0 && model.isFirstOfLetter)
            height: showSectionHeader ? 72 : 44

            Column {
                anchors.fill: parent

                /* Niagara Alphabet Section Header */
                Item {
                    id: sectionHeader
                    width: parent.width
                    height: 28
                    visible: rowItem.showSectionHeader

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.firstLetter ?? ""
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(13)
                        font.bold: true
                        color: Theme.accent
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 30
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        height: 1
                        color: Qt.alpha(Theme.outline, 0.35)
                    }
                }

                /* App Row Card */
                Rectangle {
                    id: rowCard
                    width: parent.width
                    height: 44
                    radius: 9
                    color: resultsList.currentIndex === index ? Theme.bgActive : (rowArea.containsMouse ? Theme.bgHover : "transparent")

                    Behavior on color { ColorAnimation { duration: 90 } }

                    /* Active indicator pill */
                    Rectangle {
                        x: root.attachedEdge === "left" ? 7 : (parent.width - width - 7)
                        y: 7
                        height: parent.height - 14
                        width: 3
                        radius: 1.5
                        color: Theme.accent
                        visible: resultsList.currentIndex === index
                    }

                    /* Icon Tile */
                    Rectangle {
                        id: iconTile
                        width: 30
                        height: 30
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        color: Theme.bgAlt
                        scale: rowArea.containsMouse ? 1.08 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                        Image {
                            anchors.centerIn: parent
                            visible: !rowItem.isAction
                            width: 20
                            height: 20
                            source: rowItem.entry && rowItem.entry.icon
                                ? Quickshell.iconPath(rowItem.entry.icon, "image-missing")
                                : ""
                            sourceSize: Qt.size(40, 40)
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: rowItem.isAction
                            text: rowItem.action ? rowItem.action.glyph : ""
                            color: Theme.accentLit
                            font.family: Theme.fontIcon
                            font.pixelSize: 16
                        }
                    }

                    /* App Name */
                    Text {
                        id: rowName
                        anchors.top: parent.top
                        anchors.topMargin: 5
                        anchors.left: iconTile.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        text: rowItem.isAction ? (rowItem.action ? rowItem.action.name : "") : (rowItem.entry ? rowItem.entry.name : "")
                        color: rowItem.isAction ? Theme.accentLit : (resultsList.currentIndex === index ? Theme.fg : Theme.fgDim)
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(13)
                        font.weight: resultsList.currentIndex === index ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }

                    /* Description / generic name */
                    Text {
                        id: rowDesc
                        anchors.top: rowName.bottom
                        anchors.topMargin: 2
                        anchors.left: iconTile.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        text: rowItem.isAction
                            ? (rowItem.action ? rowItem.action.desc : "")
                            : (rowItem.entry ? (rowItem.entry.comment || rowItem.entry.genericName || "") : "")
                        color: Theme.fgFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(10)
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            resultsList.currentIndex = index;
                            if (rowItem.isAction)
                                rowItem.action.run();
                            else
                                root.launchEntry(rowItem.entry);
                        }
                    }
                }
            }
        }
    }

    /* ── Niagara 2D Interactive Draggable Alphabet Wave Bar (#, A-Z) ── */
    Item {
        id: niagaraWaveBar
        anchors.top: resultsList.top
        anchors.bottom: resultsList.bottom
        x: root.attachedEdge === "left" ? (parent.width - width - 6) : 6
        width: 26
        z: 10
        visible: root.mode === "apps"
        opacity: searchField.text.length === 0 ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property bool isScrubbing: false
        property real scrubY: 0
        property real inwardPull: 0
        property string activeLetter: ""

        /* Floating Niagara Pop-out Bubble Chip with 2D Drag Tracking */
        Rectangle {
            id: letterBubble
            width: 52
            height: 52
            radius: 26
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.95)
            border.color: Theme.accentLit
            border.width: 2
            z: 20

            x: {
                if (root.attachedEdge === "left") {
                    return niagaraWaveBar.isScrubbing ? (-niagaraWaveBar.inwardPull - width - 12) : -60
                } else {
                    return niagaraWaveBar.isScrubbing ? (niagaraWaveBar.width + niagaraWaveBar.inwardPull + 12) : 34
                }
            }
            y: Math.max(0, Math.min(parent.height - height, niagaraWaveBar.scrubY - height / 2))
            visible: niagaraWaveBar.isScrubbing && niagaraWaveBar.activeLetter !== ""
            opacity: visible ? 1.0 : 0.0
            scale: visible ? 1.0 : 0.4

            Behavior on opacity { NumberAnimation { duration: 100 } }
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

            Column {
                anchors.centerIn: parent
                spacing: 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: niagaraWaveBar.activeLetter
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(22)
                    font.bold: true
                    color: Theme.accentLit
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (root.letterCounts[niagaraWaveBar.activeLetter] || 0) > 0 ? (root.letterCounts[niagaraWaveBar.activeLetter] + " apps") : ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(8)
                    font.weight: Font.Medium
                    color: Theme.fgFaint
                    visible: text.length > 0
                }
            }
        }

        Column {
            id: lettersCol
            anchors.fill: parent

            Repeater {
                id: letterRepeater
                model: root.alphabet

                Item {
                    id: letterItem
                    readonly property string letterChar: modelData
                    readonly property bool hasApps: root.activeLettersSet[letterChar] === true
                    readonly property real itemCenterY: y + height / 2
                    readonly property real dist: Math.abs(itemCenterY - niagaraWaveBar.scrubY)

                    // Pure Gaussian wave: pulls active letter AND surrounding region in a smooth liquid arc
                    readonly property real sigma: 38.0 + Math.min(niagaraWaveBar.inwardPull * 0.28, 65.0)
                    readonly property real waveCurve: niagaraWaveBar.isScrubbing ? Math.exp(- (dist * dist) / (2.0 * sigma * sigma)) : 0.0
                    readonly property real waveMagnitude: 28.0 + Math.min(niagaraWaveBar.inwardPull * 0.88, 200.0)

                    readonly property real xOffset: {
                        var mag = waveCurve * waveMagnitude;
                        return root.attachedEdge === "left" ? -mag : mag;
                    }

                    width: parent.width
                    height: parent.height / root.alphabet.length

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: letterItem.letterChar
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(10)
                        font.bold: letterItem.hasApps && (letterItem.waveCurve > 0.35)
                        color: letterItem.waveCurve > 0.35 ? Theme.accentLit : (letterItem.hasApps ? Theme.fg : Theme.fgFaint)
                        opacity: letterItem.hasApps ? (0.55 + letterItem.waveCurve * 0.45) : (letterItem.waveCurve > 0.25 ? 0.4 : 0.15)
                        scale: 1.0 + letterItem.waveCurve * (0.95 + Math.min(niagaraWaveBar.inwardPull / 200.0, 0.55))
                        x: (parent.width - width) / 2 + letterItem.xOffset

                        Behavior on scale { NumberAnimation { duration: 50 } }
                        Behavior on x { NumberAnimation { duration: 45 } }
                        Behavior on color { ColorAnimation { duration: 60 } }
                        Behavior on opacity { NumberAnimation { duration: 50 } }
                    }
                }
            }
        }

        NumberAnimation {
            id: smoothListScroller
            target: resultsList
            property: "contentY"
            easing.type: Easing.OutCubic
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true

            function updateScrub(mouseX, mouseY) {
                niagaraWaveBar.isScrubbing = true
                niagaraWaveBar.scrubY = Math.max(0, Math.min(parent.height, mouseY))

                // Track horizontal drag across the screen
                if (root.attachedEdge === "left") {
                    niagaraWaveBar.inwardPull = Math.max(0, Math.min(240, -mouseX))
                } else {
                    niagaraWaveBar.inwardPull = Math.max(0, Math.min(240, mouseX - parent.width))
                }

                var letterH = parent.height / root.alphabet.length
                var floatIdx = Math.max(0, Math.min(root.alphabet.length - 1, niagaraWaveBar.scrubY / letterH))
                var idx = Math.floor(floatIdx)
                var nextIdx = Math.min(root.alphabet.length - 1, idx + 1)
                var frac = floatIdx - idx

                var roundIdx = Math.max(0, Math.min(root.alphabet.length - 1, Math.round(floatIdx)))
                var targetLetter = root.alphabet[roundIdx]

                if (niagaraWaveBar.activeLetter !== targetLetter) {
                    niagaraWaveBar.activeLetter = targetLetter
                    if (root.letterMap[targetLetter] !== undefined) {
                        resultsList.currentIndex = root.letterMap[targetLetter]
                    }
                }

                // Continuous interpolation for fluid, buttery-smooth scrolling
                var let0 = root.alphabet[idx]
                var let1 = root.alphabet[nextIdx]
                var y0 = (root.letterOffsets && root.letterOffsets[let0] !== undefined) ? root.letterOffsets[let0] : 0
                var y1 = (root.letterOffsets && root.letterOffsets[let1] !== undefined) ? root.letterOffsets[let1] : y0
                var contY = y0 + (y1 - y0) * frac
                var maxContentY = Math.max(0, resultsList.contentHeight - resultsList.height)
                var targetY = Math.max(0, Math.min(maxContentY, contY))

                var dist = Math.abs(targetY - resultsList.contentY)
                if (dist > 1.0) {
                    smoothListScroller.stop()
                    smoothListScroller.to = targetY
                    smoothListScroller.duration = Math.min(140, Math.max(50, Math.round(dist * 0.12)))
                    smoothListScroller.start()
                }
            }

            onPositionChanged: (mouse) => updateScrub(mouse.x, mouse.y)
            onPressed: (mouse) => updateScrub(mouse.x, mouse.y)
            onReleased: {
                niagaraWaveBar.isScrubbing = false
                niagaraWaveBar.inwardPull = 0
                if (root.letterOffsets && root.letterOffsets[niagaraWaveBar.activeLetter] !== undefined) {
                    var maxContentY = Math.max(0, resultsList.contentHeight - resultsList.height)
                    var targetY = Math.max(0, Math.min(maxContentY, root.letterOffsets[niagaraWaveBar.activeLetter]))
                    smoothListScroller.stop()
                    smoothListScroller.to = targetY
                    smoothListScroller.duration = 180
                    smoothListScroller.easing.type = Easing.OutQuad
                    smoothListScroller.start()
                }
            }
            onExited: {
                if (!pressed) {
                    niagaraWaveBar.isScrubbing = false
                    niagaraWaveBar.inwardPull = 0
                }
            }
        }
    }

    /* Bottom Quick Action Bar with bounce */
    Rectangle {
        id: quickActionsRow
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.filletRadius + (root.open ? 6 : -14)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 32
        radius: 10
        color: Theme.bgAlt
        opacity: root.open ? 1.0 : 0.0

        Behavior on anchors.bottomMargin { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
        Behavior on opacity { NumberAnimation { duration: 240 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 12

            /* Terminal */
            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Text {
                    anchors.centerIn: parent
                    text: "terminal"
                    font.family: Theme.fontIcon
                    font.pixelSize: 16
                    color: termHov.containsMouse ? Theme.accent : Theme.fgDim
                }
                MouseArea {
                    id: termHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closeRequested()
                        Quickshell.execDetached(["kitty"])
                    }
                }
            }

            /* Settings */
            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Text {
                    anchors.centerIn: parent
                    text: "settings"
                    font.family: Theme.fontIcon
                    font.pixelSize: 16
                    color: cfgHov.containsMouse ? Theme.accent : Theme.fgDim
                }
                MouseArea {
                    id: cfgHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closeRequested()
                        Quickshell.execDetached(["python3", root.home + "/.config/hypr/scripts/carbon-config-editor.py"])
                    }
                }
            }

            /* Lock */
            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Text {
                    anchors.centerIn: parent
                    text: "lock"
                    font.family: Theme.fontIcon
                    font.pixelSize: 16
                    color: lockHov.containsMouse ? Theme.accent : Theme.fgDim
                }
                MouseArea {
                    id: lockHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closeRequested()
                        Quickshell.execDetached(["sh", root.home + "/.config/hypr/scripts/carbon-ipc.sh", "lock"])
                    }
                }
            }

            /* Wallpaper Picker */
            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Text {
                    anchors.centerIn: parent
                    text: "wallpaper"
                    font.family: Theme.fontIcon
                    font.pixelSize: 16
                    color: wpHov.containsMouse ? Theme.accent : Theme.fgDim
                }
                MouseArea {
                    id: wpHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closeRequested()
                        Quickshell.execDetached(["sh", root.home + "/.config/hypr/scripts/carbon-ipc.sh", "wallpaper"])
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.mode === "actions" ? "Commands" : (root.allApps.length + " apps")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(10)
                font.weight: Font.DemiBold
                color: Theme.fgFaint
            }
        }
    }
}
