import QtQuick
import QtQuick.Shapes

// A mask item painting a rectangle with square top corners and rounded bottom corners.
// Use as the maskSource of an OpacityMask / MultiEffect (layer effect) to clip a surface.
Shape {
    id: root
    property real radius: 20
    readonly property real effectiveRadius: Math.max(0, Math.min(root.radius, root.height, root.width / 2))
    antialiasing: true
    preferredRendererType: Shape.GeometryRenderer

    ShapePath {
        fillColor: "#ffffff"
        strokeColor: "transparent"
        strokeWidth: 0
        startX: 0
        startY: 0

        // top-left -> top-right (straight, square corners flush against bezel)
        PathLine { x: root.width; y: 0 }
        // right side down to just above bottom-right corner
        PathLine { x: root.width; y: Math.max(0, root.height - root.effectiveRadius) }
        // bottom-right rounded corner
        PathArc {
            x: Math.max(0, root.width - root.effectiveRadius); y: root.height
            radiusX: root.effectiveRadius; radiusY: root.effectiveRadius
        }
        // bottom edge to bottom-left corner
        PathLine { x: root.effectiveRadius; y: root.height }
        // bottom-left rounded corner
        PathArc {
            x: 0; y: Math.max(0, root.height - root.effectiveRadius)
            radiusX: root.effectiveRadius; radiusY: root.effectiveRadius
        }
        // left side back up to top
        PathLine { x: 0; y: 0 }
    }
}
