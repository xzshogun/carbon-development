pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Carbon motion tokens: durations and easing curves shared by the bar modules.
 * Dynamically reacts to ~/.config/hypr/carbon-motion.json (reduceMotion, durations, bounce).
 */
Singleton {
    id: root

    property bool reduceMotion: false
    property int movementDuration: 400
    property int fadeDuration: 200
    property int hoverResponse: 150
    property int bounce: 40

    readonly property int fast: root.reduceMotion ? 0 : Math.max(20, Math.round(root.fadeDuration * 0.6))
    readonly property int normal: root.reduceMotion ? 0 : Math.max(40, root.fadeDuration)
    readonly property int slow: root.reduceMotion ? 0 : Math.max(60, root.movementDuration)

    readonly property var easeStandard: Easing.OutCubic
    readonly property var easeOut: Easing.OutQuart

    FileView {
        id: motionFile
        path: (Quickshell.env("HOME") || "") + "/.config/hypr/carbon-motion.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.reload()
        onFileChanged: root.reload()
    }

    function reload() {
        try {
            var txt = motionFile.text().trim()
            if (txt.length > 0) {
                var d = JSON.parse(txt)
                if (d.reduceMotion !== undefined) root.reduceMotion = !!d.reduceMotion
                if (d.movementDuration !== undefined) root.movementDuration = parseInt(d.movementDuration) || 400
                if (d.fadeDuration !== undefined) root.fadeDuration = parseInt(d.fadeDuration) || 200
                if (d.hoverResponse !== undefined) root.hoverResponse = parseInt(d.hoverResponse) || 150
                if (d.bounce !== undefined) root.bounce = parseInt(d.bounce) || 40
            }
        } catch (e) {}
    }
}