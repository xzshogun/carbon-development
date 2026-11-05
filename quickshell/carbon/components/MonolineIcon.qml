import QtQuick
import QtQuick.Shapes
import "MonolinePaths.js" as MonolinePaths

Item {
    id: root

    property string name: ""
    property color strokeColor: "#ffffff"
    property real strokeWidth: 1.75
    property real size: 24

    width: size
    height: size

    readonly property string pathData: MonolinePaths.getPath(root.name)

    Shape {
        id: shape
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: root.width / 24.0
        preferredRendererType: Shape.CurveRenderer
        visible: root.pathData.length > 0

        ShapePath {
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: root.pathData
            }
        }
    }
}
