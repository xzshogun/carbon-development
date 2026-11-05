import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pam
import M3Shapes
import "../../Singletons"

/**
 * PasswordCard:
 * A highly animative rectangular card with curved corners (radius 26px):
 *   - Each password character gets a unique geometric shape (MaterialShape)
 *   - Bouncy spring-scale & rotation entrance on each keystroke
 *   - Continuous fluid sine-wave floating motion across the shapes
 *   - Reactive lock glyph tilt on every keystroke
 *   - Border energy pulse on keypress
 *   - Glowing pulsing submit arrow button
 *   - Elastic shake on incorrect password & smooth unlock dissolve
 */
Item {
    id: cardRoot

    signal unlocked()

    property real xOffset: 0
    property string buffer: ""
    property bool isAuthenticating: false
    property bool isError: false
    property bool isSuccess: false

    // Unique geometric shapes assigned to each character
    readonly property var shapePalette: [
        MaterialShape.Gem,
        MaterialShape.Diamond,
        MaterialShape.Sunny,
        MaterialShape.Cookie4Sided,
        MaterialShape.SoftBurst,
        MaterialShape.Clover4Leaf,
        MaterialShape.Heart,
        MaterialShape.Slanted,
        MaterialShape.Flower,
        MaterialShape.ClamShell,
        MaterialShape.Pentagon,
        MaterialShape.Triangle,
        MaterialShape.Arch,
        MaterialShape.Boom,
        MaterialShape.PuffyDiamond,
        MaterialShape.Ghostish
    ]

    property var logoComponent: null

    function easeOutBack(p) {
        var c1 = 1.70158
        var c3 = c1 + 1.0
        var x = Math.max(0.0, Math.min(1.0, p))
        return 1.0 + c3 * Math.pow(x - 1.0, 3.0) + c1 * Math.pow(x - 1.0, 2.0)
    }

    function easeInOutCubic(p) {
        var x = Math.max(0.0, Math.min(1.0, p))
        return x < 0.5 ? 4.0 * x * x * x : 1.0 - Math.pow(-2.0 * x + 2.0, 3.0) / 2.0
    }

    // Opening progression during lock-in (550ms -> 1100ms)
    readonly property real openProgress: {
        if (LockTransition.phase === "locking") {
            if (LockTransition.t < 550.0) return 0.0
            return Math.max(0.0, Math.min(1.0, (LockTransition.t - 550.0) / 550.0))
        }
        if (LockTransition.phase === "locked") return 1.0
        if (LockTransition.phase === "unlocking") return 1.0
        return 0.0
    }

    // Collapse progression during unlock-out (520ms -> 1020ms)
    readonly property real collapseProgress: {
        if (LockTransition.phase === "unlocking" || LockTransition.phase === "post_unlock") {
            if (LockTransition.u < 520.0) return 0.0
            return Math.max(0.0, Math.min(1.0, (LockTransition.u - 520.0) / 500.0))
        }
        return 0.0
    }

    implicitWidth: 312
    implicitHeight: 50
    width: {
        if (LockTransition.reducedMotion) return 312.0
        if (cardRoot.revealProgress < 0.999) {
            return 46.0 + 266.0 * cardRoot.easeOutBack(cardRoot.revealProgress)
        }
        if ((LockTransition.phase === "unlocking" || LockTransition.phase === "post_unlock") && cardRoot.collapseProgress > 0.001) {
            return Math.max(46.0, 312.0 - 266.0 * cardRoot.easeInOutCubic(cardRoot.collapseProgress))
        }
        return 312.0
    }
    height: 50

    property bool revealed: false
    property real revealProgress: revealed ? 1.0 : 0.0
    Behavior on revealProgress {
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    opacity: {
        if (LockTransition.reducedMotion) return (cardRoot.revealed ? 1.0 : 0.0)
        if (LockTransition.phase === "unlocking" || LockTransition.phase === "post_unlock") {
            if (LockTransition.u < 520.0) return cardRoot.revealProgress
            return Math.max(0.0, (1.0 - (LockTransition.u - 520.0) / 500.0) * cardRoot.revealProgress)
        }
        return cardRoot.revealProgress
    }
    scale: 0.92 + 0.08 * cardRoot.revealProgress
    visible: opacity > 0.005

    transform: [
        Translate {
            x: cardRoot.xOffset
            y: {
                if (LockTransition.reducedMotion) return 0.0
                if (cardRoot.revealProgress < 0.999) {
                    return 10.0 * (1.0 - cardRoot.easeOutBack(cardRoot.revealProgress))
                }
                if ((LockTransition.phase === "unlocking" || LockTransition.phase === "post_unlock") && cardRoot.collapseProgress > 0.001) {
                    return -6.0 * cardRoot.collapseProgress
                }
                return 0.0
            }
        }
    ]

    readonly property real innerContentOpacity: {
        if (LockTransition.reducedMotion) return (cardRoot.revealed ? 1.0 : 0.0)
        if (LockTransition.phase === "unlocking" || LockTransition.phase === "post_unlock") {
            if (LockTransition.u >= 520.0) return Math.max(0.0, (1.0 - (LockTransition.u - 520.0) / 200.0) * cardRoot.revealProgress)
            return cardRoot.revealProgress
        }
        return cardRoot.revealProgress
    }

    onRevealedChanged: {
        if (revealed) {
            keyPressPulse.restart()
        }
    }

    focus: true
    onActiveFocusChanged: {
        if (!activeFocus) forceActiveFocus()
    }

    Component.onCompleted: {
        forceActiveFocus()
    }

    function restartIdleTimer(ms) {
        idleHideTimer.interval = ms !== undefined ? ms : 3000
        idleHideTimer.restart()
    }

    function submitPassword() {
        if (buffer.length > 0 && !isAuthenticating) {
            isAuthenticating = true
            isError = false
            submitKickAnim.restart()
            passwd.start()
        }
    }

    /* ── Auto-Hide Idle Timer (Hides back after user stops typing) ────────── */
    Timer {
        id: idleHideTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!cardRoot.isAuthenticating) {
                cardRoot.revealed = false
                cardRoot.buffer = ""
            }
        }
    }

    Keys.onPressed: (event) => {
        if (isAuthenticating || isSuccess) return

        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            idleHideTimer.stop()
            if (buffer.length > 0) {
                submitPassword()
            } else {
                cardRoot.restartIdleTimer(800)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
            cardRoot.revealed = true
            cardRoot.restartIdleTimer(3000)
            if (event.modifiers & Qt.ControlModifier) {
                buffer = ""
            } else {
                buffer = buffer.slice(0, -1)
            }
            isError = false
            lockTiltAnim.restart()
            keyPressPulse.restart()
            if (cardRoot.logoComponent && typeof cardRoot.logoComponent.bump === "function") {
                cardRoot.logoComponent.bump()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            idleHideTimer.stop()
            buffer = ""
            cardRoot.revealed = false
            isError = false
            event.accepted = true
        } else if (event.text && event.text.length > 0) {
            const code = event.text.charCodeAt(0)
            if (code >= 32 && code !== 127) {
                cardRoot.revealed = true
                cardRoot.restartIdleTimer(3000)
                buffer += event.text
                isError = false
                lockTiltAnim.restart()
                keyPressPulse.restart()
                if (cardRoot.logoComponent && typeof cardRoot.logoComponent.bump === "function") {
                    cardRoot.logoComponent.bump()
                }
            }
            event.accepted = true
        } else {
            cardRoot.revealed = true
            cardRoot.restartIdleTimer(3000)
        }
    }

    /* ── Continuous Fluid Wave Rhythm for Password Shapes ────────────────── */
    FrameAnimation {
        id: waveTimer
        running: cardRoot.buffer.length > 0 && cardRoot.visible
        property real phase: 0
        onTriggered: phase += frameTime * 5.0
    }

    /* ── Keypress Border Glow Flash ──────────────────────────────────────── */
    SequentialAnimation {
        id: keyPressPulse
        NumberAnimation { target: borderGlow; property: "opacity"; to: 0.85; duration: 60; easing.type: Easing.OutQuad }
        NumberAnimation { target: borderGlow; property: "opacity"; to: 0.0; duration: 250; easing.type: Easing.OutQuad }
    }

    /* ── Lock Glyph Reactive Tilt ────────────────────────────────────────── */
    SequentialAnimation {
        id: lockTiltAnim
        NumberAnimation { target: lockIcon; property: "rotation"; to: -14; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: lockIcon; property: "rotation"; to: 10; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: lockIcon; property: "rotation"; to: 0; duration: 65; easing.type: Easing.OutBack }
    }

    /* ── Submit Arrow Kick Animation ─────────────────────────────────────── */
    SequentialAnimation {
        id: submitKickAnim
        NumberAnimation { target: arrowText; property: "x"; from: 0; to: 7; duration: 80; easing.type: Easing.OutQuad }
        NumberAnimation { target: arrowText; property: "x"; to: 0; duration: 140; easing.type: Easing.OutBack }
    }

    /* ── Shake Animation on Authentication Error (520ms) ─────────────────── */
    SequentialAnimation {
        id: shakeAnim

        PropertyAnimation { target: cardRoot; property: "xOffset"; from: 0; to: -12; duration: 60; easing.type: Easing.OutQuad }
        PropertyAnimation { target: cardRoot; property: "xOffset"; to: 10; duration: 100; easing.type: Easing.InOutQuad }
        PropertyAnimation { target: cardRoot; property: "xOffset"; to: -8; duration: 100; easing.type: Easing.InOutQuad }
        PropertyAnimation { target: cardRoot; property: "xOffset"; to: 5; duration: 100; easing.type: Easing.InOutQuad }
        PropertyAnimation { target: cardRoot; property: "xOffset"; to: 0; duration: 160; easing.type: Easing.OutCubic }
    }

    Timer {
        id: errorTimer
        interval: 650
        onTriggered: cardRoot.isError = false
    }

    /* ── PAM Authentication Context ──────────────────────────────────────── */
    PamContext {
        id: passwd
        config: "hyprlock"
        user: Quickshell.env("USER")

        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(cardRoot.buffer)
                cardRoot.buffer = ""
            }
        }

        onCompleted: (res) => {
            cardRoot.isAuthenticating = false
            if (res === PamResult.Success) {
                cardRoot.isSuccess = true
                if (cardRoot.logoComponent && typeof cardRoot.logoComponent.triggerExit === "function") {
                    cardRoot.logoComponent.triggerExit()
                }
                cardRoot.unlocked()
            } else {
                cardRoot.isError = true
                cardRoot.buffer = ""
                if (cardRoot.logoComponent && typeof cardRoot.logoComponent.wrong === "function") {
                    cardRoot.logoComponent.wrong()
                }
                shakeAnim.restart()
                errorTimer.restart()
                cardRoot.restartIdleTimer(1400)
            }
        }
    }

    Connections {
        target: LockTransition
        function onPhaseChanged() {
            if (LockTransition.phase === "idle" || LockTransition.phase === "locking") {
                cardRoot.revealed = false
                cardRoot.buffer = ""
                cardRoot.isSuccess = false
                cardRoot.isError = false
                cardRoot.isAuthenticating = false
            }
        }
    }

    /* ── Card Body ───────────────────────────────────────────────────────── */
    Rectangle {
        id: cardBg
        anchors.fill: parent
        anchors.horizontalCenterOffset: cardRoot.xOffset
        radius: 26
        clip: true

        color: Qt.rgba(0.08, 0.08, 0.12, 0.88)

        border.width: 1.5
        border.color: {
            if (cardRoot.isSuccess) return Theme.ok ? Theme.ok : "#a6e3a1"
            if (cardRoot.isError) return "#f2705f"
            if (cardRoot.buffer.length > 0) return Theme.accent ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.75) : Qt.rgba(0, 0.94, 1, 0.75)
            return Qt.rgba(1, 1, 1, 0.15)
        }

        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }

        // Animated border glow ring on keystrokes
        Rectangle {
            id: borderGlow
            anchors.fill: parent
            radius: 26
            color: "transparent"
            border.width: 2.0
            border.color: Theme.accent ? Theme.accent : "#00F0FF"
            opacity: 0.0
        }

        // Inner row layout: Lock Icon + Animated Shapes + Submit Arrow
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: cardRoot.width < 100 ? (cardRoot.width - 20) / 2 : 16
            anchors.rightMargin: cardRoot.width < 100 ? 0 : 10
            spacing: 12

            // Lock Icon with reactive rotation & success scale
            Item {
                width: 20
                height: 20
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: lockIcon
                    anchors.centerIn: parent
                    text: cardRoot.isSuccess ? "check" : (cardRoot.isError ? "error" : "lock")
                    font.family: Theme.fontIcon
                    font.pixelSize: 18
                    scale: cardRoot.isSuccess ? 1.15 : 1.0
                    color: {
                        if (cardRoot.isSuccess) return "#f4f6f5"
                        if (cardRoot.isError) return "#f2705f"
                        return Theme.accent ? Theme.accent : "#00F0FF"
                    }

                    Behavior on scale {
                        NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.56 }
                    }
                }
            }

            // Input / Placeholder / Unique Geometric Shapes Area
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                opacity: cardRoot.innerContentOpacity
                visible: cardRoot.innerContentOpacity > 0.001

                // Placeholder / Status Text
                Text {
                    id: placeholderText
                    anchors.centerIn: parent
                    visible: cardRoot.buffer.length === 0
                    text: {
                        if (cardRoot.isSuccess) return "Unlocked"
                        if (cardRoot.isError) return "Incorrect password"
                        if (cardRoot.isAuthenticating) return "Authenticating..."
                        return "Enter your password"
                    }
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(13)
                    font.italic: !cardRoot.isError && !cardRoot.isSuccess
                    color: {
                        if (cardRoot.isSuccess) return Theme.ok ? Theme.ok : "#a6e3a1"
                        if (cardRoot.isError) return "#f2705f"
                        return Qt.rgba(1, 1, 1, 0.40)
                    }
                }

                // Fluid Animated Unique Geometric Shapes
                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    visible: cardRoot.buffer.length > 0 && !cardRoot.isError

                    Repeater {
                        model: Math.min(cardRoot.buffer.length, 16)

                        Item {
                            id: shapeWrapper
                            required property int index
                            width: 15
                            height: 15
                            y: Math.sin(waveTimer.phase + index * 0.70) * 2.4

                            MaterialShape {
                                id: m3Shape
                                anchors.centerIn: parent
                                implicitSize: 13
                                shape: cardRoot.shapePalette[shapeWrapper.index % cardRoot.shapePalette.length]
                                color: Theme.accent ? Theme.accent : "#00F0FF"

                                Component.onCompleted: {
                                    entryAnim.restart()
                                }

                                ParallelAnimation {
                                    id: entryAnim
                                    NumberAnimation {
                                        target: m3Shape
                                        property: "scale"
                                        from: 0.1
                                        to: 1.0
                                        duration: 200
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.5
                                    }
                                    NumberAnimation {
                                        target: m3Shape
                                        property: "rotation"
                                        from: -30
                                        to: 0
                                        duration: 220
                                        easing.type: Easing.OutBack
                                    }
                                    ColorAnimation {
                                        target: m3Shape
                                        property: "color"
                                        from: "#FFFFFF"
                                        to: Theme.accent ? Theme.accent : "#00F0FF"
                                        duration: 240
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Right Submit Arrow Button with interactive glow pulse & check mark morph
            Rectangle {
                id: submitBtn
                width: 34
                height: 34
                radius: 17
                opacity: cardRoot.innerContentOpacity
                visible: cardRoot.innerContentOpacity > 0.001 || cardRoot.isSuccess
                Layout.alignment: Qt.AlignVCenter

                color: {
                    if (cardRoot.isSuccess) return "#f4f6f5"
                    if (cardRoot.buffer.length > 0 && !cardRoot.isAuthenticating) return Theme.accent ? Theme.accent : "#00F0FF"
                    return Qt.rgba(1, 1, 1, 0.08)
                }

                scale: {
                    if (cardRoot.isSuccess) return 1.15
                    if (cardRoot.buffer.length > 0 && !cardRoot.isAuthenticating) return submitMouse.containsMouse ? 1.12 : 1.04
                    return 1.0
                }

                Behavior on scale {
                    NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.56 }
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                // Glowing pulse halo behind active submit button
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 6
                    height: parent.height + 6
                    radius: width / 2
                    color: Theme.accent ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35) : Qt.rgba(0, 0.94, 1, 0.35)
                    visible: !cardRoot.isSuccess && cardRoot.buffer.length > 0 && !cardRoot.isAuthenticating
                }

                Item {
                    id: arrowContainer
                    anchors.centerIn: parent
                    width: arrowText.implicitWidth
                    height: arrowText.implicitHeight

                    Text {
                        id: arrowText
                        anchors.centerIn: parent
                        text: cardRoot.isSuccess ? "check" : (cardRoot.isAuthenticating ? "progress_activity" : "arrow_forward")
                        font.family: Theme.fontIcon
                        font.pixelSize: 16
                        font.bold: true
                        color: cardRoot.isSuccess ? "#0d1013" : ((cardRoot.buffer.length > 0 && !cardRoot.isAuthenticating) ? "#121216" : Qt.rgba(1, 1, 1, 0.4))
                        scale: cardRoot.isSuccess ? 1.1 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: 300; easing.type: Easing.OutBack }
                        }
                    }
                }

                MouseArea {
                    id: submitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !cardRoot.isSuccess && !cardRoot.isAuthenticating
                    onClicked: {
                        cardRoot.submitPassword()
                        cardRoot.forceActiveFocus()
                    }
                }
            }
        }
    }
}
