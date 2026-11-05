pragma Singleton
import QtQuick

QtObject {
    id: root
    property bool isFocusActive: false

    // Notification State
    property var notificationsList: []
    property bool doNotDisturb: false

    // Spatial Canvas / Command Center State
    property bool isCommandCenterOpen: false
}
