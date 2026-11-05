import Quickshell
import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Effects
import "components" as BarComponents
import "effects"
import "config" as QsConfig
import "services" as QsServices

Item {
    id: root
    
    property var screen
    property var barWindow
    property var controlCenter
    property var launcher
    property var sidebar
    property var dashboard
    property var mixer
    
    // ═══ Inline Popup State ═══
    property string activePopup: ""  // "", "bluetooth", "network"
    readonly property bool hasPopup: activePopup !== ""
    readonly property real popupAreaHeight: hasPopup ? popupHost.height : 0
    
    function togglePopup(name: string) {
        if (activePopup === name) {
            activePopup = ""
        } else {
            activePopup = name
        }
    }
    function closePopup() {
        activePopup = ""
    }

    function popupAnchorTarget() {
        if (activePopup === "network") return networkLoader
        if (activePopup === "bluetooth") return bluetoothLoader
        if (activePopup === "battery") return batteryLoader
        return rightSection
    }
    
    readonly property var config: QsConfig.Config
    readonly property var appearance: QsConfig.AppearanceConfig
    readonly property var pywal: QsServices.Pywal
    
    // ═══════════════════════════════════════════════════════════════════════
    // CONTINUOUS PILL CAPSULE BAR (Non-stepped, unified floating bar)
    // Inspired by Carbon Pill Mode — one continuous floating pill capsule
    // ═══════════════════════════════════════════════════════════════════════
    
    Item {
        id: barContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 2
        height: config.bar.height - 4
        
        // Single unified floating pill capsule
        AuroraSurface {
            id: pillCapsule
            anchors.fill: parent
            radius: height / 2
            
            color: pywal.surfaceContainerHigh
            strokeColor: pywal.outlineVariant
            borderWidth: 1
            accentColor: pywal.primary
            elevation: 3
            
            Behavior on color {
                ColorAnimation { duration: 400; easing.type: Easing.OutCubic }
            }
            
            Item {
                id: capsuleContent
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                
                // ═══════════════════════════════════════════════════════════
                // LEFT: Workspaces & Media Player
                // ═══════════════════════════════════════════════════════════
                Row {
                    id: leftSection
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    
                    // Workspaces
                    Loader {
                        id: workspacesLoader
                        anchors.verticalCenter: parent.verticalCenter
                        asynchronous: true
                        source: "components/Workspaces.qml"
                        
                        Binding {
                            target: workspacesLoader.item
                            property: "screen"
                            value: root.screen
                            when: workspacesLoader.status === Loader.Ready && root.screen !== undefined
                            restoreMode: Binding.RestoreBinding
                        }
                    }
                    
                    // Subtle Divider
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 14
                        radius: 0.5
                        color: Qt.rgba(pywal.foreground.r, pywal.foreground.g, pywal.foreground.b, 0.12)
                    }
                    
                    // Media Player
                    Loader {
                        id: mediaPlayerLoader
                        anchors.verticalCenter: parent.verticalCenter
                        asynchronous: true
                        source: "components/MediaPlayer.qml"
                        
                        Binding {
                            target: mediaPlayerLoader.item
                            property: "barWindow"
                            value: root.barWindow
                            when: mediaPlayerLoader.status === Loader.Ready && root.barWindow !== undefined
                            restoreMode: Binding.RestoreBinding
                        }
                        
                        Binding {
                            target: mediaPlayerLoader.item
                            property: "mediaPopup"
                            value: null
                            when: mediaPlayerLoader.status === Loader.Ready
                            restoreMode: Binding.RestoreBinding
                        }
                    }
                }
                
                // ═══════════════════════════════════════════════════════════
                // CENTER: Clock (Focal Point)
                // ═══════════════════════════════════════════════════════════
                Item {
                    id: centerSection
                    anchors.centerIn: parent
                    width: clockLoader.implicitWidth
                    height: parent.height
                    
                    Loader {
                        id: clockLoader
                        anchors.centerIn: parent
                        asynchronous: true
                        source: "components/Clock.qml"

                        Binding {
                            target: clockLoader.item
                            property: "launcher"
                            value: root.launcher
                            when: clockLoader.status === Loader.Ready && root.launcher !== undefined
                            restoreMode: Binding.RestoreBinding
                        }

                        Binding {
                            target: clockLoader.item
                            property: "controlCenter"
                            value: root.controlCenter
                            when: clockLoader.status === Loader.Ready && root.controlCenter !== undefined
                            restoreMode: Binding.RestoreBinding
                        }

                        Binding {
                            target: clockLoader.item
                            property: "sidebar"
                            value: root.sidebar
                            when: clockLoader.status === Loader.Ready && root.sidebar !== undefined
                            restoreMode: Binding.RestoreBinding
                        }

                        Binding {
                            target: clockLoader.item
                            property: "dashboard"
                            value: root.dashboard
                            when: clockLoader.status === Loader.Ready && root.dashboard !== undefined
                            restoreMode: Binding.RestoreBinding
                        }
                    }
                }
                
                // ═══════════════════════════════════════════════════════════
                // RIGHT: Controls, Status & System Tray
                // ═══════════════════════════════════════════════════════════
                Row {
                    id: rightSection
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    
                    // Status Indicators (Caffeine, DND)
                    Loader {
                        id: statusIndicatorsLoader
                        anchors.verticalCenter: parent.verticalCenter
                        asynchronous: true
                        source: "components/StatusIndicators.qml"
                        visible: (item && item.hasActiveIndicators) ? true : false
                    }
                    
                    // Separator (only if status indicators visible)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 12
                        radius: 0.5
                        color: Qt.rgba(pywal.foreground.r, pywal.foreground.g, pywal.foreground.b, 0.12)
                        visible: (statusIndicatorsLoader.item && statusIndicatorsLoader.item.hasActiveIndicators) ? true : false
                    }
                    
                    // Volume
                    Loader {
                        id: volumeLoader
                        anchors.verticalCenter: parent.verticalCenter
                        asynchronous: true
                        source: "components/Volume.qml"
                        
                        Binding {
                            target: volumeLoader.item
                            property: "barWindow"
                            value: root.barWindow
                            when: volumeLoader.status === Loader.Ready && root.barWindow !== undefined
                            restoreMode: Binding.RestoreBinding
                        }

                        Binding {
                            target: volumeLoader.item
                            property: "mixer"
                            value: root.mixer
                            when: volumeLoader.status === Loader.Ready && root.mixer !== undefined
                            restoreMode: Binding.RestoreBinding
                        }
                    }
                    
                    // Battery
                    Loader {
                        id: batteryLoader
                        anchors.verticalCenter: parent.verticalCenter
                        asynchronous: true
                        source: "components/Battery.qml"
                    }

                    // Notification Center Toggle (Bell)
                    Loader {
                        id: notifCenterLoader
                        anchors.verticalCenter: parent.verticalCenter
                        asynchronous: true
                        source: "components/NotificationCenterToggle.qml"
                        
                        Binding {
                            target: notifCenterLoader.item
                            property: "sidebar"
                            value: root.sidebar
                            when: notifCenterLoader.status === Loader.Ready && root.sidebar !== undefined
                            restoreMode: Binding.RestoreBinding
                        }

                        Binding {
                            target: notifCenterLoader.item
                            property: "controlCenter"
                            value: root.controlCenter
                            when: notifCenterLoader.status === Loader.Ready && root.controlCenter !== undefined
                            restoreMode: Binding.RestoreBinding
                        }

                        Binding {
                            target: notifCenterLoader.item
                            property: "launcher"
                            value: root.launcher
                            when: notifCenterLoader.status === Loader.Ready && root.launcher !== undefined
                            restoreMode: Binding.RestoreBinding
                        }
                    }

                    // Control Center Toggle
                    Loader {
                        id: controlCenterLoader
                        anchors.verticalCenter: parent.verticalCenter
                        asynchronous: true
                        source: "components/ControlCenterToggle.qml"
                        
                        Binding {
                            target: controlCenterLoader.item
                            property: "controlCenter"
                            value: root.controlCenter
                            when: controlCenterLoader.status === Loader.Ready && root.controlCenter !== undefined
                            restoreMode: Binding.RestoreBinding
                        }
                    }
                    
                    // System Tray (only if has items)
                    Loader {
                        id: systemTrayLoader
                        anchors.verticalCenter: parent.verticalCenter
                        asynchronous: true
                        source: "components/SystemTray.qml"
                        visible: (item && item.hasItems) ? true : false
                    }
                }
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // INLINE POPUP HOST — popups expand below the bar within the same window
    // ═══════════════════════════════════════════════════════════════════════
    Item {
        id: popupHost
        anchors.top: barContainer.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        height: hasPopup ? popupContentWrapper.height + 12 : 0
        clip: true

        // Match Control Center behavior: close after leaving popup focus area
        property bool mouseHasEntered: false
        property bool mouseInside: popupHoverHandler.hovered

        onVisibleChanged: {
            if (!visible) {
                mouseHasEntered = false
                popupCloseTimer.stop()
            }
        }

        Connections {
            target: root
            function onHasPopupChanged() {
                if (root.hasPopup) {
                    popupHost.mouseHasEntered = false
                    popupCloseTimer.stop()
                } else {
                    popupCloseTimer.stop()
                }
            }
        }

        Timer {
            id: popupCloseTimer
            interval: 400
            onTriggered: {
                if (!popupHost.mouseInside && popupHost.mouseHasEntered && root.hasPopup) {
                    root.closePopup()
                }
            }
        }
        
        Behavior on height {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }
        }
        
        // Click-outside scrim to dismiss popup
        MouseArea {
            anchors.fill: parent
            visible: hasPopup
            onClicked: root.closePopup()
        }
        
        // Popup content container — positioned below the triggering icon
        Item {
            id: popupContentWrapper
            y: 4
            x: {
                const w = width
                const hostPadding = 12
                const anchor = root.popupAnchorTarget()

                if (anchor) {
                    const centerInHost = anchor.mapToItem(popupHost, anchor.width / 2, anchor.height).x
                    return Math.max(hostPadding, Math.min(popupHost.width - w - hostPadding, centerInHost - (w / 2)))
                }

                return Math.max(hostPadding, popupHost.width - w - hostPadding)
            }
            width: activePopup === "network" ? 340 : 320
            height: {
                if (btPanelLoader.active && btPanelLoader.item)
                    return btPanelLoader.item.implicitHeight
                if (netPanelLoader.active && netPanelLoader.item)
                    return netPanelLoader.item.implicitHeight
                return 0
            }
            
            // Entry animation
            scale: hasPopup ? 1.0 : 0.92
            opacity: hasPopup ? 1 : 0
            transformOrigin: Item.TopRight
            
            Behavior on scale {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.1
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: popupHoverHandler
                onHoveredChanged: {
                    if (hovered) {
                        popupHost.mouseHasEntered = true
                        popupCloseTimer.stop()
                    } else if (popupHost.mouseHasEntered && root.hasPopup) {
                        popupCloseTimer.restart()
                    }
                }
            }
            
            // Bluetooth Panel
            Loader {
                id: btPanelLoader
                anchors.fill: parent
                active: root.activePopup === "bluetooth"
                source: "components/BluetoothPanel.qml"
                
                onLoaded: {
                    item.shouldShow = true
                    item.forceActiveFocus()
                }
                
                Connections {
                    target: btPanelLoader.item
                    function onCloseRequested() { root.closePopup() }
                }
            }
            
            // Network Panel
            Loader {
                id: netPanelLoader
                anchors.fill: parent
                active: root.activePopup === "network"
                source: "components/NetworkPanel.qml"
                
                onLoaded: {
                    item.shouldShow = true
                    item.forceActiveFocus()
                }
                
                Connections {
                    target: netPanelLoader.item
                    function onCloseRequested() { root.closePopup() }
                }
            }
        }
    }
}
