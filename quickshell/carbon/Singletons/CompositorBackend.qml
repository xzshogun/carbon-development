pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property string compositor: "hyprland"
    readonly property int revision: 1

    function isOutputFocused(name) {
        return true
    }

    function activeWorkspaceIndexForOutput(name) {
        return 1
    }
}
