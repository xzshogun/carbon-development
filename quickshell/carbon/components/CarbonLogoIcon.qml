import QtQuick
import QtQuick.Shapes
import "../Singletons"

/**
 * CarbonLogoIcon:
 * Crisp, scalable vector brand mark icon for Carbon Shell.
 * Renders the clean luminous nucleus and dual-vortex spiral arms.
 */
Item {
    id: root

    implicitWidth: Theme.px(18)
    implicitHeight: Theme.px(18)

    property color color: Theme.accent
    property color twinColor: root.color
    property real twinOpacity: 0.45
    property bool spinning: false
    property real customRotation: 0

    Behavior on color { ColorAnimation { duration: 150 } }

    Item {
        id: container
        width: 200
        height: 200
        anchors.centerIn: parent
        scale: Math.min(root.width, root.height) / 116.0
        transformOrigin: Item.Center
        rotation: root.customRotation

        // 1. Soft Ambient Halo Disk
        Rectangle {
            anchors.centerIn: parent
            width: 64
            height: 64
            radius: 32
            color: root.color
            opacity: 0.15
            antialiasing: true
        }

        // 2. Central Nucleus Core
        Rectangle {
            anchors.centerIn: parent
            width: 44
            height: 44
            radius: 22
            color: root.color
            antialiasing: true
        }

        // 3. Spiral 2: Secondary Twin Swirl
        Shape {
            anchors.fill: parent
            antialiasing: true
            smooth: true
            preferredRendererType: Shape.CurveRenderer
            opacity: root.twinOpacity

            ShapePath {
                strokeColor: root.twinColor
                strokeWidth: 12
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: "M100.0 138.0 L98.1 138.2 L96.2 138.3 L94.2 138.3 L92.3 138.2 L90.3 138.0 L88.4 137.7 L86.4 137.3 L84.5 136.8 L82.6 136.2 L80.7 135.5 L78.8 134.7 L76.9 133.8 L75.1 132.8 L73.3 131.8 L71.6 130.6 L69.9 129.3 L68.3 128.0 L66.8 126.5 L65.3 125.0 L63.9 123.3 L62.5 121.6 L61.2 119.9 L60.0 118.0 L59.0 116.1 L57.9 114.1 L57.0 112.1 L56.2 110.0 L55.5 107.8 L54.9 105.6 L54.4 103.4 L54.0 101.1 L53.8 98.8 L53.6 96.5 L53.6 94.2 L53.7 91.8 L53.9 89.5 L54.2 87.1 L54.6 84.8 L55.2 82.4 L55.9 80.1 L56.7 77.8 L57.6 75.5 L58.6 73.3 L59.8 71.1 L61.1 69.0 L62.5 66.9 L64.0 64.8 L65.6 62.9 L67.3 61.0 L69.1 59.2 L71.0 57.5 L73.0 55.9 L75.1 54.3 L77.3 52.9 L79.6 51.6 L81.9 50.3 L84.3 49.2 L86.8 48.3 L89.4 47.4 L92.0 46.6 L94.6 46.0 L97.3 45.6 L100.0 45.2 L102.7 45.0 L105.5 44.9 L108.3 45.0 L111.1 45.2 L113.9 45.5 L116.6 46.0 L119.4 46.7"
                }
            }
        }

        // 4. Spiral 1: Primary Master Swirl
        Shape {
            anchors.fill: parent
            antialiasing: true
            smooth: true
            preferredRendererType: Shape.CurveRenderer
            opacity: 1.0

            ShapePath {
                strokeColor: root.color
                strokeWidth: 14
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: "M100.0 62.0 L101.9 61.8 L103.8 61.7 L105.8 61.7 L107.7 61.8 L109.7 62.0 L111.6 62.3 L113.6 62.7 L115.5 63.2 L117.4 63.8 L119.3 64.5 L121.2 65.3 L123.1 66.2 L124.9 67.2 L126.7 68.2 L128.4 69.4 L130.1 70.7 L131.7 72.0 L133.2 73.5 L134.7 75.0 L136.1 76.7 L137.5 78.4 L138.8 80.1 L140.0 82.0 L141.0 83.9 L142.1 85.9 L143.0 87.9 L143.8 90.0 L144.5 92.2 L145.1 94.4 L145.6 96.6 L146.0 98.9 L146.2 101.2 L146.4 103.5 L146.4 105.8 L146.3 108.2 L146.1 110.5 L145.8 112.9 L145.4 115.2 L144.8 117.6 L144.1 119.9 L143.3 122.2 L142.4 124.5 L141.4 126.7 L140.2 128.9 L138.9 131.0 L137.5 133.1 L136.0 135.2 L134.4 137.1 L132.7 139.0 L130.9 140.8 L129.0 142.5 L127.0 144.1 L124.9 145.7 L122.7 147.1 L120.4 148.4 L118.1 149.7 L115.7 150.8 L113.2 151.7 L110.6 152.6 L108.0 153.4 L105.4 154.0 L102.7 154.4 L100.0 154.8 L97.3 155.0 L94.5 155.1 L91.7 155.0 L88.9 154.8 L86.1 154.5 L83.4 154.0 L80.6 153.3"
                }
            }
        }
    }
}
