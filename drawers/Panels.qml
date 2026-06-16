import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.config
import qs.services
import qs.modules.bar as Bar
import qs.modules.controlcenter as ControlCenter
import qs.modules.dashboard as Dashboard
import qs.modules.launcher as Launcher
import qs.modules.notifications as Notifications
import qs.modules.osd as Osd
import qs.modules.session as Session
import qs.modules.sidebar as Sidebar
import qs.modules.utilities as Utilities
import qs.modules.yin as Yin
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities.toasts as Toasts

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property var bar
    required property real borderThickness

    readonly property alias osd: osd
    readonly property alias osdWrapper: osdWrapper
    readonly property alias notifications: notifications
    readonly property alias session: session
    readonly property alias sessionWrapper: sessionWrapper
    readonly property alias launcher: launcher
    readonly property alias dashboard: dashboard
    readonly property alias controlCenter: controlCenter
    readonly property alias popouts: popoutsWrapper.content
    readonly property alias popoutsWrapper: popoutsWrapper
    readonly property alias utilities: utilities
    readonly property alias yin: yin
    readonly property alias toasts: toasts
    readonly property alias sidebar: sidebar
    property real sidehubDragProgress

    anchors.fill: parent

    ConnectedSurface {
        id: sidehubBackground
        z: 30

        readonly property bool active: root.visibilities.sidebar || root.visibilities.utilities
        readonly property bool trackingDrag: root.sidehubDragProgress > 0 && !active
        readonly property real revealProgress: Math.max(active ? 1 : 0, root.sidehubDragProgress)
        readonly property real targetWidth: Math.max(
            notifications.width || notifications.implicitWidth || 0,
            sidebar.width || sidebar.implicitWidth || 0,
            utilities.width || utilities.implicitWidth || 0
        )
        property real offsetScale: 1 - revealProgress

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: (-targetWidth - 5) * offsetScale
        width: targetWidth

        visible: false
        opacity: 0

        surfaceColor: Colours.tPalette.m3surface
        radius: Tokens.rounding.large
        outlineOpacity: 0.22
        accentOpacity: 0.07
        glossOpacity: 0.07

        Behavior on opacity {
            enabled: !sidehubBackground.trackingDrag
            Anim {
                duration: Appearance.anim.durations.large
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        }

        Behavior on offsetScale {
            enabled: !sidehubBackground.trackingDrag
            Anim {
                duration: Appearance.anim.durations.large
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        }
    }

    anchors.margins: borderThickness
    anchors.leftMargin: 0
    anchors.topMargin: Math.max(Config.border.thickness, (bar.contentHeight || bar.implicitHeight || 0) - Math.max(2, Config.border.thickness / 3))

    WorkspacePushTransition {
        id: workspaceTransition
        z: -20

        screen: root.screen

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Config.background.visualiser.enabled ? Math.max(56, Config.border.rounding * 2) : 0
    }

    Item {
        id: osdWrapper

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: sessionWrapper.anchors.rightMargin + session.width * (1 - session.offsetScale)
        clip: sidebar.visible || session.visible

        implicitWidth: osd.implicitWidth * (1 - osd.offsetScale)
        implicitHeight: osd.implicitHeight

        Osd.Wrapper {
            id: osd

            screen: root.screen
            visibilities: root.visibilities
            sidebarOrSessionVisible: sidebar.visible || session.visible

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Notifications.Wrapper {
        id: notifications
        z: 60

        visibilities: root.visibilities
        sidebarPanel: sidebar
        dragProgress: root.sidehubDragProgress
        osdPanel: osdWrapper
        sessionPanel: sessionWrapper

        anchors.top: parent.top
        anchors.right: parent.right
    }

    Item {
        id: sessionWrapper

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: sidebar.width * (1 - sidebar.offsetScale)
        clip: sidebar.visible

        implicitWidth: session.implicitWidth * (1 - session.offsetScale)
        implicitHeight: session.implicitHeight

        Session.Wrapper {
            id: session

            visibilities: root.visibilities
            sidebarVisible: sidebar.visible

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Launcher.Wrapper {
        id: launcher

        screen: root.screen
        visibilities: root.visibilities
        panels: root

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    Dashboard.Wrapper {
        id: dashboard

        visibilities: root.visibilities

        anchors.left: parent.left
        anchors.top: parent.top
    }

    ControlCenter.Wrapper {
        id: controlCenter
        z: 80

        screen: root.screen
        visibilities: root.visibilities

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    BarPopouts.ClipWrapper {
        id: popoutsWrapper
        z: 1000

        anchors.fill: parent

        screen: root.screen
        borderThickness: root.borderThickness
    }

    Utilities.Wrapper {
        id: utilities
        z: 70

        visibilities: root.visibilities
        sidebar: sidebar
        popouts: popoutsWrapper.content
        dragProgress: root.sidehubDragProgress

        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    Yin.Wrapper {
        id: yin
        z: 90

        visibilities: root.visibilities

        anchors.top: parent.top
        anchors.right: parent.right
    }

    Toasts.Toasts {
        id: toasts

        anchors.bottom: sidebar.visible ? parent.bottom : utilities.top
        anchors.right: (yin.visible && yin.width > 0) ? yin.left : sidebar.left
        anchors.margins: Tokens.padding.normal
    }

    Sidebar.Wrapper {
        id: sidebar
        z: 50

        visibilities: root.visibilities
        dragProgress: root.sidehubDragProgress

        anchors.top: notifications.visible ? notifications.bottom : parent.top
        anchors.bottom: utilities.visible ? utilities.top : parent.bottom
        anchors.right: parent.right
    }
}
