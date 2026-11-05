import QtQuick
import QtQuick.Shapes

/**
 * AuroraBackground — Inspired by Reactbits Aurora
 * Multi-chromatic atmospheric gradient mesh blending deep obsidian,
 * cyan/teal, electric violet, indigo, and rose tones.
 */
Item {
    id: root
    anchors.fill: parent

    // Base deep dark obsidian background
    Rectangle {
        anchors.fill: parent
        color: "#08080d"
    }

    // Layer 1: Electric Teal / Cyan Blob (Top Left / Center)
    Rectangle {
        id: cyanBlob
        x: -root.width * 0.15
        y: -root.height * 0.2
        width: root.width * 0.75
        height: root.height * 0.8
        radius: width * 0.5
        opacity: 0.24
        transformOrigin: Item.Center

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#06b6d4" } // cyan-500
            GradientStop { position: 0.5; color: "#0ea5e9" } // sky-500
            GradientStop { position: 1.0; color: "transparent" }
        }

        SequentialAnimation on x {
            loops: Animation.Infinite
            NumberAnimation { to: -root.width * 0.05; duration: 9200; easing.type: Easing.InOutSine }
            NumberAnimation { to: -root.width * 0.22; duration: 8400; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { to: -root.height * 0.10; duration: 8100; easing.type: Easing.InOutSine }
            NumberAnimation { to: -root.height * 0.28; duration: 9600; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on scale {
            loops: Animation.Infinite
            NumberAnimation { to: 1.14; duration: 7300; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.92; duration: 7900; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on rotation {
            loops: Animation.Infinite
            NumberAnimation { to: 12; duration: 11500; easing.type: Easing.InOutSine }
            NumberAnimation { to: -8; duration: 10800; easing.type: Easing.InOutSine }
        }
    }

    // Layer 2: Ethereal Violet / Indigo Blob (Top Right)
    Rectangle {
        id: violetBlob
        x: root.width * 0.35
        y: -root.height * 0.25
        width: root.width * 0.8
        height: root.height * 0.85
        radius: width * 0.5
        opacity: 0.28
        transformOrigin: Item.Center

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#7c3aed" } // violet-600
            GradientStop { position: 0.6; color: "#6366f1" } // indigo-500
            GradientStop { position: 1.0; color: "transparent" }
        }

        SequentialAnimation on x {
            loops: Animation.Infinite
            NumberAnimation { to: root.width * 0.45; duration: 11000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.width * 0.25; duration: 10200; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { to: -root.height * 0.12; duration: 9400; easing.type: Easing.InOutSine }
            NumberAnimation { to: -root.height * 0.32; duration: 10600; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on scale {
            loops: Animation.Infinite
            NumberAnimation { to: 0.90; duration: 8700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.18; duration: 9300; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on rotation {
            loops: Animation.Infinite
            NumberAnimation { to: -14; duration: 12200; easing.type: Easing.InOutSine }
            NumberAnimation { to: 10; duration: 13100; easing.type: Easing.InOutSine }
        }
    }

    // Layer 3: Neon Rose / Fuchsia Accent (Bottom Right)
    Rectangle {
        id: roseBlob
        x: root.width * 0.4
        y: root.height * 0.35
        width: root.width * 0.7
        height: root.height * 0.75
        radius: width * 0.5
        opacity: 0.18
        transformOrigin: Item.Center

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#e11d48" } // rose-600
            GradientStop { position: 0.6; color: "#d946ef" } // fuchsia-500
            GradientStop { position: 1.0; color: "transparent" }
        }

        SequentialAnimation on x {
            loops: Animation.Infinite
            NumberAnimation { to: root.width * 0.28; duration: 10500; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.width * 0.48; duration: 11800; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { to: root.height * 0.45; duration: 8900; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.25; duration: 9700; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on scale {
            loops: Animation.Infinite
            NumberAnimation { to: 1.12; duration: 8100; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.88; duration: 8600; easing.type: Easing.InOutSine }
        }
    }

    // Layer 4: Deep Cosmic Blue Fill (Bottom Left)
    Rectangle {
        id: blueBlob
        x: -root.width * 0.1
        y: root.height * 0.3
        width: root.width * 0.65
        height: root.height * 0.7
        radius: width * 0.5
        opacity: 0.20
        transformOrigin: Item.Center

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#2563eb" } // blue-600
            GradientStop { position: 0.7; color: "#0284c7" } // sky-600
            GradientStop { position: 1.0; color: "transparent" }
        }

        SequentialAnimation on x {
            loops: Animation.Infinite
            NumberAnimation { to: root.width * 0.02; duration: 9800; easing.type: Easing.InOutSine }
            NumberAnimation { to: -root.width * 0.18; duration: 10400; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { to: root.height * 0.20; duration: 11200; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.38; duration: 9100; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on scale {
            loops: Animation.Infinite
            NumberAnimation { to: 0.94; duration: 7700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.15; duration: 8500; easing.type: Easing.InOutSine }
        }
    }

    // Layer 5: Dark Vignette & Soft Tint Overlay for high contrast & legibility
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#4008080d" }
            GradientStop { position: 0.5; color: "#2008080d" }
            GradientStop { position: 1.0; color: "#8008080d" }
        }
    }

    // Layer 6: Subtle Edge Border
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: "#18ffffff"
        border.width: 1
    }
}
