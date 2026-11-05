pragma Singleton
import QtQuick
import Quickshell

/**
 * ShellConfig.qml
 * Global configuration proxy for Carbon Shell.
 */
Singleton {
    id: root
    readonly property bool cairoModeEnabled: LockState.cairoModeEnabled
    readonly property bool verciModeEnabled: LockState.verciModeEnabled
}
