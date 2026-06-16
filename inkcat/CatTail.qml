pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Shape {
    id: root

    property color accent: "#cba6f7"
    property string mood: "ink"
    property bool musicPlaying
    property bool sleeping
    property bool petting
    property bool pulled
    property bool chewing
    property bool transforming
    property real phase

    anchors.fill: parent
    asynchronous: true
    preferredRendererType: Shape.CurveRenderer

    readonly property real tug: pulled ? 1 : 0
    readonly property real moodLift: mood === "ember" ? 4 : mood === "frost" ? -2 : mood === "spirit" ? 3 : mood === "void" ? 5 : 0
    readonly property real sway: Math.sin(phase) * (pulled ? 1.2 : petting ? 8 : musicPlaying ? 5 : chewing ? 2.2 : sleeping ? 0.7 : 2)
    readonly property real baseX: 154
    readonly property real baseY: 100
    readonly property real tipX: 188 + tug * 18 + sway * 0.18
    readonly property real tipY: 50 + moodLift * 0.45 + tug * 3 + sway * 0.28
    readonly property real c1X: 168 + tug * 3
    readonly property real c1Y: 100
    readonly property real c2X: 198 + tug * 12
    readonly property real c2Y: 73 + moodLift * 0.35 + sway * 0.12
    readonly property real glowOpacity: transforming ? 0.06 : pulled ? 0.36 : musicPlaying ? 0.24 : petting ? 0.28 : 0.16

    ShapePath {
        strokeColor: Qt.rgba(0, 0, 0, 0.8)
        strokeWidth: pulled ? 12 : 15
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root.baseX
        startY: root.baseY

        PathCubic {
            x: root.tipX
            y: root.tipY
            control1X: root.c1X
            control1Y: root.c1Y
            control2X: root.c2X
            control2Y: root.c2Y
        }
    }

    ShapePath {
        strokeColor: Qt.alpha(root.accent, root.glowOpacity)
        strokeWidth: pulled ? 9 : musicPlaying || petting ? 8 : 6
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root.baseX
        startY: root.baseY

        PathCubic {
            x: root.tipX
            y: root.tipY
            control1X: root.c1X
            control1Y: root.c1Y
            control2X: root.c2X
            control2Y: root.c2Y
        }
    }

    ShapePath {
        strokeColor: root.transforming ? Qt.alpha(root.accent, 0.3) : root.accent
        strokeWidth: pulled ? 3.6 : 3
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root.baseX
        startY: root.baseY - 1

        PathCubic {
            x: root.tipX
            y: root.tipY
            control1X: root.c1X + 2
            control1Y: root.c1Y - 2
            control2X: root.c2X - 3
            control2Y: root.c2Y + 1
        }
    }
}
