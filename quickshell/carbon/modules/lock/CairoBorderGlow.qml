import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../../Singletons"

/**
 * CairoBorderGlow.qml:
 * ReactBits Border Glow (https://reactbits.dev/components/border-glow)
 * Adapted for Cairo Standby / Lockscreen:
 * - Always visible on the screen border at all times (continuous perimeter sweep, zero hover dependency).
 * - Multi-tier chromatic mesh glow using Google Material 3 tokens (primary, secondary, tertiary).
 * - Intense white-hot travelling spotlight core + soft chromatic dispersion halo.
 * - Layered inward occluders ensuring smooth falloff and pure OLED #000000 stage center.
 * - Completely decoupled from lyrics (no beat blinks or flash triggers).
 */
Item {
    id: root
    anchors.fill: parent

    readonly property color primaryColor: Theme.m3primary || Theme.accent || "#a1c9fd"
    readonly property color secondaryColor: Theme.m3secondary || Theme.accentLit || Theme.accent || "#d7bde4"
    readonly property color tertiaryColor: Theme.m3tertiary || Theme.accent || "#bbc7db"

    // Continuous 8000ms perimeter traveling loop
    property real sweepProgress: 0.0
    NumberAnimation on sweepProgress {
        from: 0.0
        to: 1.0
        duration: 8000
        loops: Animation.Infinite
        easing.type: Easing.Linear
    }

    readonly property real m: 8
    readonly property real w: Math.max(100, root.width - 2 * m)
    readonly property real h: Math.max(100, root.height - 2 * m)
    readonly property real perimeter: 2 * (w + h)

    readonly property real spotX: {
        var d = root.sweepProgress * root.perimeter
        if (d <= w) return m + d
        if (d <= w + h) return m + w
        if (d <= 2 * w + h) return m + w - (d - (w + h))
        return m
    }

    readonly property real spotY: {
        var d = root.sweepProgress * root.perimeter
        if (d <= w) return m
        if (d <= w + h) return m + (d - w)
        if (d <= 2 * w + h) return m + h
        return m + h - (d - (2 * w + h))
    }

    // 1. Traveling ReactBits Mesh Glow Spotlights at (spotX, spotY)
    Item {
        x: root.spotX
        y: root.spotY
        width: 1
        height: 1

        // Broad outer chromatic mesh halo (500px wide)
        Shape {
            anchors.centerIn: parent
            width: 500
            height: 500
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: 250; centerY: 250; centerRadius: 250
                    focalX: 250; focalY: 250; focalRadius: 0
                    GradientStop { position: 0.00; color: Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.94) }
                    GradientStop { position: 0.22; color: Qt.rgba(root.secondaryColor.r, root.secondaryColor.g, root.secondaryColor.b, 0.70) }
                    GradientStop { position: 0.50; color: Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.35) }
                    GradientStop { position: 0.80; color: Qt.rgba(root.tertiaryColor.r, root.tertiaryColor.g, root.tertiaryColor.b, 0.10) }
                    GradientStop { position: 1.00; color: "transparent" }
                }
                startX: 0; startY: 0
                PathLine { x: 500; y: 0 }
                PathLine { x: 500; y: 500 }
                PathLine { x: 0; y: 500 }
                PathLine { x: 0; y: 0 }
            }
        }

        // Core intense white-hot beam (160px wide)
        Shape {
            anchors.centerIn: parent
            width: 160
            height: 160
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: 80; centerY: 80; centerRadius: 80
                    focalX: 80; focalY: 80; focalRadius: 0
                    GradientStop { position: 0.00; color: "#ffffff" }
                    GradientStop { position: 0.35; color: "#f5ffffff" }
                    GradientStop { position: 0.65; color: Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.75) }
                    GradientStop { position: 1.00; color: "transparent" }
                }
                startX: 0; startY: 0
                PathLine { x: 160; y: 0 }
                PathLine { x: 160; y: 160 }
                PathLine { x: 0; y: 160 }
                PathLine { x: 0; y: 0 }
            }
        }
    }

    // 2. Soft Inward Occluders: Blends the glow smoothly into the pure OLED black center
    // Outer falloff ring
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.m + 8
        radius: 14
        color: "transparent"
        border.width: 10
        border.color: "#000000"
        opacity: 0.45
    }

    // Middle falloff ring
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.m + 16
        radius: 12
        color: "transparent"
        border.width: 12
        border.color: "#000000"
        opacity: 0.80
    }

    // Inner solid black canvas
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.m + 26
        radius: 10
        color: "#000000"
    }

    // 3. Crisp Rounded Outer Border Stroke (Always clearly visible around the screen)
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.m
        radius: 16
        color: "transparent"
        border.width: 2.0
        border.color: root.primaryColor
        opacity: 0.65
    }

    // Ambient soft inner border
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.m + 1
        radius: 15
        color: "transparent"
        border.width: 4
        border.color: root.primaryColor
        opacity: 0.30
    }
}
