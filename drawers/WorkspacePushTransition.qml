import qs.components
import qs.config
import qs.services
import Quickshell
import QtQuick

Item {
    id: root

    required property ShellScreen screen

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property int activeWorkspaceId: Config.bar.workspaces.perMonitorWorkspaces ? (monitor?.activeWorkspace?.id ?? Hypr.activeWsId) : Hypr.activeWsId

    property bool ready
    property bool active
    property int previousWorkspaceId: activeWorkspaceId
    property int direction: 1
    property int workspaceId: activeWorkspaceId
    property real progress: 1
    readonly property real easedProgress: 1 - Math.pow(1 - progress, 3)
    readonly property real pulse: Math.sin(progress * Math.PI)

    visible: active
    opacity: active ? 1 : 0
    clip: true

    function startTransition(fromId: int, toId: int): void {
        if (fromId === toId)
            return;

        direction = toId > fromId ? 1 : -1;
        workspaceId = toId;
        active = true;
        progress = 0;
        animation.restart();
    }

    Component.onCompleted: {
        previousWorkspaceId = activeWorkspaceId;
        ready = true;
    }

    onActiveWorkspaceIdChanged: {
        if (!ready) {
            previousWorkspaceId = activeWorkspaceId;
            return;
        }

        const fromId = previousWorkspaceId;
        previousWorkspaceId = activeWorkspaceId;
        startTransition(fromId, activeWorkspaceId);
    }

    NumberAnimation {
        id: animation

        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 330
        easing.type: Easing.InOutCubic

        onStopped: {
            root.progress = 1;
            root.active = false;
        }
    }

    Rectangle {
        id: incomingShade

        width: parent.width
        height: parent.height
        x: root.direction > 0 ? parent.width - root.easedProgress * parent.width : -parent.width + root.easedProgress * parent.width
        color: Qt.alpha(Colours.palette.m3surface, Colours.transparency.enabled ? 0.32 : 0.22)
        opacity: root.pulse * 0.74
    }

    Rectangle {
        width: parent.width
        height: parent.height
        x: root.direction > 0 ? -root.easedProgress * parent.width * 0.2 : root.easedProgress * parent.width * 0.2
        color: Qt.alpha(Colours.palette.m3shadow, 0.2)
        opacity: root.pulse * 0.42
    }

    Rectangle {
        width: 240
        height: parent.height
        x: (root.direction > 0 ? parent.width - root.easedProgress * parent.width : root.easedProgress * parent.width) - width / 2
        opacity: root.pulse * 0.48

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.alpha(Colours.palette.m3primary, 0.13) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
