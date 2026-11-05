import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../Singletons"

/**
 * LockClock:
 * Sleek, animated clock with day and date displayed in the bottom-right corner of the lock screen.
 * Matches the styling of the former desktop clock:
 *   - Bold high-contrast time readout
 *   - Day of the week in cursive "Caveat" font
 *   - Clean date string with a sleek vertical divider
 *   - Soft drop shadow for legibility over blurred backgrounds
 *   - Smooth fluid sliding and fading entrance animation
 */
Item {
    id: root

    implicitWidth: clockCol.implicitWidth + 8
    implicitHeight: clockCol.implicitHeight + 8

    property string timeStr: Qt.formatTime(new Date(), "hh:mm")
    property string dayStr: Qt.formatDate(new Date(), "dddd")
    property string dateStr: Qt.formatDate(new Date(), "d MMMM")
    readonly property var splashes: [
        "Woo, animations!",
        "It's like Hypr, but better.",
        "Release 1.0 when?",
        "It's not awesome, it's Hyprland!",
        "\"I commit too often, people can't catch up lmao\" - Vaxry",
        "This text is random.",
        "\"There are reasons to not use rust.\" - Boga",
        "Read the wiki.",
        "\"Hello everyone this is YOUR daily dose of ‘read the wiki’\" - Vaxry",
        "h",
        "\"‘why no work’, bro I haven't hacked your pc to get live feeds yet\" - Vaxry",
        "Compile, wait for 20 minutes, notice a new commit, compile again.",
        "To rice, or not to rice, that is the question.",
        "Now available on Fedora!",
        "\"Hyprland is so good it starts with a capital letter\" - Hazel",
        "\"please make this message a splash\" - eriedaberrie",
        "\"the only wayland compositor powered by fried chicken\" - raf",
        "\"This will never get into Hyprland\" - Flafy",
        "\"Hyprland only gives you up on -git\" - fazzi",
        "Segmentation fault (core dumped)",
        "\"disabling hyprland logo is a war crime\" - Vaxry",
        "some basic startup code",
        "\"I think I am addicted to hyprland\" - mathisbuilder",
        "Thanks Brodie!",
        "Thanks fufexan!",
        "Thanks raf!",
        "You can't use --splash to change this message :)",
        "Hyprland will overtake Gnome in popularity by [insert year]",
        "Designed in California - Assembled in China",
        "\"something <time here> and still no new splash\" - snowman",
        "My name is Land. Hypr Land. One red bull, shaken not stirred.",
        "\"Glory To The Emperor\" - raf",
        "Help I forgot to install kitty",
        "Go to settings to activate Hyprland",
        "Why is there code??? Make a damn .exe file and give it to me.",
        "Hyprland: sleek, fluid, and unstoppable"
    ]

    property string splashStr: root.splashes[Math.floor(Math.random() * root.splashes.length)]

    function pickRandomSplash() {
        var next = root.splashes[Math.floor(Math.random() * root.splashes.length)]
        if (next === root.splashStr && root.splashes.length > 1) {
            next = root.splashes[(root.splashes.indexOf(next) + 1) % root.splashes.length]
        }
        root.splashStr = next
    }

    function refresh() {
        var d = new Date()
        root.timeStr = Qt.formatTime(d, "hh:mm")
        root.dayStr = Qt.formatDate(d, "dddd")
        root.dateStr = Qt.formatDate(d, "d MMMM")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Refresh the splash quote every 45 seconds or on every entrance
    Timer {
        interval: 45000
        running: true
        repeat: true
        onTriggered: root.pickRandomSplash()
    }

    /* ── Read Lock Screen Configuration ───────────────────────────────────── */
    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/hypr/carbon-lockscreen.json"
    property bool enabledSetting: true

    FileView {
        id: cfgFile
        path: root.configPath
        onFileChanged: root.reloadConfig()
        onLoaded: root.reloadConfig()
    }

    function reloadConfig() {
        try {
            const txt = cfgFile.text().trim()
            if (txt.length > 0) {
                const parsed = JSON.parse(txt)
                if (parsed.clock !== undefined) {
                    root.enabledSetting = parsed.clock
                }
            }
        } catch (e) {}
    }

    Component.onCompleted: root.reloadConfig()

    function easeOutCubic(p) {
        var x = Math.max(0.0, Math.min(1.0, p))
        return 1.0 - Math.pow(1.0 - x, 3.0)
    }

    /* ── Smooth Animated Visibility & Entrance ───────────────────────────── */
    property bool stageDriven: false
    property bool entered: stageDriven

    readonly property real exitOpacity: {
        if (LockTransition.phase === "unlocking") {
            if (LockTransition.u < 520.0) return 1.0
            return Math.max(0.0, 1.0 - (LockTransition.u - 520.0) / 450.0)
        }
        if (LockTransition.phase === "post_unlock") return 0.0
        return 1.0
    }

    visible: opacity > 0.01
    opacity: ((entered && enabledSetting) ? 1.0 : 0.0) * root.exitOpacity
    transform: Translate {
        id: transOffset
        y: root.stageDriven ? 0 : (root.entered ? 0 : 36)
        x: root.stageDriven ? 0 : (root.entered ? 0 : 16)

        Behavior on y {
            enabled: !root.stageDriven
            NumberAnimation {
                duration: 650
                easing.type: Easing.OutCubic
            }
        }
        Behavior on x {
            enabled: !root.stageDriven
            NumberAnimation {
                duration: 650
                easing.type: Easing.OutCubic
            }
        }
    }

    Behavior on opacity {
        enabled: !root.stageDriven
        NumberAnimation {
            duration: 520
            easing.type: Easing.OutQuad
        }
    }

    Timer {
        id: introDelay
        interval: 180
        running: !root.stageDriven
        onTriggered: {
            root.pickRandomSplash()
            root.entered = true
        }
    }

    /* ── Drop Shadow Component ───────────────────────────────────────────── */
    Component {
        id: shadowFx
        MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.55
            shadowBlur: 0.65
        }
    }

    /* ── Clock Display ──────────────────────────────────────────────────── */
    Column {
        id: clockCol
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 2

        // Time Readout with staggered digit roll-in (1000ms, 900ms duration, 70ms stagger)
        Row {
            id: timeRow
            anchors.right: parent.right
            spacing: 0

            Repeater {
                model: root.timeStr.length

                Item {
                    id: charWrapper
                    required property int index
                    readonly property string charText: root.timeStr.charAt(index)

                    width: charTextLabel.implicitWidth
                    height: charTextLabel.implicitHeight

                    readonly property real charStartTime: 580.0 + index * 40.0
                    readonly property real charProgress: {
                        if (LockTransition.reducedMotion) return 1.0
                        if (LockTransition.phase === "locked") return 1.0
                        if (LockTransition.phase === "locking") {
                            if (LockTransition.t < charStartTime) return 0.0
                            return Math.min(1.0, (LockTransition.t - charStartTime) / 450.0)
                        }
                        if (LockTransition.phase === "unlocking") return 1.0
                        return 0.0
                    }

                    readonly property real charEased: root.easeOutCubic(charProgress)

                    Text {
                        id: charTextLabel
                        text: charWrapper.charText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(68)
                        font.weight: Font.Bold
                        color: "#FFFFFF"
                        opacity: charWrapper.charEased
                        transform: Translate {
                            y: (1.0 - charWrapper.charEased) * (charTextLabel.font.pixelSize * 0.45)
                        }

                        layer.enabled: true
                        layer.effect: shadowFx
                    }
                }
            }
        }

        // Ambient Hyprland Splash Quote (enters at 750ms, 400ms duration, 14px rise)
        readonly property real greetProgress: {
            if (LockTransition.reducedMotion) return 1.0
            if (LockTransition.phase === "locked") return 1.0
            if (LockTransition.phase === "locking") {
                if (LockTransition.t < 750.0) return 0.0
                return Math.min(1.0, (LockTransition.t - 750.0) / 400.0)
            }
            if (LockTransition.phase === "unlocking") return 1.0
            return 0.0
        }
        readonly property real greetEased: root.easeOutCubic(clockCol.greetProgress)

        Text {
            id: greetingText
            anchors.right: parent.right
            text: GreetingEngine.currentLine
            font.family: "Caveat"
            font.pixelSize: Theme.fontPx(22)
            font.weight: Font.Bold
            color: Theme.accentLit ? Theme.accentLit : (Theme.accent ? Theme.accent : "#00F0FF")
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            width: Math.min(460, root.parent ? root.parent.width * 0.45 : 460)
            opacity: clockCol.greetEased
            transform: Translate {
                y: 14.0 * (1.0 - clockCol.greetEased)
            }

            layer.enabled: true
            layer.effect: shadowFx

            Behavior on opacity {
                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
            }
        }

        // Day and Date Row (enters at 820ms, 400ms duration, 14px rise)
        readonly property real dateProgress: {
            if (LockTransition.reducedMotion) return 1.0
            if (LockTransition.phase === "locked") return 1.0
            if (LockTransition.phase === "locking") {
                if (LockTransition.t < 820.0) return 0.0
                return Math.min(1.0, (LockTransition.t - 820.0) / 400.0)
            }
            if (LockTransition.phase === "unlocking") return 1.0
            return 0.0
        }
        readonly property real dateEased: root.easeOutCubic(clockCol.dateProgress)

        Row {
            anchors.right: parent.right
            spacing: 12
            opacity: clockCol.dateEased
            transform: Translate {
                y: 14.0 * (1.0 - clockCol.dateEased)
            }

            // Day of the week in cursive Caveat
            Text {
                id: dayText
                anchors.verticalCenter: parent.verticalCenter
                text: root.dayStr
                font.family: "Caveat"
                font.pixelSize: Theme.fontPx(34)
                font.weight: Font.Bold
                color: Theme.accentLit

                layer.enabled: true
                layer.effect: shadowFx
            }

            // Sleek Divider
            Rectangle {
                width: 1.5
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.25)
            }

            // Date string
            Text {
                id: dateText
                anchors.verticalCenter: parent.verticalCenter
                text: root.dateStr
                font.family: Theme.font
                font.pixelSize: Theme.fontPx(16)
                font.weight: Font.Medium
                color: "#CBD5E1"

                layer.enabled: true
                layer.effect: shadowFx
            }
        }
    }
}
