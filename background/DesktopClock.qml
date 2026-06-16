pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    required property Item wallpaper
    required property real absX
    required property real absY

    property real scale: Config.background.desktopClock.scale
    property bool allowWallpaperBlur: true

    readonly property bool bgEnabled: Config.background.desktopClock.background.enabled
    readonly property bool blurEnabled: allowWallpaperBlur
        && bgEnabled
        && Config.background.desktopClock.background.blur
        && !GameMode.enabled

    readonly property bool invertColors: Config.background.desktopClock.invertColors

    /*
        REAL wallpaper-driven soft pastel clock

        Important:
        The wallpaper palette is the main color now.
        The dark/pastel colors only soften it.
    */

    // Wallpaper palette colors
    readonly property color primary: Colours.palette.m3primary
    readonly property color secondary: Colours.palette.m3secondary
    readonly property color tertiary: Colours.palette.m3tertiary

    readonly property color primaryContainer: Colours.palette.m3primaryContainer
    readonly property color secondaryContainer: Colours.palette.m3secondaryContainer
    readonly property color tertiaryContainer: Colours.palette.m3tertiaryContainer

    readonly property color onSurface: Colours.palette.m3onSurface
    readonly property color onSurfaceVariant: Colours.palette.m3onSurfaceVariant
    readonly property color surface: Colours.palette.m3surface

    /*
        Small helper.
        mix(a, b, 0.0) = a
        mix(a, b, 1.0) = b
    */
    function mix(a, b, amount) {
        return Qt.rgba(
            a.r + (b.r - a.r) * amount,
            a.g + (b.g - a.g) * amount,
            a.b + (b.b - a.b) * amount,
            a.a + (b.a - a.a) * amount
        );
    }

    /*
        Matte anchors.
        These do NOT decide the clock color.
        They only make the wallpaper colors softer/darker.
    */
    readonly property color darkPastelInk: Qt.rgba(0.24, 0.22, 0.25, 1.0)
    readonly property color softPastelInk: Qt.rgba(0.42, 0.39, 0.43, 1.0)
    readonly property color lightPastelInk: Qt.rgba(0.78, 0.74, 0.80, 1.0)

    /*
        Final colors.

        These are mostly wallpaper color.
        Then they are blended slightly toward matte pastel tones.
        This means red wallpaper becomes red-ish, blue becomes blue-ish,
        monochrome becomes gray-ish, as it should. Miracles, but with math.
    */

    readonly property color hourColor: invertColors
        ? mix(primaryContainer, lightPastelInk, 0.20)
        : mix(primary, darkPastelInk, 0.34)

    readonly property color minuteColor: invertColors
        ? mix(secondaryContainer, lightPastelInk, 0.20)
        : mix(secondary, darkPastelInk, 0.32)

    readonly property color colonColor: invertColors
        ? mix(tertiaryContainer, lightPastelInk, 0.28)
        : mix(tertiary, softPastelInk, 0.42)

    readonly property color ampmColor: invertColors
        ? mix(primaryContainer, lightPastelInk, 0.32)
        : mix(primary, onSurfaceVariant, 0.42)

    readonly property color monthColor: invertColors
        ? mix(secondaryContainer, lightPastelInk, 0.32)
        : mix(secondary, onSurfaceVariant, 0.40)

    readonly property color dayColor: invertColors
        ? mix(primaryContainer, lightPastelInk, 0.28)
        : mix(primary, onSurface, 0.36)

    readonly property color weekdayColor: invertColors
        ? mix(tertiaryContainer, lightPastelInk, 0.6)
        : mix(tertiary, onSurfaceVariant, 0.70)

    readonly property color dividerColor: invertColors
        ? mix(primaryContainer, lightPastelInk, 0.25)
        : mix(primary, darkPastelInk, 0.24)

    readonly property color plateColor: mix(surface, primary, 0.08)

    implicitWidth: layout.implicitWidth + (Appearance.padding.large * 4 * root.scale)
    implicitHeight: layout.implicitHeight + (Appearance.padding.large * 2 * root.scale)

    Item {
        id: clockContainer

        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.68)
            shadowOpacity: Math.max(Config.background.desktopClock.shadow.opacity, 0.38)
            shadowBlur: Math.max(Config.background.desktopClock.shadow.blur, 0.75)
        }

        Loader {
            anchors.fill: parent
            active: root.blurEnabled

            sourceComponent: MultiEffect {
                source: ShaderEffectSource {
                    sourceItem: root.wallpaper
                    sourceRect: Qt.rect(root.absX, root.absY, root.width, root.height)
                }

                maskSource: backgroundPlate
                maskEnabled: true
                blurEnabled: true
                blur: 0.7
                blurMax: 48
                autoPaddingEnabled: false
            }
        }

        StyledRect {
            id: backgroundPlate

            visible: root.bgEnabled
            anchors.fill: parent
            radius: Appearance.rounding.large * root.scale
            opacity: Math.min(Config.background.desktopClock.background.opacity, 0.10)
            color: root.plateColor

            layer.enabled: root.blurEnabled
        }

        RowLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Appearance.spacing.larger * root.scale

            RowLayout {
                spacing: Appearance.spacing.small

                StyledText {
                    text: Time.hourStr
                    font.pointSize: Appearance.font.size.extraLarge * 3 * root.scale
                    font.weight: Font.Bold
                    color: root.hourColor
                    opacity: 1.0
                }

                StyledText {
                    text: ":"
                    font.pointSize: Appearance.font.size.extraLarge * 3 * root.scale
                    color: root.colonColor
                    opacity: 0.92
                    Layout.topMargin: -Appearance.padding.large * 1.5 * root.scale
                }

                StyledText {
                    text: Time.minuteStr
                    font.pointSize: Appearance.font.size.extraLarge * 3 * root.scale
                    font.weight: Font.Bold
                    color: root.minuteColor
                    opacity: 1.0
                }

                Loader {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Appearance.padding.large * 1.4 * root.scale

                    active: Config.services.useTwelveHourClock
                    visible: active

                    sourceComponent: StyledText {
                        text: Time.amPmStr
                        font.pointSize: Appearance.font.size.large * root.scale
                        font.weight: Font.DemiBold
                        color: root.ampmColor
                        opacity: 0.98
                    }
                }
            }

            StyledRect {
                Layout.fillHeight: true
                Layout.preferredWidth: 4 * root.scale
                Layout.topMargin: Appearance.spacing.larger * root.scale
                Layout.bottomMargin: Appearance.spacing.larger * root.scale
                radius: Appearance.rounding.full
                color: root.dividerColor
                opacity: 0.95
            }

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: Time.format("MMMM").toUpperCase()
                    font.pointSize: Appearance.font.size.large * root.scale
                    font.letterSpacing: 4
                    font.weight: Font.Bold
                    color: root.monthColor
                    opacity: 0.98
                }

                StyledText {
                    text: Time.format("dd")
                    font.pointSize: Appearance.font.size.extraLarge * root.scale
                    font.letterSpacing: 2
                    font.weight: Font.DemiBold
                    color: root.dayColor
                    opacity: 1.0
                }

                StyledText {
                    text: Time.format("dddd")
                    font.pointSize: Appearance.font.size.larger * root.scale
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                    color: root.weekdayColor
                    opacity: 1.0
                }
            }
        }
    }

    Behavior on scale {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    Behavior on implicitWidth {
        Anim {
            duration: Appearance.anim.durations.small
        }
    }
}