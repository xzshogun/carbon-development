import QtQuick
import Quickshell.Widgets
import "../island"
import "../../../../Singletons"

Item {
    id: notificationCenter

    signal clearAllRequested()
    signal closeRequested()

    focus: true
    Keys.onEscapePressed: (event) => {
        closeRequested();
        event.accepted = true;
    }

    readonly property var userConfig: UserConfig
    property var notificationModel: null
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    property string heroFontFamily: userConfig.heroFontFamily

    readonly property bool hasNotifications: notificationModel && notificationModel.count > 0
    readonly property real contentHeight: {
        if (!hasNotifications)
            return 180;
        var count = notificationModel ? notificationModel.count : 0;
        if (count === 1)
            return 144;
        if (count === 2)
            return 212;
        return 280;
    }
    readonly property real verticalPadding: 14
    readonly property real horizontalPadding: 16

    NotificationHistory {
        id: notificationHistory

        anchors.fill: parent
        anchors.topMargin: notificationCenter.verticalPadding
        anchors.bottomMargin: notificationCenter.verticalPadding
        anchors.leftMargin: notificationCenter.horizontalPadding
        anchors.rightMargin: notificationCenter.horizontalPadding
        notificationModel: notificationCenter.notificationModel
        iconFontFamily: notificationCenter.iconFontFamily
        textFontFamily: notificationCenter.textFontFamily
        heroFontFamily: notificationCenter.heroFontFamily
        onClearAllRequested: notificationCenter.clearAllRequested()
        onCloseRequested: notificationCenter.closeRequested()
    }
}
