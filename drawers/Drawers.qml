pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.services
import qs.config
import qs.utils
import qs.modules.bar
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects

Variants {
    model: Quickshell.screens

    Scope {
        id: scope

        required property ShellScreen modelData
        readonly property bool barDisabled: Strings.testRegexList(Config.bar.excludedScreens, modelData.name)

        Exclusions {
            screen: scope.modelData
            bar: bar
        }

        StyledWindow {
            id: win

            readonly property bool hasFullscreen: Hypr.workspaceHasFullscreen(Hypr.monitorFor(screen)?.activeWorkspace?.id ?? -1)
            readonly property real panelTopMargin: Math.max(Config.border.thickness, (bar.contentHeight || bar.implicitHeight || 0) - Math.max(2, Config.border.thickness / 3))
            readonly property int dragMaskPadding: 0

            onHasFullscreenChanged: {
                drawerVisibilities.launcher = false;
                drawerVisibilities.session = false;
                drawerVisibilities.dashboard = false;
                drawerVisibilities.controlCenter = false;
                drawerVisibilities.sidebar = false;
                drawerVisibilities.utilities = false;
                drawerVisibilities.yin = false;
            }

            screen: scope.modelData
            name: "drawers"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: drawerVisibilities.launcher || drawerVisibilities.session || drawerVisibilities.controlCenter || drawerVisibilities.yin || (!Config.dashboard.showOnHover && drawerVisibilities.dashboard && Config.dashboard.enabled) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            mask: Regions {
                bar: bar
                panels: panels
                visibilities: drawerVisibilities
                win: win
            }

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            HyprlandFocusGrab {
                active: drawerVisibilities.launcher || drawerVisibilities.session || drawerVisibilities.controlCenter || (!Config.dashboard.showOnHover && drawerVisibilities.dashboard && Config.dashboard.enabled)
                windows: [win]

                onCleared: {
                    drawerVisibilities.launcher = false;
                    drawerVisibilities.session = false;
                    drawerVisibilities.controlCenter = false;
                    drawerVisibilities.dashboard = false;
                    drawerVisibilities.yin = false;
                }
            }

            StyledRect {
                anchors.fill: parent
                opacity: drawerVisibilities.session && Config.session.enabled ? 0.5 : 0
                color: Colours.palette.m3scrim

                Behavior on opacity {
                    Anim {}
                }
            }

            DrawerVisibilities {
                id: drawerVisibilities

                property bool weebcentral

                Component.onCompleted: {
                    Visibilities.load(scope.modelData, this);
                    drawerVisibilities.bar = true;
                }
            }

            FileView {
                path: `${Quickshell.env("HOME")}/.local/state/weebcentral-panel/visible`
                watchChanges: true
                onFileChanged: reload()
                onLoaded: drawerVisibilities.weebcentral = text().trim() === "1"
                onLoadFailed: drawerVisibilities.weebcentral = false
            }

            Interactions {
                id: interactions

                screen: scope.modelData
                popouts: panels.popouts
                visibilities: drawerVisibilities
                panels: panels
                bar: bar
                borderThickness: Config.border.thickness
                fullscreen: win.hasFullscreen

                Panels {
                    id: panels
                    z: 10

                    screen: scope.modelData
                    visibilities: drawerVisibilities
                    bar: bar
                    borderThickness: Config.border.thickness
                }

                TopBarWrapper {
                    id: bar
                    z: 20

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top

                    screen: scope.modelData
                    visibilities: drawerVisibilities
                    popouts: panels.popouts
                    osd: panels.osd
                    disabled: scope.barDisabled

                    Component.onCompleted: Visibilities.bars.set(scope.modelData, this)
                }
            }
        }
    }
}
