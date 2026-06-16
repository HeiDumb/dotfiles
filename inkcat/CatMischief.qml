pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color accent: "#cba6f7"
    property bool active
    property bool rightEdge
    property string mood: "ink"
    property real phase

    width: 34
    height: 30
    visible: active
    opacity: active ? 0.76 : 0

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.rightEdge ? -1 : 1
        yScale: 1
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Qt.rgba(0, 0, 0, 0.3)
            strokeColor: "transparent"
            startX: 1
            startY: 15

            PathCubic {
                x: 15
                y: 7 - Math.abs(Math.sin(root.phase * 5.2)) * 2
                control1X: 5
                control1Y: 16
                control2X: 9
                control2Y: 7
            }
            PathCubic {
                x: 32
                y: 13 + Math.sin(root.phase * 5.2) * 1.4
                control1X: 20
                control1Y: 5
                control2X: 29
                control2Y: 7
            }
            PathCubic {
                x: 22
                y: 25
                control1X: 33
                control1Y: 20
                control2X: 29
                control2Y: 27
            }
            PathCubic {
                x: 1
                y: 15
                control1X: 11
                control1Y: 26
                control2X: 3
                control2Y: 23
            }
        }
    }

    Repeater {
        model: 3

        Rectangle {
            required property int index

            x: 23 + index * 3
            y: 11 + Math.sin(root.phase * 5 + index) * 2 + index % 2 * 4
            width: 3.2
            height: 3.2
            radius: width / 2
            color: root.accent
            opacity: 0.48 + Math.abs(Math.sin(root.phase * 4.2 + index)) * 0.24
        }
    }
}
