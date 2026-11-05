import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: rootWindow

    title: "Carbon Drop"
    implicitWidth: 640
    implicitHeight: 520
    minimumSize: Qt.size(640, 520)
    maximumSize: Qt.size(640, 520)
    color: "transparent"

    // Visual states: "Idle" | "Uploading" | "Success" | "Error"
    property string appState: "Idle"
    property real uploadProgress: 0.0
    property string uploadStatusText: "Starting..."
    property string currentFileName: ""
    property string currentFilePath: ""
    property string finalUrl: ""
    property string errorMessage: ""
    property bool isPaused: false
    property int enginePid: 0
    property int childPid: 0
    property bool dropdownOpen: false
    property bool isCopied: false

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string enginePath: {
        let envPath = Quickshell.env("CARBON_DROP_ENGINE");
        if (envPath && envPath.length > 0) return envPath;
        if (homeDir.length > 0) {
            return homeDir + "/.local/bin/carbon-drop-engine";
        }
        return "carbon-drop-engine";
    }

    readonly property var hosts: [
        { id: "Buzzheavier", label: "Buzzheavier (10GB+)", desc: "10GB+ heavy transfers • Direct streaming" },
        { id: "filebin.net", label: "filebin.net (5GB+ Raw)", desc: "5GB+ storage • Direct raw playback URL" },
        { id: "x0.at", label: "x0.at (1GB Raw)", desc: "1GB max • Raw link • Discord video embed" },
        { id: "uguu.se", label: "uguu.se (128MB Embed)", desc: "128MB max • 48h temp • Discord embed" },
        { id: "kappa.lol", label: "kappa.lol (100MB Perm)", desc: "100MB max • Permanent raw media link" }
    ]
    property int selectedHostIndex: 0
    readonly property var currentHost: hosts[selectedHostIndex]

    Behavior on uploadProgress {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    onUploadProgressChanged: {
        if (progressArcCanvas.available) {
            progressArcCanvas.requestPaint();
        }
    }

    Timer {
        id: copyTimer
        interval: 1500
        running: false
        repeat: false
        onTriggered: rootWindow.isCopied = false
    }

    function closeApp() {
        if (uploadProcess.running) {
            uploadProcess.running = false;
        }
        if (childPid > 0) {
            Quickshell.execDetached(["kill", "-9", childPid.toString()]);
        }
        Quickshell.execDetached(["sh", "-c", "pkill -f 'CarbonDrop.qml'"]);
        Qt.quit();
    }

    function startUpload(filePath) {
        if (!filePath || filePath.trim().length === 0) return;
        let clean = filePath.trim();
        rootWindow.currentFilePath = clean;
        let parts = clean.split("/");
        rootWindow.currentFileName = parts[parts.length - 1];
        rootWindow.uploadProgress = 0.0;
        rootWindow.uploadStatusText = "Initializing...";
        rootWindow.errorMessage = "";
        rootWindow.finalUrl = "";
        rootWindow.isPaused = false;
        rootWindow.appState = "Uploading";

        uploadProcess.running = false;
        uploadProcess.command = [
            rootWindow.enginePath,
            rootWindow.currentHost.id,
            clean
        ];
        uploadProcess.running = true;
    }

    function togglePause() {
        if (!childPid || childPid <= 0) return;
        if (isPaused) {
            Quickshell.execDetached(["kill", "-CONT", childPid.toString()]);
            isPaused = false;
        } else {
            Quickshell.execDetached(["kill", "-STOP", childPid.toString()]);
            isPaused = true;
        }
    }

    function cancelUpload() {
        if (childPid > 0) {
            Quickshell.execDetached(["kill", "-9", childPid.toString()]);
        }
        if (uploadProcess.running) {
            uploadProcess.running = false;
        }
        isPaused = false;
        appState = "Idle";
        uploadProgress = 0.0;
    }

    function openFilePicker() {
        zenityProcess.running = false;
        zenityProcess.running = true;
    }

    function copyToClipboard() {
        if (finalUrl.length > 0) {
            Quickshell.execDetached(["wl-copy", finalUrl]);
            isCopied = true;
            copyTimer.restart();
        }
    }

    Process {
        id: zenityProcess
        command: ["zenity", "--file-selection", "--title=Select File to Upload with Carbon Drop"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                let p = line.trim();
                if (p.length > 0) {
                    rootWindow.startUpload(p);
                }
            }
        }
    }

    Process {
        id: uploadProcess
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let line = data.trim();
                if (!line) return;
                try {
                    let msg = JSON.parse(line);
                    if (msg.type === "init") {
                        rootWindow.enginePid = msg.pid;
                        rootWindow.childPid = msg.child_pid;
                    } else if (msg.type === "progress") {
                        rootWindow.uploadProgress = msg.percent;
                        rootWindow.uploadStatusText = msg.status;
                    } else if (msg.type === "complete") {
                        rootWindow.uploadProgress = 100.0;
                        rootWindow.finalUrl = msg.url;
                        rootWindow.appState = "Success";
                        Quickshell.execDetached(["wl-copy", msg.url]);
                        rootWindow.isCopied = true;
                        copyTimer.restart();
                    } else if (msg.type === "error") {
                        rootWindow.errorMessage = msg.message;
                        rootWindow.appState = "Error";
                    }
                } catch (e) {
                    console.log("Raw output parsing error:", e, line);
                }
            }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim().length > 0) {
                    console.log("Engine stderr:", data.trim());
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (rootWindow.appState === "Uploading") {
                if (exitCode !== 0) {
                    rootWindow.errorMessage = "Upload failed with exit code " + exitCode;
                    rootWindow.appState = "Error";
                }
            }
        }
    }

    Component.onCompleted: {
        let initialFile = Quickshell.env("CARBON_DROP_FILE");
        if (initialFile && initialFile.length > 0) {
            rootWindow.startUpload(initialFile);
        }
    }

    // Main Card (640 x 520) - Direct content of FloatingWindow
    Rectangle {
        id: mainCard
        anchors.fill: parent
        radius: 16
        color: "#0a0b0e"
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        clip: false

        // Close dropdown when clicking on card background
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (rootWindow.dropdownOpen) {
                    rootWindow.dropdownOpen = false;
                }
            }
        }

        // Header Bar
        Item {
            id: headerBar
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: 44

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16
                spacing: 8

                Text {
                    text: "CARBON // DROP"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 2
                    color: "#ffffff"
                    opacity: 0.85
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: closeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 14
                        color: closeArea.containsMouse ? "#ffffff" : "#71788e"
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rootWindow.closeApp()
                    }
                }
            }
        }

        // Drop Zone Area (592 x 300)
        Item {
            id: dropZoneContainer
            anchors {
                top: headerBar.bottom
                horizontalCenter: parent.horizontalCenter
            }
            width: 592
            height: 300

            Canvas {
                id: dropZoneCanvas
                anchors.fill: parent
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    // Matrix dots: 2px dots, 16px spacing, opacity 0.15
                    ctx.fillStyle = "rgba(255, 255, 255, 0.12)";
                    for (let x = 12; x < width - 6; x += 16) {
                        for (let y = 12; y < height - 6; y += 16) {
                            ctx.fillRect(x, y, 2, 2);
                        }
                    }

                    // Dashed rounded border
                    let isHovered = fileDropArea.containsDrag;
                    ctx.strokeStyle = isHovered ? "#8ee8a8" : "rgba(255, 255, 255, 0.16)";
                    ctx.lineWidth = 3;
                    ctx.setLineDash([8, 6]);

                    let x = 2;
                    let y = 2;
                    let w = width - 4;
                    let h = height - 4;
                    let r = 12;

                    ctx.beginPath();
                    ctx.moveTo(x + r, y);
                    ctx.lineTo(x + w - r, y);
                    ctx.arcTo(x + w, y, x + w, y + r, r);
                    ctx.lineTo(x + w, y + h - r);
                    ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
                    ctx.lineTo(x + r, y + h);
                    ctx.arcTo(x, y + h, x, y + h - r, r);
                    ctx.lineTo(x, y + r);
                    ctx.arcTo(x, y, x + r, y, r);
                    ctx.closePath();
                    ctx.stroke();
                }
            }

            DropArea {
                id: fileDropArea
                anchors.fill: parent
                onEntered: (drag) => {
                    if (rootWindow.appState === "Idle") {
                        drag.accept();
                        dropZoneCanvas.requestPaint();
                    }
                }
                onExited: {
                    dropZoneCanvas.requestPaint();
                }
                onDropped: (drop) => {
                    dropZoneCanvas.requestPaint();
                    if (drop.hasUrls && drop.urls.length > 0) {
                        let rawUrl = drop.urls[0].toString();
                        let cleanPath = rawUrl.replace(/^file:\/\//, "");
                        rootWindow.startUpload(decodeURIComponent(cleanPath));
                    }
                }
            }

            // Click zone to browse when Idle
            MouseArea {
                anchors.fill: parent
                enabled: rootWindow.appState === "Idle"
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (rootWindow.dropdownOpen) {
                        rootWindow.dropdownOpen = false;
                    } else {
                        rootWindow.openFilePicker();
                    }
                }
            }

            // ─── STATE 1: IDLE ───
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: rootWindow.appState === "Idle"

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "◇"
                    font.pixelSize: 42
                    color: fileDropArea.containsDrag ? "#8ee8a8" : "#8a91a5"
                    scale: fileDropArea.containsDrag ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "DRAG & DROP FILE"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 15
                    font.bold: true
                    font.letterSpacing: 2
                    color: "#f1f5f9"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "or click [ ⇪ BROWSE ] below"
                    font.pixelSize: 12
                    color: "#71788e"
                }
            }

            // ─── STATE 2: UPLOADING ───
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 14
                visible: rootWindow.appState === "Uploading"

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    width: 120
                    height: 120

                    Canvas {
                        id: progressArcCanvas
                        anchors.fill: parent
                        onPaint: {
                            let ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            let cx = width / 2;
                            let cy = height / 2;
                            let radius = 48;

                            // Background ring track
                            ctx.beginPath();
                            ctx.arc(cx, cy, radius, 0, 2 * Math.PI);
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.08)";
                            ctx.lineWidth = 6;
                            ctx.lineCap = "round";
                            ctx.stroke();

                            // Progress arc
                            let start = -Math.PI / 2;
                            let progressPct = Math.max(0.0, Math.min(100.0, rootWindow.uploadProgress));
                            let sweep = (progressPct / 100.0) * (2 * Math.PI);

                            ctx.beginPath();
                            ctx.arc(cx, cy, radius, start, start + sweep);
                            ctx.strokeStyle = rootWindow.isPaused ? "#f59e0b" : "#8ee8a8";
                            ctx.lineWidth = 6;
                            ctx.lineCap = "round";
                            ctx.stroke();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: Math.round(rootWindow.uploadProgress) + "%"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 22
                        font.bold: true
                        color: "#ffffff"
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: rootWindow.currentFileName
                    font.pixelSize: 13
                    font.bold: true
                    color: "#e2e8f0"
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: 420
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: rootWindow.isPaused ? "PAUSED • " + rootWindow.uploadStatusText : rootWindow.uploadStatusText
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    color: rootWindow.isPaused ? "#f59e0b" : "#8ee8a8"
                }
            }

            // ─── STATE 3: SUCCESS ───
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: rootWindow.appState === "Success"

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 56
                    height: 56
                    radius: 28
                    color: "#163824"
                    border.color: "#4ade80"
                    border.width: 2

                    scale: rootWindow.appState === "Success" ? 1.0 : 0.4
                    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        font.pixelSize: 28
                        font.bold: true
                        color: "#4ade80"
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Upload Complete"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#4ade80"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: rootWindow.currentFileName
                    font.pixelSize: 12
                    color: "#94a3b8"
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: 420
                }
            }

            // ─── STATE 4: ERROR ───
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: rootWindow.appState === "Error"

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 56
                    height: 56
                    radius: 28
                    color: "#381616"
                    border.color: "#f87171"
                    border.width: 2

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 26
                        font.bold: true
                        color: "#f87171"
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Upload Failed"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#f87171"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: rootWindow.errorMessage
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    color: "#ef4444"
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.maximumWidth: 460
                }
            }
        }

        // Hairline separator
        Rectangle {
            anchors {
                top: dropZoneContainer.bottom
                topMargin: 12
                left: parent.left
                right: parent.right
            }
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // Bottom Control Deck (Height ~150px)
        Item {
            id: controlDeck
            anchors {
                top: dropZoneContainer.bottom
                topMargin: 20
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 14

                // ROW 1: Dropdown Selector & Browse Button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Host Dropdown Box
                    Item {
                        width: 230
                        height: 34

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: dropHover.containsMouse ? "#181b24" : "#12141a"
                            border.color: rootWindow.dropdownOpen ? "#8ee8a8" : Qt.rgba(1, 1, 1, 0.14)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                Text {
                                    text: "◆ " + rootWindow.currentHost.label
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#e2e8f0"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: rootWindow.dropdownOpen ? "▲" : "▾"
                                    font.pixelSize: 12
                                    color: "#8ee8a8"
                                }
                            }

                            MouseArea {
                                id: dropHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rootWindow.dropdownOpen = !rootWindow.dropdownOpen
                            }
                        }
                    }

                    // Browse Button (Visible in Idle)
                    Rectangle {
                        visible: rootWindow.appState === "Idle"
                        width: 110
                        height: 34
                        radius: 8
                        color: browseHover.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.16)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "⇪"
                                font.pixelSize: 14
                                color: "#8ee8a8"
                            }
                            Text {
                                text: "BROWSE"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#e2e8f0"
                            }
                        }

                        MouseArea {
                            id: browseHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rootWindow.openFilePicker()
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // ROW 2: Contextual Action Bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // ── In "Idle": Capacity hint on left
                    Item {
                        visible: rootWindow.appState === "Idle"
                        Layout.fillWidth: true
                        height: 34

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "• " + rootWindow.currentHost.desc
                            font.pixelSize: 12
                            color: "#8a91a5"
                        }
                    }

                    // ── In "Uploading": Pause & Cancel buttons
                    Item {
                        visible: rootWindow.appState === "Uploading"
                        Layout.fillWidth: true
                        height: 34

                        RowLayout {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Rectangle {
                                width: 95
                                height: 32
                                radius: 8
                                color: pauseHover.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                                border.color: Qt.rgba(1, 1, 1, 0.16)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: rootWindow.isPaused ? "▶ RESUME" : "|| PAUSE"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: rootWindow.isPaused ? "#f59e0b" : "#e2e8f0"
                                }

                                MouseArea {
                                    id: pauseHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rootWindow.togglePause()
                                }
                            }

                            Rectangle {
                                width: 95
                                height: 32
                                radius: 8
                                color: cancelHover.containsMouse ? "#3b1717" : Qt.rgba(1, 1, 1, 0.08)
                                border.color: cancelHover.containsMouse ? "#ef4444" : Qt.rgba(1, 1, 1, 0.16)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕ CANCEL"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: cancelHover.containsMouse ? "#ef4444" : "#e2e8f0"
                                }

                                MouseArea {
                                    id: cancelHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rootWindow.cancelUpload()
                                }
                            }
                        }
                    }

                    // ── In "Success": Scrollable URL input + Copy + New
                    RowLayout {
                        visible: rootWindow.appState === "Success"
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 34
                            radius: 8
                            color: "#12141a"
                            border.color: Qt.rgba(1, 1, 1, 0.14)
                            border.width: 1
                            clip: true

                            TextInput {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                text: rootWindow.finalUrl
                                readOnly: true
                                selectByMouse: true
                                font.family: "JetBrains Mono"
                                font.pixelSize: 12
                                color: "#8ee8a8"
                            }
                        }

                        Rectangle {
                            width: 100
                            height: 34
                            radius: 8
                            color: copyHover.containsMouse ? "#1c3d28" : "#14291c"
                            border.color: "#8ee8a8"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: rootWindow.isCopied ? "✓ COPIED" : "⧉ COPY"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#8ee8a8"
                            }

                            MouseArea {
                                id: copyHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rootWindow.copyToClipboard()
                            }
                        }

                        Rectangle {
                            width: 80
                            height: 34
                            radius: 8
                            color: newHover.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                            border.color: Qt.rgba(1, 1, 1, 0.16)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "+ NEW"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#e2e8f0"
                            }

                            MouseArea {
                                id: newHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    rootWindow.appState = "Idle";
                                    rootWindow.finalUrl = "";
                                    rootWindow.uploadProgress = 0.0;
                                }
                            }
                        }
                    }

                    // ── In "Error": Retry + Dismiss
                    RowLayout {
                        visible: rootWindow.appState === "Error"
                        Layout.fillWidth: true
                        spacing: 10

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 90
                            height: 34
                            radius: 8
                            color: retryHover.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                            border.color: Qt.rgba(1, 1, 1, 0.16)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "↺ RETRY"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#e2e8f0"
                            }

                            MouseArea {
                                id: retryHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rootWindow.startUpload(rootWindow.currentFilePath)
                            }
                        }

                        Rectangle {
                            width: 90
                            height: 34
                            radius: 8
                            color: dismissHover.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                            border.color: Qt.rgba(1, 1, 1, 0.16)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "✕ DISMISS"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#e2e8f0"
                            }

                            MouseArea {
                                id: dismissHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    rootWindow.appState = "Idle";
                                    rootWindow.errorMessage = "";
                                    rootWindow.uploadProgress = 0.0;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Floating Dark-Glass Dropdown Menu Card (z: 200)
        Rectangle {
            id: dropdownCard
            visible: rootWindow.dropdownOpen
            z: 200
            anchors.bottom: controlDeck.top
            anchors.bottomMargin: 8
            anchors.left: controlDeck.left
            anchors.leftMargin: 24
            width: 250
            height: 190
            radius: 10
            color: "#0f1117"
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 2

                Repeater {
                    model: rootWindow.hosts

                    Rectangle {
                        width: parent.width
                        height: 34
                        radius: 6
                        color: {
                            if (index === rootWindow.selectedHostIndex) return "#1c2230";
                            if (itemHover.containsMouse) return Qt.rgba(1, 1, 1, 0.08);
                            return "transparent";
                        }
                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            Text {
                                text: modelData.label
                                font.family: "JetBrains Mono"
                                font.pixelSize: 11
                                font.bold: index === rootWindow.selectedHostIndex
                                color: index === rootWindow.selectedHostIndex ? "#8ee8a8" : "#cbd5e1"
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: index === rootWindow.selectedHostIndex
                                text: "✓"
                                font.pixelSize: 11
                                color: "#8ee8a8"
                            }
                        }

                        MouseArea {
                            id: itemHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                rootWindow.selectedHostIndex = index;
                                rootWindow.dropdownOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
