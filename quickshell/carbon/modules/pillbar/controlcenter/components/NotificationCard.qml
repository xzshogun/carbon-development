import QtQuick 6.10
import QtQuick.Layouts
import "../../services" as QsServices
import "../../config" as QsConfig

Item {
    id: root

    required property var notification

    // Feature flags
    property bool showCloseButton: true
    property bool showTimestamp: false
    property bool showUnreadDot: false
    property bool showActions: true
    property bool showBody: true
    property bool showAppIcon: true

    // Color tokens (overridable by consumer)
    property var pywal: null
    property color primaryColor: (pywal && pywal.primary) ? pywal.primary : "#88cc88"
    property color onSurfaceColor: (pywal && pywal.foreground) ? pywal.foreground : "#dddddd"
    property color onSurfaceVariantColor: (pywal && pywal.onSurfaceMuted) ? pywal.onSurfaceMuted : "#999999"
    property color errorColor: (pywal && pywal.error) ? pywal.error : "#ff4444"
    property color surfaceContainerHighColor: (pywal && pywal.surfaceContainerHigh) ? pywal.surfaceContainerHigh : "#1a1a1a"

    function urgencyColor(urgency) {
        if (urgency === 2) return errorColor
        if (urgency === 0) return Qt.rgba(onSurfaceColor.r, onSurfaceColor.g, onSurfaceColor.b, 0.5)
        return primaryColor
    }

    function iconSource(icon) {
        if (!icon) return ""
        if (icon.startsWith("/") || icon.startsWith("file://")) return icon
        return "image://icon/" + icon
    }

    implicitHeight: contentLayout.implicitHeight

    ColumnLayout {
        id: contentLayout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        // --- Header Row: icon + summary + timestamp + close ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // App icon
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignTop
                radius: 12
                visible: root.showAppIcon
                color: Qt.rgba(root.urgencyColor(root.notification && root.notification.urgency !== undefined ? root.notification.urgency : 1).r,
                               root.urgencyColor(root.notification && root.notification.urgency !== undefined ? root.notification.urgency : 1).g,
                               root.urgencyColor(root.notification && root.notification.urgency !== undefined ? root.notification.urgency : 1).b, 0.12)

                Image {
                    anchors.centerIn: parent
                    width: 20; height: 20
                    visible: Boolean(root.notification && root.notification.appIcon && root.notification.appIcon.length > 0)
                    source: root.iconSource(root.notification && root.notification.appIcon ? root.notification.appIcon : "")
                    fillMode: Image.PreserveAspectFit
                    smooth: true; cache: true; asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.notification || !root.notification.appIcon || root.notification.appIcon.length === 0
                    text: "󰂚"
                    font.family: "Material Design Icons"
                    font.pixelSize: 18
                    color: root.urgencyColor(root.notification && root.notification.urgency !== undefined ? root.notification.urgency : 1)
                    opacity: 0.8
                }
            }

            // Summary + app name
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: (root.notification && root.notification.summary) ? root.notification.summary : "Notification"
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: root.onSurfaceColor
                    elide: Text.ElideRight
                    font.letterSpacing: -0.15
                }

                Text {
                    Layout.fillWidth: true
                    text: (root.notification && root.notification.appName) ? root.notification.appName : ""
                    font.family: "Inter"
                    font.pixelSize: 11
                    color: root.onSurfaceVariantColor
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            // Unread dot
            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                Layout.alignment: Qt.AlignTop
                radius: 4
                visible: root.showUnreadDot && Boolean(root.notification && !root.notification.read)
                color: root.primaryColor
                Layout.topMargin: 4
            }

            // Timestamp
            Text {
                visible: root.showTimestamp
                text: (root.notification && root.notification.timeString) ? root.notification.timeString : ""
                font.family: "Inter"
                font.pixelSize: 10
                color: root.onSurfaceVariantColor
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 2
            }

            // Close button
            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignTop
                radius: 13
                visible: root.showCloseButton
                color: closeMouse.containsMouse
                    ? Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.12)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: "Material Design Icons"
                    font.pixelSize: 13
                    color: closeMouse.containsMouse ? root.errorColor : Qt.rgba(root.onSurfaceColor.r, root.onSurfaceColor.g, root.onSurfaceColor.b, 0.45)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.notification && root.notification.close)
                            root.notification.close()
                    }
                }
            }
        }

        // --- Body text ---
        Text {
            Layout.fillWidth: true
            text: (root.notification && root.notification.body) ? root.notification.body : ""
            font.family: "Inter"
            font.pixelSize: 12
            color: root.onSurfaceVariantColor
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            lineHeight: 1.4
            visible: root.showBody && text.length > 0
        }

        // --- Image preview ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            radius: 10
            clip: true
            visible: Boolean(root.notification && root.notification.image && root.notification.image.length > 0)
            color: root.surfaceContainerHighColor

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: root.iconSource(root.notification && root.notification.image ? root.notification.image : "")
                fillMode: Image.PreserveAspectCrop
                smooth: true; cache: true; asynchronous: true
            }
        }

        // --- Action buttons ---
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: root.showActions && Boolean(root.notification && root.notification.actions && root.notification.actions.length > 0)

            Repeater {
                model: (root.notification && root.notification.actions) ? root.notification.actions : []

                Rectangle {
                    required property var modelData
                    width: actionLabel.implicitWidth + 22
                    height: 28
                    radius: 14
                    color: actionMouse.containsMouse
                        ? Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.18)
                        : Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.10)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    scale: actionMouse.pressed ? 0.94 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: (modelData && modelData.text) ? modelData.text : ((modelData && modelData.identifier) ? modelData.identifier : "")
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.family: "Inter"
                        font.letterSpacing: 0.3
                        color: root.primaryColor
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData && modelData.invoke)
                                modelData.invoke()
                            if (root.notification && root.notification.close)
                                root.notification.close()
                        }
                    }
                }
            }
        }
    }
}
