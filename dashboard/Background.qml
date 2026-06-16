import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes

ShapePath {
    id: root

    required property Wrapper wrapper

    readonly property real rounding: Config.border.rounding
    readonly property bool flatten: wrapper.height < rounding * 2
    readonly property real roundingY: flatten ? wrapper.height / 2 : rounding

    strokeWidth: -1
    fillColor: Colours.palette.m3surface

    // Top edge: start from attached/right side, go left
    PathLine {
        relativeX: -(root.wrapper.width - root.rounding)
        relativeY: 0
    }

    // Top-left rounded corner
    PathArc {
        relativeX: -root.rounding
        relativeY: root.roundingY
        radiusX: root.rounding
        radiusY: Math.min(root.rounding, root.wrapper.height)
        direction: PathArc.Counterclockwise
    }

    // Left side
    PathLine {
        relativeX: 0
        relativeY: root.wrapper.height - root.roundingY * 2
    }

    // Bottom-left rounded corner
    PathArc {
        relativeX: root.rounding
        relativeY: root.roundingY
        radiusX: root.rounding
        radiusY: Math.min(root.rounding, root.wrapper.height)
        direction: PathArc.Counterclockwise
    }

    // Bottom edge back to attached/right side
    PathLine {
        relativeX: root.wrapper.width - root.rounding
        relativeY: 0
    }

    Behavior on fillColor {
        CAnim {}
    }
}
