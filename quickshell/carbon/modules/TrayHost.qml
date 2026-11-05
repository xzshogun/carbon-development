import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import "../components"
import "../Singletons"

/**
 * StatusNotifier tray icons, stacked vertically. Left click activates; right
 * click shows the item's native menu via display() anchored to the bar.
 */
Item {
    id: root

    readonly property var trayItems: SystemTray.items.values.filter(function (it) {
        var key = ((it.id || "") + " " + (it.title || "") + " " + (it.tooltipTitle || "")).toLowerCase();
        return !/(nm[ _-]?applet|blueman)/.test(key);
    })

    property var anchorWindow: null

    implicitWidth: 28
    implicitHeight: trayItems.length * 26 + (trayItems.length ? 6 : 0)
    visible: trayItems.length > 0
    property int hoverIndex: -1

    function showMenu(item, slot) {
        if (!item.hasMenu) return;
        var p = slot.mapToItem(null, slot.width / 2, slot.height);
        item.display(root.anchorWindow, p.x, p.y);
    }

    Column {
        anchors.fill: parent
        spacing: 6

        Repeater {
            model: root.trayItems

            delegate: Item {
                id: slot
                required property var modelData
                required property int index

                implicitWidth: 28
                implicitHeight: 20

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: root.hoverIndex === index ? Theme.bgHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                Image {
                    id: ticon
                    anchors.centerIn: parent
                    source: slot.modelData.icon
                    sourceSize: Qt.size(32, 32)
                    width: 16
                    height: 16
                    fillMode: Image.PreserveAspectFit
                }

                MultiEffect {
                    anchors.fill: ticon
                    source: ticon
                    colorization: 1.0
                    colorizationColor: Theme.fg
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverIndex = index
                    onExited: root.hoverIndex = -1
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton)
                            slot.modelData.activate();
                        else if (mouse.button === Qt.RightButton)
                            root.showMenu(slot.modelData, slot);
                    }
                }
            }
        }
    }
}