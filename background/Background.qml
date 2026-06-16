pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.services
import qs.config
import Quickshell
import Quickshell.Wayland
import QtQuick

Loader {
    active: Config.background.enabled

    sourceComponent: Variants {
        model: Quickshell.screens

        Scope {
            id: scope

            required property ShellScreen modelData

        StyledWindow {
            id: win

            readonly property bool useWallpaperEngine: WallpaperEngine.wantsRunning

            screen: scope.modelData
            name: "background"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: Config.background.wallpaperEnabled && !useWallpaperEngine ? WlrLayer.Background : WlrLayer.Bottom
            color: Config.background.wallpaperEnabled && !useWallpaperEngine ? "black" : "transparent"
            surfaceFormat.opaque: false

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Item {
                id: behindClock

                anchors.fill: parent

                Loader {
                    id: wallpaper

                    z: 0
                    anchors.fill: parent
                    active: Config.background.wallpaperEnabled && !win.useWallpaperEngine

                    sourceComponent: Wallpaper {}
                }

                Visualiser {
                    anchors.fill: parent
                    screen: scope.modelData
                    wallpaper: wallpaper
                    visible: Config.background.visualiser.enabled && !GameMode.enabled
                }

            }

            Loader {
                id: clockLoader
                active: Config.background.desktopClock.enabled && !win.useWallpaperEngine

                anchors.margins: Appearance.padding.large * 2
                anchors.leftMargin: Appearance.padding.large * 2 + Config.bar.sizes.innerWidth + Math.max(Appearance.padding.smaller, Config.border.thickness)

                state: Config.background.desktopClock.position
                states: [
                    State {
                        name: "top-left"
                        AnchorChanges {
                            target: clockLoader
                            anchors.top: parent.top
                            anchors.left: parent.left
                        }
                    },
                    State {
                        name: "top-center"
                        AnchorChanges {
                            target: clockLoader
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    },
                    State {
                        name: "top-right"
                        AnchorChanges {
                            target: clockLoader
                            anchors.top: parent.top
                            anchors.right: parent.right
                        }
                    },
                    State {
                        name: "middle-left"
                        AnchorChanges {
                            target: clockLoader
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                        }
                    },
                    State {
                        name: "middle-center"
                        AnchorChanges {
                            target: clockLoader
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    },
                    State {
                        name: "middle-right"
                        AnchorChanges {
                            target: clockLoader
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                        }
                    },
                    State {
                        name: "bottom-left"
                        AnchorChanges {
                            target: clockLoader
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                        }
                    },
                    State {
                        name: "bottom-center"
                        AnchorChanges {
                            target: clockLoader
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    },
                    State {
                        name: "bottom-right"
                        AnchorChanges {
                            target: clockLoader
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                        }
                    }
                ]

                transitions: Transition {
                    AnchorAnimation {
                        duration: Appearance.anim.durations.expressiveDefaultSpatial
                        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                    }
                }

                sourceComponent: DesktopClock {
                    wallpaper: behindClock
                    absX: clockLoader.x
                    absY: clockLoader.y
                }
            }
        }

        StyledWindow {
            id: wavesWin

            visible: Config.background.bottomWaves.enabled && !GameMode.enabled
            screen: scope.modelData
            name: "background-waves"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            color: "transparent"
            surfaceFormat.opaque: false
            mask: Region {}

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            BottomWaves {}
        }

        StyledWindow {
            id: matrixWin

            visible: Config.background.enabled && !GameMode.enabled
            screen: scope.modelData
            name: "background-matrix-strip"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            color: "transparent"
            surfaceFormat.opaque: false
            mask: Region {}
            implicitWidth: Math.min(scope.modelData.width * 0.1, 180)
            implicitHeight: Math.min(scope.modelData.height * 0.46, 480)

            anchors.top: true
            anchors.left: true

            MatrixStrip {
                anchors.fill: parent
            }
        }

        StyledWindow {
            id: clockWin

            readonly property bool useWallpaperEngine: WallpaperEngine.wantsRunning

            visible: Config.background.desktopClock.enabled && useWallpaperEngine
            screen: scope.modelData
            name: "background-clock"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            color: "transparent"
            surfaceFormat.opaque: false

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Item {
                id: clockBackdrop
                anchors.fill: parent
            }

            Loader {
                id: wallpaperClockLoader
                active: Config.background.desktopClock.enabled && clockWin.useWallpaperEngine

                anchors.margins: Appearance.padding.large * 2
                anchors.leftMargin: Appearance.padding.large * 2 + Config.bar.sizes.innerWidth + Math.max(Appearance.padding.smaller, Config.border.thickness)

                state: Config.background.desktopClock.position
                states: [
                    State {
                        name: "top-left"
                        AnchorChanges {
                            target: wallpaperClockLoader
                            anchors.top: parent.top
                            anchors.left: parent.left
                        }
                    },
                    State {
                        name: "top-center"
                        AnchorChanges {
                            target: wallpaperClockLoader
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    },
                    State {
                        name: "top-right"
                        AnchorChanges {
                            target: wallpaperClockLoader
                            anchors.top: parent.top
                            anchors.right: parent.right
                        }
                    },
                    State {
                        name: "middle-left"
                        AnchorChanges {
                            target: wallpaperClockLoader
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                        }
                    },
                    State {
                        name: "middle-center"
                        AnchorChanges {
                            target: wallpaperClockLoader
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    },
                    State {
                        name: "middle-right"
                        AnchorChanges {
                            target: wallpaperClockLoader
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                        }
                    },
                    State {
                        name: "bottom-left"
                        AnchorChanges {
                            target: wallpaperClockLoader
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                        }
                    },
                    State {
                        name: "bottom-center"
                        AnchorChanges {
                            target: wallpaperClockLoader
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    },
                    State {
                        name: "bottom-right"
                        AnchorChanges {
                            target: wallpaperClockLoader
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                        }
                    }
                ]

                transitions: Transition {
                    AnchorAnimation {
                        duration: Appearance.anim.durations.expressiveDefaultSpatial
                        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                    }
                }

                sourceComponent: DesktopClock {
                    wallpaper: clockBackdrop
                    absX: wallpaperClockLoader.x
                    absY: wallpaperClockLoader.y
                    allowWallpaperBlur: false
                }
            }
        }

        }
    }
}
