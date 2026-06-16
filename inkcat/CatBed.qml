pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color accent: "#cba6f7"
    property bool occupied

    width: 204
    height: 52
    opacity: occupied ? 0.42 : 0.2

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 28
        radius: 8
        color: Qt.rgba(0, 0, 0, 0.34)
        border.color: Qt.alpha(root.accent, root.occupied ? 0.42 : 0.18)
        border.width: 1
    }

    Shape {
        anchors.fill: parent

        ShapePath {
            strokeColor: Qt.alpha(root.accent, root.occupied ? 0.55 : 0.22)
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 20
            startY: 37

            PathCubic {
                x: 184
                y: 37
                control1X: 62
                control1Y: 50
                control2X: 142
                control2Y: 22
            }
        }
    }
}
