pragma ComponentBehavior: Bound

import qs.components
import qs.config
import qs.services
import "popouts" as BarPopouts
import Quickshell
import QtQuick

Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property BarPopouts.Wrapper popouts
    required property bool disabled
    property var osd: null

    readonly property int padding: Math.max(Appearance.padding.smaller, Config.border.thickness)
    readonly property int contentHeight: Math.max(46, Config.bar.sizes.innerWidth + padding)
    readonly property bool hasFullscreen: Hypr.workspaceHasFullscreen(Hypr.monitorFor(screen)?.activeWorkspace?.id ?? -1)
    readonly property int exclusiveZone: !disabled && !hasFullscreen && (Config.bar.persistent || visibilities.bar || isHovered) ? contentHeight : Config.border.thickness
    readonly property bool shouldBeVisible: !disabled && !hasFullscreen && (Config.bar.persistent || visibilities.bar || isHovered)

    property bool isHovered

    function closeTray(): void {
        content.item?.closeTray();
    }

    function checkPopout(x: real): void {
        content.item?.checkPopout(x);
    }

    function handleWheel(x: real, angleDelta: point): void {
        content.item?.handleWheel(x, angleDelta);
    }

    visible: height > Config.border.thickness
    implicitHeight: Config.border.thickness
    implicitWidth: screen.width
    width: parent ? parent.width : screen.width

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.implicitHeight: root.contentHeight
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "implicitHeight"
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "implicitHeight"
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    ]

    Loader {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        active: root.shouldBeVisible || root.visible

        sourceComponent: TopBar {
            width: root.width
            height: root.contentHeight
            screen: root.screen
            visibilities: root.visibilities
            popouts: root.popouts
            osd: root.osd
        }
    }
}
