pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Caelestia.Config
import qs.config
import qs.components
import qs.services
import qs.modules.controlcenter
import qs.modules.windowinfo

Item {
    id: root

    required property ShellScreen screen

    // Compatibility if something still passes it.
    property real offsetScale: hasCurrent ? 0 : 1
    property real borderThickness: Config.border.thickness

    readonly property alias content: content
    readonly property alias winfo: winfo
    readonly property alias controlCenter: controlCenter

    readonly property real nonAnimWidth: children.find(c => c.shouldBeActive)?.implicitWidth ?? content.implicitWidth
    readonly property real nonAnimHeight: children.find(c => c.shouldBeActive)?.implicitHeight ?? content.implicitHeight
    readonly property Item current: content.item?.current ?? null
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool isDetached: detachedMode.length > 0

    property alias currentName: popoutState.currentName
    property alias hasCurrent: popoutState.hasCurrent
    property real currentCenter

    property string detachedMode
    property string queuedMode

    readonly property QtObject dummy: QtObject {}
    property int animLength: Appearance.anim.durations.normal
    property list<real> animCurve: Appearance.anim.curves.emphasized

    function detach(mode: string): void {
        animLength = Appearance.anim.durations.large;
        currentName = "";

        if (mode === "winfo") {
            hasCurrent = true;
            detachedMode = mode;
        } else {
            close();
            WindowFactory.create(null, {
                active: mode
            });
            return;
        }

        focus = true;
    }

    function close(): void {
        hasCurrent = false;
        detachedMode = "";
        queuedMode = "";
    }

    PopoutState {
        id: popoutState

        onDetachRequested: mode => root.detach(mode)
    }

    visible: hasCurrent && width > 0 && height > 0
    clip: false

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight
    width: implicitWidth
    height: implicitHeight

    // TOPBAR geometry:
    // currentCenter is X from TopBar.qml, so use it for x.
    x: Math.max(
        Config.border.rounding,
        Math.min((screen?.width ?? root.parent?.width ?? width) - width - Config.border.rounding, currentCenter - width / 2)
    )
    y: Config.border.thickness + Appearance.padding.normal
    z: 9999

    focus: hasCurrent

    HoverHandler {
        id: hoverHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    Keys.onEscapePressed: {
        if (currentName === "wirelesspassword" && content.item) {
            const passwordPopout = content.item.children.find(c => c.name === "wirelesspassword");
            if (passwordPopout && passwordPopout.item) {
                passwordPopout.item.closeDialog();
                return;
            }
        }

        close();
    }

    Keys.onPressed: event => {
        if (currentName === "wirelesspassword")
            event.accepted = false;
    }

    HyprlandFocusGrab {
        active: root.isDetached
        windows: [QsWindow.window]
        onCleared: root.close()
    }

    ConnectedSurface {
        anchors.fill: parent
        visible: root.hasCurrent
        surfaceColor: Colours.tPalette.m3surface
        radius: root.isDetached ? Appearance.rounding.large : Appearance.rounding.normal
        outlineOpacity: 0.24
        accentOpacity: root.isDetached ? 0.08 : 0.06
        glossOpacity: 0.08
    }

    Binding {
        when: root.isDetached || (root.hasCurrent && root.currentName === "wirelesspassword")

        target: QsWindow.window
        property: "WlrLayershell.keyboardFocus"
        value: WlrKeyboardFocus.OnDemand
    }

    Comp {
        id: content

        shouldBeActive: root.hasCurrent && !root.detachedMode
        anchors.fill: parent

        sourceComponent: Content {
            popouts: popoutState
        }
    }

    Comp {
        id: winfo
        shouldBeActive: root.detachedMode === "winfo"
        anchors.centerIn: parent

        sourceComponent: WindowInfo {
            screen: root.screen
            client: Hypr.activeToplevel
        }
    }

    Comp {
        id: controlCenter
        shouldBeActive: root.detachedMode === "any"
        anchors.centerIn: parent

        sourceComponent: ControlCenter {
            screen: root.screen
            active: root.queuedMode
        }
    }

    Behavior on y {
        enabled: root.implicitWidth > 0

        Anim {
            duration: root.animLength
            easing.bezierCurve: root.animCurve
        }
    }

    Behavior on implicitWidth {
        Anim {
            duration: root.animLength
            easing.bezierCurve: root.animCurve
        }
    }

    Behavior on implicitHeight {
        enabled: root.implicitWidth > 0

        Anim {
            duration: root.animLength
            easing.bezierCurve: root.animCurve
        }
    }

    component Comp: Loader {
        id: comp

        property bool shouldBeActive

        active: false
        opacity: 0

        states: State {
            name: "active"
            when: comp.shouldBeActive

            PropertyChanges {
                comp.opacity: 1
                comp.active: true
            }

            PropertyChanges {
                comp.active: true
            }
        }

        transitions: [
            Transition {
                from: ""
                to: "active"

                SequentialAnimation {
                    PropertyAction {
                        property: "active"
                    }

                    Anim {
                        property: "opacity"
                    }
                }
            },
            Transition {
                from: "active"
                to: ""

                SequentialAnimation {
                    Anim {
                        property: "opacity"
                    }

                    PropertyAction {
                        property: "active"
                    }
                }
            }
        ]
    }
}
