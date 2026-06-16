pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.config
import qs.services

Item {
    id: root

    required property DrawerVisibilities visibilities
    property real dragProgress
    readonly property Props props: Props {}

    readonly property bool shouldBeActive: visibilities.sidebar || visibilities.utilities
    readonly property bool trackingDrag: dragProgress > 0 && !shouldBeActive
    readonly property real revealProgress: Math.max(shouldBeActive ? 1 : 0, dragProgress)
    property real offsetScale: 1 - revealProgress

    visible: offsetScale < 1
    anchors.rightMargin: (-implicitWidth - 5) * offsetScale
    implicitWidth: Tokens.sizes.sidebar.width
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        enabled: !root.trackingDrag

        Anim {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    ConnectedSurface {
        anchors.fill: parent
        surfaceColor: Colours.tPalette.m3surface
        radius: Tokens.rounding.large
        outlineOpacity: 0.22
        accentOpacity: 0.07
        glossOpacity: 0.07
        z: -1
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: Tokens.padding.large

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            implicitWidth: Tokens.sizes.sidebar.width - Tokens.padding.large * 2
            props: root.props
            visibilities: root.visibilities
        }
    }
}
