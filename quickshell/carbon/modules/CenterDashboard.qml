import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "../Singletons"
import "../components"

/**
 * CenterDashboard:
 * Multi-page tactical deck for Carbon Center Notch.
 * Pages:
 *   -1 : Quick Settings Bento (Volume & Brightness sliders, Wi-Fi, BT, DND, Night Light toggles)
 *    0 : Default Tactical Media & Chronometer
 *    1 : Pomodoro Focus & Weather
 */
Item {
    id: root

    property bool open: false
    property bool minimalCalendarOnly: false
    property bool attachedBottom: false
    property bool showBackground: true
    readonly property bool hovered: (rootHover && rootHover.hovered) || (mainCardHover && mainCardHover.hovered)
    signal closeRequested()

    // ── Multi-Page State (-1, 0, 1) ──────────────────────────────────────────
    property int notchPage: 0
    function previousPage() {
        if (root.notchPage > -1) root.notchPage--
    }
    function nextPage() {
        if (root.notchPage < 1) root.notchPage++
    }

    implicitWidth: Theme.px(820)
    implicitHeight: Theme.px(270)
    width: implicitWidth
    height: implicitHeight
    clip: false
    property real earRadius: Theme.px(16)
    property real bottomRadius: Theme.px(20)

    focus: root.open
    Keys.enabled: root.open
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            root.previousPage()
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            root.nextPage()
            event.accepted = true
        }
    }
    Keys.onEscapePressed: (event) => {
        root.closeRequested()
        event.accepted = true
    }

    HoverHandler {
        id: rootHover
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            var dx = event.angleDelta.x
            var dy = event.angleDelta.y
            if (Math.abs(dx) > 15 || ((event.modifiers & Qt.ShiftModifier) && Math.abs(dy) > 15)) {
                var delta = Math.abs(dx) > 15 ? dx : dy
                if (delta > 0) root.previousPage()
                else root.nextPage()
            }
        }
    }

    readonly property var cardItem: mainCard
    property bool animatingOut: false

    onOpenChanged: {
        if (root.open) {
            if (LyricsService.hasTrack && (!LyricsService.lines || LyricsService.lines.length === 0)) {
                LyricsService.reloadLyrics()
            }
            if (root.notchPage === -1) {
                wifiPoller.running = true
                ssidPoller.running = true
                btPoller.running = true
            } else if (root.notchPage === 1) {
                weatherPoller.running = true
            }
        }
    }

    onNotchPageChanged: {
        if (root.notchPage === -1) {
            wifiPoller.running = true
            ssidPoller.running = true
            btPoller.running = true
        } else if (root.notchPage === 1) {
            weatherPoller.running = true
        }
    }

    /* ── Format Time Helper (MM:SS or HH:MM:SS) ───────────────────────────── */
    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec < 0) return "00:00"
        let s = Math.floor(sec)
        let hrs = Math.floor(s / 3600)
        let mins = Math.floor((s % 3600) / 60)
        let secs = s % 60
        let mStr = (mins < 10 ? "0" : "") + mins
        let sStr = (secs < 10 ? "0" : "") + secs
        if (hrs > 0) {
            let hStr = (hrs < 10 ? "0" : "") + hrs
            return hStr + ":" + mStr + ":" + sStr
        }
        return mStr + ":" + sStr
    }

    /* ── Backend Pollers for Quick Settings ───────────────────────────────── */
    Process {
        id: wifiPoller
        command: ["sh", "-c", "nmcli radio wifi | tr -d ' \n\r'"]
        running: root.open && root.notchPage === -1
        stdout: StdioCollector {
            onTextChanged: {
                if (text) tileWifi.wifiOn = (text.trim() === "enabled")
            }
        }
    }

    Process {
        id: ssidPoller
        command: ["sh", "-c", "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2-"]
        running: root.open && root.notchPage === -1
        stdout: StdioCollector {
            onTextChanged: {
                if (text && text.trim().length > 0) tileWifi.ssid = text.trim()
            }
        }
    }

    Process {
        id: btPoller
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep 'Powered:' | awk '{print $2}'"]
        running: root.open && root.notchPage === -1
        stdout: StdioCollector {
            onTextChanged: {
                if (text) tileBt.btOn = (text.trim() === "yes")
            }
        }
    }

    Timer {
        interval: 4000
        repeat: true
        running: root.open && root.notchPage === -1
        onTriggered: {
            wifiPoller.running = true
            ssidPoller.running = true
            btPoller.running = true
        }
    }

    /* ── Backend Poller for Weather ───────────────────────────────────────── */
    readonly property string weatherScriptPath: (Quickshell.env("HOME") || "") + "/.local/share/quickshell/carbon/scripts/carbon-weather.py"
    Process {
        id: weatherPoller
        command: ["python3", root.weatherScriptPath, "status"]
        running: root.open && root.notchPage === 1
        stdout: StdioCollector {
            waitForEnd: true
            onTextChanged: {
                if (text && text.trim().length > 0) {
                    try {
                        var d = JSON.parse(text.trim())
                        if (d) {
                            weatherCard.cityName = d.city_name || "Patna, IN"
                            weatherCard.temp = d.temp || "--"
                            weatherCard.feelsLike = d.feels_like || "--"
                            weatherCard.desc = d.description || ""
                            weatherCard.icon = d.icon || "󰖐"
                            weatherCard.humidity = d.humidity || "--"
                            weatherCard.wind = d.wind || "--"
                            weatherCard.forecast = (d.forecast && Array.isArray(d.forecast)) ? d.forecast : []
                        }
                    } catch (e) {}
                }
            }
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.open && root.notchPage === 1
        onTriggered: {
            weatherPoller.running = false
            weatherPoller.running = true
        }
    }

    /* ── Main Card ───────────────────────────────────────────────────────── */
    Item {
        id: mainCard
        anchors.fill: parent

        HoverHandler {
            id: mainCardHover
        }

        MouseArea {
            anchors.fill: parent
            z: 0
        }

        // Top-attached seamless background with flat top edge and curved bottom corners
        Shape {
            id: cardBgShape
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            preferredRendererType: Shape.CurveRenderer
            visible: root.showBackground

            ShapePath {
                fillColor: Theme.isDark ? Qt.rgba(0.04, 0.04, 0.06, root.showBackground ? Theme.shellOpacity : 0.98) : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.showBackground ? Theme.shellOpacity : 0.98)
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0; startY: 0
                PathLine { x: mainCard.width; y: 0 }
                PathLine { x: mainCard.width; y: mainCard.height - root.bottomRadius }
                PathArc { x: mainCard.width - root.bottomRadius; y: mainCard.height; radiusX: root.bottomRadius; radiusY: root.bottomRadius }
                PathLine { x: root.bottomRadius; y: mainCard.height }
                PathArc { x: 0; y: mainCard.height - root.bottomRadius; radiusX: root.bottomRadius; radiusY: root.bottomRadius }
                PathLine { x: 0; y: 0 }
            }
        }

        /* ── Deck Pages Container ────────────────────────────────────────── */
        Item {
            id: pagesContainer
            anchors.fill: parent
            anchors.margins: Theme.px(14)
            clip: true
            z: 1

            /* ============================================================= */
            /* PAGE -1: QUICK SETTINGS BENTO & SLIDERS                       */
            /* ============================================================= */
            Item {
                id: pageControls
                anchors.fill: parent
                visible: opacity > 0.01
                opacity: root.notchPage === -1 ? 1.0 : 0.0
                transform: Translate {
                    x: (-1 - root.notchPage) * Theme.px(80)
                    Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutExpo } }
                }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.px(14)

                    // ── Left Column: Audio & Display Studio Capsules ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: Theme.px(380)
                        Layout.fillHeight: true
                        spacing: Theme.px(10)

                        // A. Volume Studio Capsule Slider
                        Rectangle {
                            id: volSlider
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.px(16)
                            color: volCardMouse.containsMouse
                                ? Qt.rgba(0.045, 0.05, 0.06, 0.85)
                                : Qt.rgba(0.025, 0.03, 0.035, 0.75)
                            border.width: 1
                            border.color: (volTrackMouse.pressed || volCardMouse.containsMouse)
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                                : Qt.rgba(1, 1, 1, 0.07)
                            clip: true
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Behavior on border.color { ColorAnimation { duration: 160 } }

                            readonly property var sink: Pipewire.defaultAudioSink
                            readonly property real rawVol: (sink && sink.audio && sink.audio.volume !== undefined)
                                ? sink.audio.volume : (SysBackend ? SysBackend.currentVolume : 0.5)
                            readonly property bool isMuted: (sink && sink.audio && sink.audio.muted !== undefined)
                                ? sink.audio.muted : (SysBackend ? SysBackend.isMuted : false)
                            readonly property real clampedVol: Math.max(0.0, Math.min(1.0, rawVol))

                            // Top edge subtle glass highlight
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Qt.rgba(255, 255, 255, 0.08)
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.px(12)
                                spacing: Theme.px(8)

                                // 1. Header Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(10)

                                    // Tactile Mute / Speaker Icon Button
                                    Rectangle {
                                        id: volMuteBtn
                                        width: Theme.px(32)
                                        height: Theme.px(32)
                                        radius: Theme.px(10)
                                        color: volSlider.isMuted
                                            ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, volMuteMouse.containsMouse ? 0.30 : 0.16)
                                            : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, volMuteMouse.containsMouse ? 0.28 : 0.14)
                                        border.width: 1
                                        border.color: volSlider.isMuted
                                            ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.40)
                                            : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                                        scale: volMuteMouse.pressed ? 0.90 : (volMuteMouse.containsMouse ? 1.05 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 120 } }
                                        Behavior on color { ColorAnimation { duration: 140 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: volSlider.isMuted ? "󰝟" : (volSlider.clampedVol < 0.33 ? "󰕿" : (volSlider.clampedVol < 0.66 ? "󰖀" : "󰕾"))
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                            color: volSlider.isMuted ? Theme.err : Theme.primary
                                        }

                                        MouseArea {
                                            id: volMuteMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                                    Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                                                } else {
                                                    Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                                                }
                                            }
                                        }
                                    }

                                    // Labels
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: "MASTER AUDIO"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontPx(10.5)
                                            font.bold: true
                                            color: Theme.fg
                                        }

                                        Text {
                                            text: volSlider.isMuted ? "Audio muted" : (volSlider.sink && volSlider.sink.description ? volSlider.sink.description : "Default PipeWire Sink")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontPx(9)
                                            color: Theme.fgDim
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // Right Percentage Badge
                                    Rectangle {
                                        width: Theme.px(54)
                                        height: Theme.px(22)
                                        radius: Theme.px(11)
                                        color: volSlider.isMuted
                                            ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.18)
                                            : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                                        border.width: 1
                                        border.color: volSlider.isMuted
                                            ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.45)
                                            : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)

                                        Text {
                                            anchors.centerIn: parent
                                            text: volSlider.isMuted ? "MUTED" : Math.round(volSlider.clampedVol * 100) + "%"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontPx(10)
                                            font.bold: true
                                            color: volSlider.isMuted ? Theme.err : Theme.primary
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                // 2. Track Row (Dedicated tactile groove with glowing knob)
                                Item {
                                    id: volTrackArea
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Theme.px(26)

                                    // Groove Channel
                                    Rectangle {
                                        id: volGroove
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: Theme.px(10)
                                        radius: Theme.px(5)
                                        color: Qt.rgba(0, 0, 0, 0.65)
                                        border.width: 1
                                        border.color: Qt.rgba(255, 255, 255, 0.06)
                                        clip: true

                                        // Active Gradient Fill
                                        Rectangle {
                                            id: volFill
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: volSlider.isMuted ? 0 : Math.max(0, Math.min(parent.width, parent.width * volSlider.clampedVol))
                                            radius: Theme.px(5)
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45) }
                                                GradientStop { position: 1.0; color: Theme.primary }
                                            }
                                            Behavior on width { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }
                                        }
                                    }

                                    // Glowing Thumb Knob
                                    Rectangle {
                                        id: volThumb
                                        width: Theme.px(18)
                                        height: Theme.px(18)
                                        radius: Theme.px(9)
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: volSlider.isMuted ? -width : Math.max(0, Math.min(parent.width - width, (parent.width * volSlider.clampedVol) - width / 2))
                                        color: "#FFFFFF"
                                        scale: volTrackMouse.pressed ? 1.25 : (volTrackMouse.containsMouse ? 1.12 : 1.0)
                                        visible: !volSlider.isMuted
                                        Behavior on scale { NumberAnimation { duration: 110 } }
                                        Behavior on x { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }

                                        // Outer ambient glow ring
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width + 8
                                            height: parent.height + 8
                                            radius: width / 2
                                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, (volTrackMouse.pressed || volTrackMouse.containsMouse) ? 0.45 : 0.25)
                                            z: -1
                                        }
                                    }

                                    MouseArea {
                                        id: volTrackMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        function setVolFromX(mouseX) {
                                            var r = Math.max(0.0, Math.min(1.0, mouseX / width))
                                            if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                                Pipewire.defaultAudioSink.audio.volume = r
                                                if (Pipewire.defaultAudioSink.audio.muted) Pipewire.defaultAudioSink.audio.muted = false
                                            } else {
                                                Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(r * 100) + "%"])
                                            }
                                        }

                                        onPressed: mouse => setVolFromX(mouse.x)
                                        onPositionChanged: mouse => { if (pressed) setVolFromX(mouse.x) }
                                    }
                                }
                            }

                            // Card-level MouseArea for wheel scrolling & hover
                            MouseArea {
                                id: volCardMouse
                                anchors.fill: parent
                                z: -1
                                hoverEnabled: true
                                onWheel: wheel => {
                                    var delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                    var newVol = Math.max(0.0, Math.min(1.0, volSlider.clampedVol + delta))
                                    if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                        Pipewire.defaultAudioSink.audio.volume = newVol
                                        if (Pipewire.defaultAudioSink.audio.muted) Pipewire.defaultAudioSink.audio.muted = false
                                    } else {
                                        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(newVol * 100) + "%"])
                                    }
                                }
                            }
                        }

                        // B. Brightness Studio Capsule Slider
                        Rectangle {
                            id: brightSlider
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.px(16)
                            color: brightCardMouse.containsMouse
                                ? Qt.rgba(0.045, 0.05, 0.06, 0.85)
                                : Qt.rgba(0.025, 0.03, 0.035, 0.75)
                            border.width: 1
                            border.color: (brightTrackMouse.pressed || brightCardMouse.containsMouse)
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                                : Qt.rgba(1, 1, 1, 0.07)
                            clip: true
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Behavior on border.color { ColorAnimation { duration: 160 } }

                            property int curBrightness: (SysBackend && SysBackend.lastBrightnessPct >= 0)
                                ? SysBackend.lastBrightnessPct : 80
                            readonly property real brightRatio: Math.max(0.05, Math.min(1.0, curBrightness / 100.0))

                            // Top edge subtle glass highlight
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Qt.rgba(255, 255, 255, 0.08)
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.px(12)
                                spacing: Theme.px(8)

                                // 1. Header Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(10)

                                    // Brightness Icon Squircle
                                    Rectangle {
                                        width: Theme.px(32)
                                        height: Theme.px(32)
                                        radius: Theme.px(10)
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, brightIconMouse.containsMouse ? 0.28 : 0.14)
                                        border.width: 1
                                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                                        scale: brightIconMouse.pressed ? 0.90 : (brightIconMouse.containsMouse ? 1.05 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 120 } }
                                        Behavior on color { ColorAnimation { duration: 140 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: brightSlider.curBrightness < 33 ? "󰃞" : (brightSlider.curBrightness < 66 ? "󰃟" : "󰃠")
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 15
                                            color: Theme.primary
                                        }

                                        MouseArea {
                                            id: brightIconMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var next = brightSlider.curBrightness < 50 ? 80 : 30
                                                brightSlider.curBrightness = next
                                                Quickshell.execDetached(["brightnessctl", "set", next + "%", "-q"])
                                            }
                                        }
                                    }

                                    // Labels
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: "SCREEN BRIGHTNESS"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontPx(10.5)
                                            font.bold: true
                                            color: Theme.fg
                                        }

                                        Text {
                                            text: "Display Backlight"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontPx(9)
                                            color: Theme.fgDim
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // Right Percentage Badge
                                    Rectangle {
                                        width: Theme.px(54)
                                        height: Theme.px(22)
                                        radius: Theme.px(11)
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                                        border.width: 1
                                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)

                                        Text {
                                            anchors.centerIn: parent
                                            text: brightSlider.curBrightness + "%"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontPx(10)
                                            font.bold: true
                                            color: Theme.primary
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                // 2. Track Row
                                Item {
                                    id: brightTrackArea
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Theme.px(26)

                                    // Groove Channel
                                    Rectangle {
                                        id: brightGroove
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: Theme.px(10)
                                        radius: Theme.px(5)
                                        color: Qt.rgba(0, 0, 0, 0.65)
                                        border.width: 1
                                        border.color: Qt.rgba(255, 255, 255, 0.06)
                                        clip: true

                                        // Active Gradient Fill
                                        Rectangle {
                                            id: brightFill
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: Math.max(0, Math.min(parent.width, parent.width * brightSlider.brightRatio))
                                            radius: Theme.px(5)
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45) }
                                                GradientStop { position: 1.0; color: Theme.primary }
                                            }
                                            Behavior on width { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }
                                        }
                                    }

                                    // Glowing Thumb Knob
                                    Rectangle {
                                        id: brightThumb
                                        width: Theme.px(18)
                                        height: Theme.px(18)
                                        radius: Theme.px(9)
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: Math.max(0, Math.min(parent.width - width, (parent.width * brightSlider.brightRatio) - width / 2))
                                        color: "#FFFFFF"
                                        scale: brightTrackMouse.pressed ? 1.25 : (brightTrackMouse.containsMouse ? 1.12 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 110 } }
                                        Behavior on x { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }

                                        // Outer ambient glow ring
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width + 8
                                            height: parent.height + 8
                                            radius: width / 2
                                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, (brightTrackMouse.pressed || brightTrackMouse.containsMouse) ? 0.45 : 0.25)
                                            z: -1
                                        }
                                    }

                                    MouseArea {
                                        id: brightTrackMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        function setBrightFromX(mouseX) {
                                            var pct = Math.round(Math.max(5, Math.min(100, (mouseX / width) * 100)))
                                            brightSlider.curBrightness = pct
                                            Quickshell.execDetached(["brightnessctl", "set", pct + "%", "-q"])
                                        }

                                        onPressed: mouse => setBrightFromX(mouse.x)
                                        onPositionChanged: mouse => { if (pressed) setBrightFromX(mouse.x) }
                                    }
                                }
                            }

                            // Card-level MouseArea for wheel scrolling & hover
                            MouseArea {
                                id: brightCardMouse
                                anchors.fill: parent
                                z: -1
                                hoverEnabled: true
                                onWheel: wheel => {
                                    var delta = wheel.angleDelta.y > 0 ? 5 : -5
                                    var pct = Math.max(5, Math.min(100, brightSlider.curBrightness + delta))
                                    brightSlider.curBrightness = pct
                                    Quickshell.execDetached(["brightnessctl", "set", pct + "%", "-q"])
                                }
                            }
                        }
                    }

                    // ── Right Column: 2x2 Quick Toggles Grid ──
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: Theme.px(380)
                        Layout.fillHeight: true
                        columns: 2
                        rowSpacing: Theme.px(10)
                        columnSpacing: Theme.px(10)

                        // ── Button 1: Wi-Fi ──
                        Rectangle {
                            id: tileWifi
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.px(16)
                            property bool wifiOn: true
                            property string ssid: "Connected"
                            color: tileWifi.wifiOn
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, wifiMouse.containsMouse ? 0.16 : 0.08)
                                : (wifiMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0.025, 0.03, 0.035, 0.75))
                            border.width: 1
                            border.color: tileWifi.wifiOn
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, wifiMouse.containsMouse ? 0.45 : 0.25)
                                : (wifiMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07))
                            scale: wifiMouse.pressed ? 0.97 : (wifiMouse.containsMouse ? 1.01 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on border.color { ColorAnimation { duration: 140 } }

                            // Top glass highlight
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Qt.rgba(255, 255, 255, tileWifi.wifiOn ? 0.16 : 0.06)
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.px(12)
                                spacing: 0

                                // Header Row: Squircle Icon + Status LED Pill
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(8)

                                    Rectangle {
                                        width: Theme.px(34)
                                        height: Theme.px(34)
                                        radius: Theme.px(10)
                                        color: tileWifi.wifiOn
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                                            : Qt.rgba(1, 1, 1, 0.05)
                                        border.width: 1
                                        border.color: tileWifi.wifiOn
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                            : Qt.rgba(1, 1, 1, 0.08)

                                        Text {
                                            anchors.centerIn: parent
                                            text: tileWifi.wifiOn ? "󰤨" : "󰤭"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 15
                                            color: tileWifi.wifiOn ? Theme.primary : Theme.fgDim
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Micro LED Status Pill
                                    Rectangle {
                                        height: Theme.px(18)
                                        radius: Theme.px(9)
                                        width: Theme.px(42)
                                        color: tileWifi.wifiOn
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                            : Qt.rgba(1, 1, 1, 0.04)
                                        border.width: 1
                                        border.color: tileWifi.wifiOn
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                                            : Qt.rgba(1, 1, 1, 0.07)

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Rectangle {
                                                width: 5
                                                height: 5
                                                radius: 2.5
                                                color: tileWifi.wifiOn ? Theme.primary : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.4)
                                            }

                                            Text {
                                                text: tileWifi.wifiOn ? "ON" : "OFF"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontPx(8.5)
                                                font.bold: true
                                                color: tileWifi.wifiOn ? Theme.primary : Theme.fgDim
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                // Bottom Labels
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "Wi-Fi"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(11.5)
                                        font.bold: true
                                        color: Theme.fg
                                    }

                                    Text {
                                        text: tileWifi.wifiOn ? tileWifi.ssid : "Disconnected"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(9)
                                        color: tileWifi.wifiOn ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.70) : Theme.fgDim
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: wifiMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                pressAndHoldInterval: 450
                                property bool held: false
                                onPressed: { held = false }
                                onPressAndHold: {
                                    held = true
                                    Quickshell.execDetached(["nm-connection-editor"])
                                }
                                onClicked: {
                                    if (!held) {
                                        var nextState = !tileWifi.wifiOn
                                        tileWifi.wifiOn = nextState
                                        Quickshell.execDetached(["nmcli", "radio", "wifi", nextState ? "on" : "off"])
                                        wifiPoller.running = false
                                        wifiPoller.running = true
                                    }
                                }
                            }
                        }

                        // ── Button 2: Bluetooth ──
                        Rectangle {
                            id: tileBt
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.px(16)
                            property bool btOn: false
                            color: tileBt.btOn
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, btMouse.containsMouse ? 0.16 : 0.08)
                                : (btMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0.025, 0.03, 0.035, 0.75))
                            border.width: 1
                            border.color: tileBt.btOn
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, btMouse.containsMouse ? 0.45 : 0.25)
                                : (btMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07))
                            scale: btMouse.pressed ? 0.97 : (btMouse.containsMouse ? 1.01 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on border.color { ColorAnimation { duration: 140 } }

                            // Top glass highlight
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Qt.rgba(255, 255, 255, tileBt.btOn ? 0.16 : 0.06)
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.px(12)
                                spacing: 0

                                // Header Row: Squircle Icon + Status LED Pill
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(8)

                                    Rectangle {
                                        width: Theme.px(34)
                                        height: Theme.px(34)
                                        radius: Theme.px(10)
                                        color: tileBt.btOn
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                                            : Qt.rgba(1, 1, 1, 0.05)
                                        border.width: 1
                                        border.color: tileBt.btOn
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                            : Qt.rgba(1, 1, 1, 0.08)

                                        Text {
                                            anchors.centerIn: parent
                                            text: tileBt.btOn ? "󰂯" : "󰂲"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 15
                                            color: tileBt.btOn ? Theme.primary : Theme.fgDim
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Micro LED Status Pill
                                    Rectangle {
                                        height: Theme.px(18)
                                        radius: Theme.px(9)
                                        width: Theme.px(42)
                                        color: tileBt.btOn
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                            : Qt.rgba(1, 1, 1, 0.04)
                                        border.width: 1
                                        border.color: tileBt.btOn
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                                            : Qt.rgba(1, 1, 1, 0.07)

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Rectangle {
                                                width: 5
                                                height: 5
                                                radius: 2.5
                                                color: tileBt.btOn ? Theme.primary : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.4)
                                            }

                                            Text {
                                                text: tileBt.btOn ? "ON" : "OFF"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontPx(8.5)
                                                font.bold: true
                                                color: tileBt.btOn ? Theme.primary : Theme.fgDim
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                // Bottom Labels
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "Bluetooth"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(11.5)
                                        font.bold: true
                                        color: Theme.fg
                                    }

                                    Text {
                                        text: tileBt.btOn ? "Ready / Active" : "Disabled"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(9)
                                        color: tileBt.btOn ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.70) : Theme.fgDim
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: btMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                pressAndHoldInterval: 450
                                property bool held: false
                                onPressed: { held = false }
                                onPressAndHold: {
                                    held = true
                                    Quickshell.execDetached(["blueman-manager"])
                                }
                                onClicked: {
                                    if (!held) {
                                        var next = !tileBt.btOn
                                        tileBt.btOn = next
                                        Quickshell.execDetached(["bluetoothctl", "power", next ? "on" : "off"])
                                        btPoller.running = false
                                        btPoller.running = true
                                    }
                                }
                            }
                        }

                        // ── Button 3: Do Not Disturb ──
                        Rectangle {
                            id: tileDnd
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.px(16)
                            readonly property bool isDnd: NotificationService.dnd || GlobalState.doNotDisturb
                            color: tileDnd.isDnd
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, dndMouse.containsMouse ? 0.16 : 0.08)
                                : (dndMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0.025, 0.03, 0.035, 0.75))
                            border.width: 1
                            border.color: tileDnd.isDnd
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, dndMouse.containsMouse ? 0.45 : 0.25)
                                : (dndMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07))
                            scale: dndMouse.pressed ? 0.97 : (dndMouse.containsMouse ? 1.01 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on border.color { ColorAnimation { duration: 140 } }

                            // Top glass highlight
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Qt.rgba(255, 255, 255, tileDnd.isDnd ? 0.16 : 0.06)
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.px(12)
                                spacing: 0

                                // Header Row: Squircle Icon + Status LED Pill
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(8)

                                    Rectangle {
                                        width: Theme.px(34)
                                        height: Theme.px(34)
                                        radius: Theme.px(10)
                                        color: tileDnd.isDnd
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                                            : Qt.rgba(1, 1, 1, 0.05)
                                        border.width: 1
                                        border.color: tileDnd.isDnd
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                            : Qt.rgba(1, 1, 1, 0.08)

                                        Text {
                                            anchors.centerIn: parent
                                            text: tileDnd.isDnd ? "󰂛" : "󰂚"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 15
                                            color: tileDnd.isDnd ? Theme.primary : Theme.fgDim
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Micro LED Status Pill
                                    Rectangle {
                                        height: Theme.px(18)
                                        radius: Theme.px(9)
                                        width: Theme.px(42)
                                        color: tileDnd.isDnd
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                            : Qt.rgba(1, 1, 1, 0.04)
                                        border.width: 1
                                        border.color: tileDnd.isDnd
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                                            : Qt.rgba(1, 1, 1, 0.07)

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Rectangle {
                                                width: 5
                                                height: 5
                                                radius: 2.5
                                                color: tileDnd.isDnd ? Theme.primary : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.4)
                                            }

                                            Text {
                                                text: tileDnd.isDnd ? "ON" : "OFF"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontPx(8.5)
                                                font.bold: true
                                                color: tileDnd.isDnd ? Theme.primary : Theme.fgDim
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                // Bottom Labels
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "Do Not Disturb"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(11.5)
                                        font.bold: true
                                        color: Theme.fg
                                    }

                                    Text {
                                        text: tileDnd.isDnd ? "Muted / Silent" : "Alerts Active"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(9)
                                        color: tileDnd.isDnd ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.70) : Theme.fgDim
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: dndMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof NotificationService !== "undefined" && NotificationService.toggleDnd) {
                                        NotificationService.toggleDnd()
                                        GlobalState.doNotDisturb = NotificationService.dnd
                                    } else {
                                        GlobalState.doNotDisturb = !GlobalState.doNotDisturb
                                    }
                                }
                            }
                        }

                        // ── Button 4: Night Light / Appearance ──
                        Rectangle {
                            id: tileAppr
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.px(16)
                            readonly property bool isDark: (typeof Theme !== "undefined" && Theme.isDark !== undefined) ? Theme.isDark : true
                            color: tileAppr.isDark
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, apprMouse.containsMouse ? 0.16 : 0.08)
                                : (apprMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0.025, 0.03, 0.035, 0.75))
                            border.width: 1
                            border.color: tileAppr.isDark
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, apprMouse.containsMouse ? 0.45 : 0.25)
                                : (apprMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07))
                            scale: apprMouse.pressed ? 0.97 : (apprMouse.containsMouse ? 1.01 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on border.color { ColorAnimation { duration: 140 } }

                            // Top glass highlight
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Qt.rgba(255, 255, 255, tileAppr.isDark ? 0.16 : 0.06)
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.px(12)
                                spacing: 0

                                // Header Row: Squircle Icon + Status LED Pill
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(8)

                                    Rectangle {
                                        width: Theme.px(34)
                                        height: Theme.px(34)
                                        radius: Theme.px(10)
                                        color: tileAppr.isDark
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                                            : Qt.rgba(1, 1, 1, 0.05)
                                        border.width: 1
                                        border.color: tileAppr.isDark
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                            : Qt.rgba(1, 1, 1, 0.08)

                                        Text {
                                            anchors.centerIn: parent
                                            text: tileAppr.isDark ? "󰖔" : "󰖙"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 15
                                            color: tileAppr.isDark ? Theme.primary : Theme.fgDim
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Micro LED Status Pill
                                    Rectangle {
                                        height: Theme.px(18)
                                        radius: Theme.px(9)
                                        width: Theme.px(42)
                                        color: tileAppr.isDark
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                            : Qt.rgba(1, 1, 1, 0.04)
                                        border.width: 1
                                        border.color: tileAppr.isDark
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                                            : Qt.rgba(1, 1, 1, 0.07)

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Rectangle {
                                                width: 5
                                                height: 5
                                                radius: 2.5
                                                color: tileAppr.isDark ? Theme.primary : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.4)
                                            }

                                            Text {
                                                text: tileAppr.isDark ? "DARK" : "LITE"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontPx(8.5)
                                                font.bold: true
                                                color: tileAppr.isDark ? Theme.primary : Theme.fgDim
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                // Bottom Labels
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "Theme Mode"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(11.5)
                                        font.bold: true
                                        color: Theme.fg
                                    }

                                    Text {
                                        text: tileAppr.isDark ? "Dark Cyber" : "Light Porcelain"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(9)
                                        color: tileAppr.isDark ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.70) : Theme.fgDim
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: apprMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof Theme !== "undefined" && Theme.isDark !== undefined) {
                                        Theme.isDark = !Theme.isDark
                                    }
                                }
                            }
                        }
                    }
                }
            }

            /* ============================================================= */
            /* ============================================================= */
            /* PAGE 0: DEFAULT MEDIA & TACTICAL CHRONOMETER                  */
            /* ============================================================= */
            Item {
                id: pageMedia
                anchors.fill: parent
                visible: opacity > 0.01
                opacity: root.notchPage === 0 ? 1.0 : 0.0
                transform: Translate {
                    x: (0 - root.notchPage) * Theme.px(80)
                    Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutExpo } }
                }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.px(14)

                    // 1. LEFT COLUMN: ANIMATED TACTICAL CHRONOMETER
                    Item {
                        id: centerCol
                        Layout.fillWidth: true
                        Layout.preferredWidth: Theme.px(360)
                        Layout.fillHeight: true
                        clip: true

                        TacticalChronometer {
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                        }
                    }

                    // Vertical Divider
                    Rectangle {
                        Layout.fillHeight: true
                        width: 1
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
                    }

                    // 2. RIGHT COLUMN: MEDIA PLAYER & KINETIC CAIRO LYRICS
                    Item {
                        id: rightCol
                        Layout.fillWidth: true
                        Layout.preferredWidth: Theme.px(420)
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.px(8)

                            // Track Header Row (Title, Artist & Album Art)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.px(10)

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: LyricsService.hasTrack ? LyricsService.trackTitle : "No Media Active"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(12.5)
                                        font.weight: Font.Bold
                                        color: Theme.fg
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: LyricsService.hasTrack ? (LyricsService.trackArtist + (LyricsService.trackAlbum ? " • " + LyricsService.trackAlbum : "")) : "Standby // No Media"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(9.5)
                                        font.weight: Font.Medium
                                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55)
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    width: Theme.px(36)
                                    height: Theme.px(36)
                                    radius: Theme.px(10)
                                    color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.90)
                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                                    border.width: 1
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: LyricsService.artUrl
                                        fillMode: Image.PreserveAspectCrop
                                        visible: LyricsService.hasTrack && LyricsService.artUrl.length > 0 && status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !LyricsService.hasTrack || !LyricsService.artUrl || LyricsService.artUrl.length === 0
                                        text: "music_note"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 16
                                        color: Theme.primary
                                    }
                                }
                            }

                            // Dynamic Lyrics Engine: MiniCairo (Default / Timed) or ListView (Untimed Fallback Only)
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                MiniCairo {
                                    id: miniCairo
                                    anchors.fill: parent
                                    active: root.open && root.notchPage === 0
                                    visible: !miniCairo.isUntimed
                                }

                                ListView {
                                    id: lyricsList
                                    anchors.fill: parent
                                    visible: miniCairo.isUntimed
                                    model: miniCairo.rawLines || []
                                    clip: true
                                    spacing: 4
                                    preferredHighlightBegin: parent.height * 0.40
                                    preferredHighlightEnd: parent.height * 0.60
                                    highlightRangeMode: ListView.ApplyRange

                                    currentIndex: {
                                        if (!miniCairo.rawLines || miniCairo.rawLines.length === 0) return 0
                                        var pos = LyricsService.currentPosition
                                        var idx = 0
                                        for (var i = 0; i < miniCairo.rawLines.length; i++) {
                                            if (miniCairo.rawLines[i].time <= pos) idx = i
                                            else break
                                        }
                                        return idx
                                    }

                                    delegate: Item {
                                        width: lyricsList.width
                                        height: lyricText.implicitHeight + 4
                                        readonly property bool isCurrent: index === lyricsList.currentIndex

                                        Text {
                                            id: lyricText
                                            anchors.centerIn: parent
                                            width: parent.width - 16
                                            text: modelData.text || ""
                                            font.family: Theme.fontFamily
                                            font.pixelSize: isCurrent ? Theme.fontPx(11.5) : Theme.fontPx(9.5)
                                            font.weight: isCurrent ? Font.Bold : Font.Normal
                                            color: isCurrent ? Theme.primary : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.40)
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.Wrap
                                            Behavior on color { ColorAnimation { duration: 160 } }
                                        }
                                    }
                                }
                            }

                            // Media Transport Bar
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.px(24)
                                spacing: Theme.px(8)

                                Text {
                                    text: root.formatTime(LyricsService.currentPosition) + " / " + root.formatTime(LyricsService.totalLength)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(8.5)
                                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.50)
                                }

                                Item { Layout.fillWidth: true }

                                // Prev
                                Rectangle {
                                    width: Theme.px(22); height: Theme.px(22); radius: Theme.px(11)
                                    color: prevM.containsMouse ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12) : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "skip_previous"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 13
                                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.70)
                                    }
                                    MouseArea {
                                        id: prevM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (LyricsService.activePlayer) LyricsService.activePlayer.previous()
                                    }
                                }

                                // Play / Pause
                                Rectangle {
                                    width: Theme.px(24); height: Theme.px(24); radius: Theme.px(12)
                                    color: playM.containsMouse ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                                    Text {
                                        anchors.centerIn: parent
                                        text: LyricsService.isPlaying ? "pause" : "play_arrow"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 14
                                        color: playM.containsMouse ? Theme.bg : Theme.primary
                                    }
                                    MouseArea {
                                        id: playM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (LyricsService.activePlayer) LyricsService.activePlayer.togglePlaying()
                                    }
                                }

                                // Next
                                Rectangle {
                                    width: Theme.px(22); height: Theme.px(22); radius: Theme.px(11)
                                    color: nextM.containsMouse ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12) : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "skip_next"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 13
                                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.70)
                                    }
                                    MouseArea {
                                        id: nextM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (LyricsService.activePlayer) LyricsService.activePlayer.next()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            /* ============================================================= */
            /* PAGE 1: POMODORO & WEATHER                                    */
            /* ============================================================= */
            Item {
                id: pagePomodoroWeather
                anchors.fill: parent
                visible: opacity > 0.01
                opacity: root.notchPage === 1 ? 1.0 : 0.0
                transform: Translate {
                    x: (1 - root.notchPage) * Theme.px(80)
                    Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutExpo } }
                }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.px(14)

                    // ── Left Column: Tactical Pomodoro ──
                    Item {
                        Layout.preferredWidth: Theme.px(320)
                        Layout.fillHeight: true
                        clip: true

                        TacticalPomodoro {
                            anchors.fill: parent
                        }
                    }

                    // Vertical Divider
                    Rectangle {
                        Layout.fillHeight: true
                        width: 1
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
                    }

                    // ── Right Column: Weather Bento Card ──
                    Item {
                        id: weatherCard
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        property string cityName: "Patna, IN"
                        property string temp: "--"
                        property string feelsLike: "--"
                        property string desc: "Clear Sky"
                        property string icon: "󰖐"
                        property string humidity: "--"
                        property string wind: "--"
                        property var forecast: []

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.px(14)
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.05)
                            border.width: 1
                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.px(12)
                            spacing: Theme.px(8)

                            // Top Header: City & Refresh
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.px(8)

                                Text {
                                    text: "󰍎 " + weatherCard.cityName
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(12)
                                    font.bold: true
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    width: Theme.px(24)
                                    height: Theme.px(24)
                                    radius: Theme.px(12)
                                    color: weathRefHov.containsMouse ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰑐"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        color: weathRefHov.containsMouse ? Theme.primary : Theme.fgDim
                                    }
                                    MouseArea {
                                        id: weathRefHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            weatherPoller.command = ["python3", root.weatherScriptPath, "status", "--force"]
                                            weatherPoller.running = false
                                            weatherPoller.running = true
                                        }
                                    }
                                }
                            }

                            // Center Row: Icon + Temp + Description
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.px(12)

                                // Weather Icon
                                Text {
                                    text: weatherCard.icon
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 36
                                    color: Theme.primary
                                }

                                ColumnLayout {
                                    spacing: 0
                                    Text {
                                        text: weatherCard.temp
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(22)
                                        font.bold: true
                                        color: Theme.fg
                                    }
                                    Text {
                                        text: weatherCard.desc
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(10)
                                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.70)
                                        elide: Text.ElideRight
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Feels Like Badge
                                Rectangle {
                                    Layout.preferredHeight: Theme.px(22)
                                    Layout.preferredWidth: feelsText.implicitWidth + Theme.px(14)
                                    radius: Theme.px(11)
                                    color: Qt.rgba(0, 0, 0, 0.40)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.08)

                                    Text {
                                        id: feelsText
                                        anchors.centerIn: parent
                                        text: "Feels " + weatherCard.feelsLike
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(9)
                                        color: Theme.primary
                                    }
                                }
                            }

                            // Sub-metrics Row (Humidity & Wind)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.px(10)

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Theme.px(26)
                                    radius: Theme.px(8)
                                    color: Qt.rgba(0, 0, 0, 0.30)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.06)

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: Theme.px(4)
                                        Text {
                                            text: "󰖌"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            color: Theme.primary
                                        }
                                        Text {
                                            text: "Humidity " + weatherCard.humidity
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontPx(9)
                                            color: Theme.fgDim
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Theme.px(26)
                                    radius: Theme.px(8)
                                    color: Qt.rgba(0, 0, 0, 0.30)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.06)

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: Theme.px(4)
                                        Text {
                                            text: "󰖝"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            color: Theme.primary
                                        }
                                        Text {
                                            text: "Wind " + weatherCard.wind
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontPx(9)
                                            color: Theme.fgDim
                                        }
                                    }
                                }
                            }

                            // Forecast mini preview row
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.px(32)
                                spacing: Theme.px(6)
                                visible: weatherCard.forecast && weatherCard.forecast.length > 0

                                Repeater {
                                    model: (weatherCard.forecast && Array.isArray(weatherCard.forecast)) ? weatherCard.forecast.slice(0, 4) : []
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: Theme.px(6)
                                        color: Qt.rgba(1, 1, 1, 0.03)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.05)

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: Theme.px(4)
                                            Text {
                                                text: modelData.day || ""
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontPx(8.5)
                                                font.bold: true
                                                color: Theme.fgDim
                                            }
                                            Text {
                                                text: modelData.icon || "󰖐"
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 10
                                                color: Theme.primary
                                            }
                                            Text {
                                                text: modelData.temp || "--"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontPx(8.5)
                                                color: Theme.fg
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
