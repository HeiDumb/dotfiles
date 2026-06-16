pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Caelestia.Services
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property ShellScreen screen
    required property Item wallpaper

    readonly property bool shouldBeActive: Config.background.visualiser.enabled
        && !Config.background.bottomWaves.enabled
        && !GameMode.enabled
        && (!Config.background.visualiser.autoHide || Audio.playbackStreams.length > 0)
    readonly property real colourOpacity: Colours.transparency.enabled ? Math.max(0.42, Colours.transparency.base * 0.78) : 0.72
    readonly property color barTopColour: Qt.alpha(Colours.palette.m3primary, colourOpacity)
    readonly property color barBottomColour: Qt.alpha(Colours.palette.m3inversePrimary, colourOpacity * 0.92)
    readonly property color barTrackColour: Qt.alpha(Colours.palette.m3surfaceContainerHigh, colourOpacity * 0.2)
    property real offset: shouldBeActive ? 0 : screen.height * 0.2

    opacity: shouldBeActive ? 1 : 0

    function cavaValue(index: int): real {
        const values = Audio.cava.values ?? [];
        return Math.max(0, Math.min(1, values[index] ?? 0));
    }

    Loader {
        anchors.fill: parent
        active: root.opacity > 0 && Config.background.visualiser.blur

        sourceComponent: MultiEffect {
            source: root.wallpaper
            maskSource: wrapper
            maskEnabled: true
            blurEnabled: true
            blur: 1
            blurMax: 32
            autoPaddingEnabled: false
        }
    }

    Item {
        id: wrapper

        anchors.fill: parent
        layer.enabled: true

        Loader {
            anchors.fill: parent
            anchors.topMargin: root.offset
            anchors.bottomMargin: -root.offset

            active: root.opacity > 0

            sourceComponent: Item {
                ServiceRef {
                    service: Audio.cava
                }

                Item {
                    id: content

                    anchors.fill: parent
                    anchors.margins: Config.border.thickness
                    anchors.leftMargin: Visibilities.bars.get(root.screen).exclusiveZone + Appearance.spacing.small * Config.background.visualiser.spacing

                    Side {
                        content: content
                    }
                    Side {
                        content: content
                        isRight: true
                    }

                    Behavior on anchors.leftMargin {
                        Anim {}
                    }
                }
            }
        }
    }

    Behavior on offset {
        Anim {}
    }

    Behavior on opacity {
        Anim {}
    }

    component Side: Repeater {
        id: side

        required property Item content
        property bool isRight

        model: Config.services.visualiserBars

        ClippingRectangle {
            id: bar

            required property int modelData
            readonly property int sampleIndex: side.isRight ? modelData : side.count - modelData - 1
            readonly property real rawValue: root.cavaValue(sampleIndex)
            readonly property real blendedValue: rawValue * 0.64
                + root.cavaValue(sampleIndex - 1) * 0.18
                + root.cavaValue(sampleIndex + 1) * 0.18
            property real value: Math.max(0, Math.min(1, Math.pow(blendedValue, 0.78) * 1.04))

            clip: true
            opacity: 0.42 + bar.value * 0.58

            x: modelData * ((side.content.width * 0.4) / Config.services.visualiserBars) + (side.isRight ? side.content.width * 0.6 : 0)
            implicitWidth: Math.max(2, (side.content.width * 0.4) / Config.services.visualiserBars - Appearance.spacing.small * Config.background.visualiser.spacing)

            y: side.content.height - height
            implicitHeight: Math.max(2, bar.value * side.content.height * 0.4)

            color: root.barTrackColour
            topLeftRadius: Appearance.rounding.small * Config.background.visualiser.rounding
            topRightRadius: Appearance.rounding.small * Config.background.visualiser.rounding
            bottomLeftRadius: topLeftRadius
            bottomRightRadius: topRightRadius

            Rectangle {
                topLeftRadius: parent.topLeftRadius
                topRightRadius: parent.topRightRadius
                bottomLeftRadius: parent.bottomLeftRadius
                bottomRightRadius: parent.bottomRightRadius

                gradient: Gradient {
                    orientation: Gradient.Vertical

                    GradientStop {
                        position: 0
                        color: root.barTopColour

                        Behavior on color {
                            CAnim {}
                        }
                    }
                    GradientStop {
                        position: 1
                        color: root.barBottomColour

                        Behavior on color {
                            CAnim {}
                        }
                    }
                }

                anchors.left: parent.left
                anchors.right: parent.right
                y: parent.height - height
                implicitHeight: side.content.height * 0.4
            }

            Behavior on value {
                Anim {
                    duration: Appearance.anim.durations.normal
                    easing.bezierCurve: Appearance.anim.curves.expressiveEffects
                }
            }

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.small
                }
            }
        }
    }
}
