import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import "../controlcenter"
import "../../../../Singletons"

Item {
    id: root

    readonly property var userConfig: UserConfig

    signal closeRequested()
    signal clearAllRequested()

    focus: true
    Keys.onEscapePressed: (event) => {
        closeRequested();
        event.accepted = true;
    }

    property var notificationModel: null
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    property string heroFontFamily: userConfig.heroFontFamily

    readonly property real headerHeight: 32
    readonly property real listTopGap: 10
    readonly property real cardHeight: 60
    readonly property real cardRadius: 14
    readonly property real cardGap: 8
    readonly property int itemCount: notificationModel ? notificationModel.count : 0
    readonly property bool hasNotifications: itemCount > 0

    function getAppIcon(appName, summary) {
        var s = ((appName || "") + " " + (summary || "")).toLowerCase();
        if (s.indexOf("shot") !== -1 || s.indexOf("screen") !== -1 || s.indexOf("grim") !== -1 || s.indexOf("slurp") !== -1)
            return "󰄀";
        if (s.indexOf("term") !== -1 || s.indexOf("bash") !== -1 || s.indexOf("zsh") !== -1 || s.indexOf("kitty") !== -1 || s.indexOf("foot") !== -1 || s.indexOf("alacritty") !== -1 || s.indexOf("ghostty") !== -1)
            return "󰆍";
        if (s.indexOf("firefox") !== -1 || s.indexOf("chrome") !== -1 || s.indexOf("brave") !== -1 || s.indexOf("zen") !== -1 || s.indexOf("browser") !== -1 || s.indexOf("web") !== -1)
            return "󰈹";
        if (s.indexOf("discord") !== -1 || s.indexOf("vesktop") !== -1)
            return "󰙯";
        if (s.indexOf("spotify") !== -1 || s.indexOf("music") !== -1 || s.indexOf("media") !== -1 || s.indexOf("player") !== -1)
            return "󰝚";
        if (s.indexOf("telegram") !== -1)
            return "󰏲";
        if (s.indexOf("slack") !== -1)
            return "󰒱";
        if (s.indexOf("code") !== -1 || s.indexOf("cursor") !== -1 || s.indexOf("antigravity") !== -1 || s.indexOf("nvim") !== -1)
            return "󰘳";
        if (s.indexOf("volume") !== -1 || s.indexOf("audio") !== -1 || s.indexOf("pipewire") !== -1 || s.indexOf("wireplumber") !== -1)
            return "󰕾";
        if (s.indexOf("brightness") !== -1 || s.indexOf("light") !== -1)
            return "󰃠";
        if (s.indexOf("battery") !== -1 || s.indexOf("power") !== -1)
            return "󰁹";
        if (s.indexOf("bluetooth") !== -1)
            return "󰂯";
        if (s.indexOf("wifi") !== -1 || s.indexOf("network") !== -1)
            return "󰖩";
        if (s.indexOf("update") !== -1 || s.indexOf("pacman") !== -1 || s.indexOf("yay") !== -1 || s.indexOf("dnf") !== -1 || s.indexOf("apt") !== -1)
            return "󰏓";
        if (s.indexOf("mail") !== -1 || s.indexOf("email") !== -1 || s.indexOf("thunderbird") !== -1)
            return "󰇮";
        if (s.indexOf("dnd") !== -1 || s.indexOf("focus") !== -1 || s.indexOf("disturb") !== -1)
            return "󰂛";
        return "󰂚";
    }

    function formatTime(ts) {
        if (!ts) return "";
        var d = (ts instanceof Date) ? ts : new Date(ts);
        if (isNaN(d.getTime())) return "";
        var now = new Date();
        var diffSec = Math.floor((now.getTime() - d.getTime()) / 1000);
        if (diffSec < 60) return "Just now";
        if (diffSec < 3600) return Math.floor(diffSec / 60) + "m ago";
        var hours = d.getHours();
        var minutes = d.getMinutes();
        var ampm = hours >= 12 ? "pm" : "am";
        hours = hours % 12;
        hours = hours ? hours : 12;
        var strMinutes = minutes < 10 ? "0" + minutes : minutes;
        return hours + ":" + strMinutes + " " + ampm;
    }

    // --- Header ---
    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.headerHeight

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Bell icon container
            Rectangle {
                width: 28
                height: 28
                radius: 14
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.isDark ? "#282d37" : "#e0e4ee"
                border.width: 1
                border.color: Theme.isDark ? "#353c4b" : "#d0d6e2"

                Text {
                    anchors.centerIn: parent
                    text: "󰂚"
                    font.family: root.iconFontFamily
                    font.pixelSize: 13
                    color: Theme.accent
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                textFormat: Text.PlainText
                color: Theme.fg
                font.pixelSize: 13
                font.family: root.textFontFamily
                font.weight: Font.Bold
                font.letterSpacing: 0.1
            }

            // Notification count badge
            Rectangle {
                visible: root.hasNotifications
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                width: Math.max(18, countText.contentWidth + 10)
                radius: 9
                color: Theme.accent

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: String(root.itemCount)
                    font.pixelSize: 10
                    font.family: root.textFontFamily
                    font.weight: Font.Bold
                    color: Theme.isDark ? "#111418" : "#ffffff"
                }
            }
        }

        // "Clear all" button on the right
        Rectangle {
            id: clearAllBtn

            visible: root.hasNotifications
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 26
            width: clearAllRow.width + 16
            radius: 13
            color: clearMouse.containsMouse
                ? (Theme.isDark ? "#383f4e" : "#ccd2df")
                : (Theme.isDark ? "#22262e" : "#dde2ed")
            border.width: 1
            border.color: Theme.isDark ? "#2f3542" : "#cfd5e2"
            scale: clearMouse.pressed ? 0.94 : 1.0

            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Row {
                id: clearAllRow
                anchors.centerIn: parent
                spacing: 5

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰆴"
                    font.family: root.iconFontFamily
                    font.pixelSize: 11
                    color: clearMouse.containsMouse ? Theme.fg : Theme.fgDim
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clear all"
                    font.family: root.textFontFamily
                    font.pixelSize: 11
                    font.weight: Font.SemiBold
                    color: clearMouse.containsMouse ? Theme.fg : Theme.fgDim
                }
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearAllRequested()
            }
        }
    }

    // --- Empty State ---
    Item {
        id: emptyState

        anchors.top: header.bottom
        anchors.topMargin: root.listTopGap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !root.hasNotifications

        Column {
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                width: 48
                height: 48
                radius: 24
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.isDark ? "#20252f" : "#e8ecf4"
                border.width: 1
                border.color: Theme.isDark ? "#2c3240" : "#d8dde8"

                Text {
                    anchors.centerIn: parent
                    text: "󰂚"
                    font.family: root.iconFontFamily
                    font.pixelSize: 22
                    color: Theme.accent
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No notifications"
                font.pixelSize: 13
                font.family: root.textFontFamily
                font.weight: Font.SemiBold
                color: Theme.fg
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "You're all caught up!"
                font.pixelSize: 11
                font.family: root.textFontFamily
                font.weight: Font.Normal
                color: Theme.fgDim
            }
        }
    }

    // --- Notification Cards List ---
    Item {
        id: listViewport

        anchors.top: header.bottom
        anchors.topMargin: root.listTopGap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.hasNotifications
        clip: true

        ListView {
            id: listView

            anchors.fill: parent
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: root.notificationModel
            currentIndex: -1
            spacing: root.cardGap

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: 160
                        easing.type: Easing.InOutCubic
                    }
                    NumberAnimation {
                        property: "scale"
                        to: 0.92
                        duration: 160
                        easing.type: Easing.InOutCubic
                    }
                }
            }

            removeDisplaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            ScrollBar.vertical: ScrollBar {
                active: listView.moving || listView.dragging
                policy: ScrollBar.AsNeeded
                width: 3

                contentItem: Rectangle {
                    radius: 1.5
                    color: Theme.isDark ? "#484f5e" : "#b0b6c4"
                }

                background: Rectangle {
                    color: StyleTokens.transparent
                }
            }

            delegate: Item {
                id: delegateItem

                width: listView.width
                height: root.cardHeight

                readonly property string titleText: (model.summary && model.summary !== "")
                    ? model.summary
                    : "Notification"
                readonly property string bodyText: (model.body && model.body !== model.summary)
                    ? model.body
                    : ""
                readonly property string appTitle: (model.appName && model.appName !== "")
                    ? model.appName
                    : "Notification"
                readonly property string timeString: root.formatTime(model.timestamp)

                // Background Card
                Rectangle {
                    anchors.fill: parent
                    radius: root.cardRadius
                    color: cardMouse.containsMouse
                        ? (Theme.isDark ? "#242934" : "#e4e8f1")
                        : (Theme.isDark ? "#1c2027" : "#eef2f8")
                    border.width: 1
                    border.color: cardMouse.containsMouse
                        ? (Theme.isDark ? "#353c4b" : "#cbd1de")
                        : (Theme.isDark ? "#282d37" : "#d8dce6")

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                // App Icon Box
                Rectangle {
                    id: appIconBox

                    x: 10
                    y: 12
                    width: 36
                    height: 36
                    radius: 10
                    color: Theme.isDark ? "#282d37" : "#dde2ed"
                    border.width: 1
                    border.color: Theme.isDark ? "#353c4b" : "#cfd5e2"

                    Text {
                        anchors.centerIn: parent
                        text: root.getAppIcon(model.appName, model.summary)
                        font.family: root.iconFontFamily
                        font.pixelSize: 16
                        color: Theme.accent
                    }
                }

                // Content Column
                Column {
                    anchors.left: appIconBox.right
                    anchors.leftMargin: 10
                    anchors.right: dismissBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    // Row 1: App Name & Time
                    Row {
                        spacing: 5
                        width: parent.width

                        Text {
                            text: delegateItem.appTitle
                            font.pixelSize: 10
                            font.weight: Font.SemiBold
                            font.family: root.textFontFamily
                            color: Theme.accent
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            visible: delegateItem.timeString !== ""
                            text: "•"
                            font.pixelSize: 10
                            color: Theme.fgDim
                        }

                        Text {
                            visible: delegateItem.timeString !== ""
                            text: delegateItem.timeString
                            font.pixelSize: 10
                            font.family: root.textFontFamily
                            font.weight: Font.Normal
                            color: Theme.fgDim
                        }
                    }

                    // Row 2: Title / Summary
                    Text {
                        width: parent.width
                        text: delegateItem.titleText
                        textFormat: Text.PlainText
                        color: Theme.fg
                        font.pixelSize: 12
                        font.family: root.textFontFamily
                        font.weight: Font.SemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    // Row 3: Body (if non-empty)
                    Text {
                        visible: delegateItem.bodyText !== ""
                        width: parent.width
                        text: delegateItem.bodyText
                        textFormat: Text.PlainText
                        color: Theme.fgDim
                        font.pixelSize: 11
                        font.family: root.textFontFamily
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                // Dismiss Button "✕" on the right
                Rectangle {
                    id: dismissBtn

                    z: 2
                    width: 24
                    height: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 12
                    color: dismissMouse.containsMouse
                        ? (Theme.isDark ? "#383f4e" : "#ccd2df")
                        : "transparent"
                    scale: dismissMouse.pressed ? 0.90 : 1.0

                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: root.textFontFamily
                        color: dismissMouse.containsMouse ? Theme.fg : Theme.fgDim
                    }

                    MouseArea {
                        id: dismissMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.notificationModel && index >= 0 && index < root.notificationModel.count)
                                root.notificationModel.remove(index);
                        }
                    }
                }

                // Card Clickable Area (to dismiss or activate)
                MouseArea {
                    id: cardMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: 1
                    onClicked: {
                        if (root.notificationModel && index >= 0 && index < root.notificationModel.count)
                            root.notificationModel.remove(index);
                    }
                }
            }
        }
    }
}
