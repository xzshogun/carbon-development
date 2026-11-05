import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * Top-Attached Notch Container matching SaneAspect / Tide Island exact geometry:
 * - Native Rectangle body with clipped top corners and smooth convex bottom corners
 * - Native PathArc ear fillets curving outward seamlessly into the screen edge
 * - No fuzzy SVG approximations, no stroke outlines
 */
Item {
    id: root

    property bool leftFillet: true
    property bool rightFillet: true
    property real filletRadius: Math.round(10 * (Theme && Theme.shellScale !== undefined ? Theme.shellScale : 1.0))
    property real bottomRadius: Math.round(14 * (Theme && Theme.shellScale !== undefined ? Theme.shellScale : 1.0))
    property real contentSpacing: Math.round(7 * (Theme && Theme.shellScale !== undefined ? Theme.shellScale : 1.0))
    property real horizontalPadding: Math.round(12 * (Theme && Theme.shellScale !== undefined ? Theme.shellScale : 1.0))
    property real earWidth: 0

    default property alias content: contentRow.data
    readonly property real contentImplicitWidth: contentRow.implicitWidth

    implicitHeight: (root.dragActive || root.isUploading)
        ? Math.round(48 * (Theme && Theme.shellScale !== undefined ? Theme.shellScale : 1.0))
        : Math.round(34 * (Theme && Theme.shellScale !== undefined ? Theme.shellScale : 1.0))
    implicitWidth: Math.max(70, contentRow.implicitWidth 
                   + (leftFillet ? filletRadius : 0) 
                   + (rightFillet ? filletRadius : 0) 
                   + (horizontalPadding * 2))
    width: implicitWidth

    Behavior on width {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    height: implicitHeight
    Behavior on height {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    property var uploadHosts: ["Buzzheavier", "x0.at", "kappa.lol"]
    property int currentHostIndex: 0

    property bool attachedBottom: false
    property bool hasAttachedPopup: false
    property real notchOpacity: 0.96

    readonly property color defaultBorderColor: "transparent"
    property color borderColor: defaultBorderColor
    property bool dragActive: false
    property bool isUploading: false

    readonly property string dropEngineBin: {
        var envPath = Quickshell.env("CARBON_DROP_ENGINE")
        if (envPath && envPath.length > 0) return envPath
        var home = Quickshell.env("HOME") || ""
        if (home.length > 0) {
            return home + "/.local/bin/carbon-drop-engine"
        }
        return "carbon-drop-engine"
    }

    // SaneAspect deep dark OLED notch surface
    readonly property color notchBgColor: Theme.isDark 
        ? Qt.rgba(0.04, 0.04, 0.06, root.notchOpacity) 
        : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.notchOpacity)

    // 1. Central Body: Clipped to hide top rounded corners, showing bottom convex corners
    Item {
        id: bodyClip
        clip: true
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: (root.leftFillet && root.filletRadius > 0) ? root.filletRadius : 0
        anchors.rightMargin: (root.rightFillet && root.filletRadius > 0) ? root.filletRadius : 0

        Rectangle {
            id: notchBackground
            anchors.left: parent.left
            anchors.leftMargin: (!root.leftFillet && root.rightFillet) ? -root.bottomRadius : 0
            anchors.right: parent.right
            anchors.rightMargin: (!root.rightFillet && root.leftFillet) ? -root.bottomRadius : 0
            y: root.attachedBottom ? 0 : -root.bottomRadius
            height: parent.height + root.bottomRadius
            radius: root.bottomRadius
            color: root.notchBgColor
            border.width: (root.dragActive || root.isUploading) ? 2 : 0
            border.color: (root.dragActive || root.isUploading) ? (root.isUploading ? "#f5b86e" : "#8ee8a8") : "transparent"

            Behavior on border.width {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }

            MouseArea {
                id: notchWheelMouseArea
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) {
                        root.currentHostIndex = (root.currentHostIndex + 1) % root.uploadHosts.length;
                    } else {
                        root.currentHostIndex = (root.currentHostIndex - 1 + root.uploadHosts.length) % root.uploadHosts.length;
                    }
                    notchText.text = "API: " + root.uploadHosts[root.currentHostIndex].toUpperCase();
                    hostTextResetTimer.restart();
                }
            }
        }
    }

    // 2. Left Ear Fillet (SaneAspect exact PathArc geometry)
    Shape {
        id: leftEar
        visible: root.leftFillet && root.filletRadius > 0
        x: 0
        y: root.attachedBottom ? (root.height - root.filletRadius) : 0
        width: root.filletRadius
        height: root.filletRadius
        preferredRendererType: Shape.GeometryRenderer
        antialiasing: true
        asynchronous: false

        ShapePath {
            fillColor: root.notchBgColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: 0
            startY: root.attachedBottom ? leftEar.height : 0
            PathLine { x: leftEar.width; y: root.attachedBottom ? leftEar.height : 0 }
            PathLine { x: leftEar.width; y: root.attachedBottom ? 0 : leftEar.height }
            PathArc {
                x: 0
                y: root.attachedBottom ? leftEar.height : 0
                radiusX: leftEar.width
                radiusY: leftEar.height
                direction: root.attachedBottom ? PathArc.Clockwise : PathArc.Counterclockwise
            }
        }
    }

    // 3. Right Ear Fillet (SaneAspect exact PathArc geometry)
    Shape {
        id: rightEar
        visible: root.rightFillet && root.filletRadius > 0
        x: root.width - root.filletRadius
        y: root.attachedBottom ? (root.height - root.filletRadius) : 0
        width: root.filletRadius
        height: root.filletRadius
        preferredRendererType: Shape.GeometryRenderer
        antialiasing: true
        asynchronous: false

        ShapePath {
            fillColor: root.notchBgColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: 0
            startY: root.attachedBottom ? 0 : rightEar.height
            PathLine { x: 0; y: root.attachedBottom ? rightEar.height : 0 }
            PathLine { x: rightEar.width; y: root.attachedBottom ? rightEar.height : 0 }
            PathArc {
                x: 0
                y: root.attachedBottom ? 0 : rightEar.height
                radiusX: rightEar.width
                radiusY: rightEar.height
                direction: root.attachedBottom ? PathArc.Clockwise : PathArc.Counterclockwise
            }
        }
    }

    property bool isPlaying: false
    property string trackTitle: ""
    property alias mouseArea: notchWheelMouseArea

    Timer {
        id: hostTextResetTimer
        interval: 1500
        onTriggered: notchText.text = "" // Revert to default text
    }

    Text {
        id: notchText
        anchors.centerIn: parent
        z: 95
        visible: text.length > 0
        text: ""
        color: (typeof Theme !== "undefined" && Theme.accentLit) ? Theme.accentLit : "#8ee8a8"
        font.family: (typeof Theme !== "undefined" && Theme.fontMono) ? Theme.fontMono : "JetBrainsMono Nerd Font"
        font.pixelSize: (typeof Theme !== "undefined" && Theme.fontPx) ? Theme.fontPx(11) : 11
        font.bold: true
    }

    Row {
        id: contentRow
        z: 1
        opacity: notchText.text.length > 0 ? 0.0 : 1.0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
        height: root.hasAttachedPopup ? root.implicitHeight : root.height
        anchors.verticalCenter: root.hasAttachedPopup ? undefined : parent.verticalCenter
        anchors.top: root.hasAttachedPopup && !root.attachedBottom ? parent.top : undefined
        anchors.bottom: root.hasAttachedPopup && root.attachedBottom ? parent.bottom : undefined
        anchors.left: (!root.rightFillet && root.leftFillet) ? undefined : ((root.leftFillet && root.rightFillet) ? undefined : parent.left)
        anchors.leftMargin: (!root.rightFillet && root.leftFillet) ? undefined : ((root.leftFillet && root.rightFillet) ? undefined : ((root.leftFillet ? root.filletRadius : 0) + root.horizontalPadding))
        anchors.right: (!root.rightFillet && root.leftFillet) ? parent.right : undefined
        anchors.rightMargin: (!root.rightFillet && root.leftFillet) ? root.horizontalPadding : undefined
        anchors.horizontalCenter: (root.leftFillet && root.rightFillet) ? parent.horizontalCenter : undefined
        spacing: root.contentSpacing
    }

    Process {
        id: uploadProcess
        running: false
        command: []
        stdout: StdioCollector {
            id: uploadStdout
            waitForEnd: true
        }
        onExited: (exitCode) => {
            let out = uploadStdout.text ? uploadStdout.text.trim() : "";
            let url = "";
            try {
                let lines = out.split("\n");
                for (let i = lines.length - 1; i >= 0; i--) {
                    let l = lines[i].trim();
                    if (!l) continue;
                    try {
                        let msg = JSON.parse(l);
                        if (msg && msg.url) { url = msg.url; break; }
                    } catch(e) {}
                    if (l.startsWith("http://") || l.startsWith("https://")) {
                        url = l;
                        break;
                    }
                }
            } catch(e) {}

            if (url && url.length > 0) {
                Quickshell.execDetached(["wl-copy", url]);
                Quickshell.execDetached(["notify-send", "-a", "Carbon Drop", "File Uploaded", "Link copied to clipboard:\n" + url]);
            }

            root.isUploading = false;
        }
    }

    DropArea {
        id: notchDropArea
        anchors.fill: parent
        z: 99

        onEntered: (drag) => {
            if (drag.hasUrls) {
                drag.accept(Qt.CopyAction);
                root.dragActive = true;
            }
        }

        onPositionChanged: (drag) => {
            if (drag.hasUrls) {
                drag.accept(Qt.CopyAction);
            }
        }

        onExited: {
            root.dragActive = false;
        }

        onDropped: (drop) => {
            root.dragActive = false;
            if (!drop.hasUrls || drop.urls.length === 0) return;
            drop.acceptProposedAction();

            let rawUrl = drop.urls[0].toString();
            let cleanPath = decodeURIComponent(rawUrl.replace(/^file:\/\//, ""));
            if (!cleanPath || cleanPath.length === 0) return;

            root.isUploading = true;

            let selectedHost = (root.uploadHosts && root.uploadHosts.length > root.currentHostIndex)
                ? root.uploadHosts[root.currentHostIndex]
                : "Buzzheavier";

            let engineCmd = [
                root.dropEngineBin || (home ? (home + "/.local/bin/carbon-drop-engine") : "carbon-drop-engine"),
                selectedHost,
                cleanPath
            ];

            uploadProcess.command = engineCmd;
            uploadProcess.running = true;
        }
    }
}
