import qs.components.effects
import qs.services
import qs.config
import qs.utils
import QtQuick
import qs.components

Item {
    id: root

    property var visibilities: Visibilities.getForActive()
    readonly property bool launcherOpen: visibilities?.launcher ?? false

    implicitWidth: Math.max(Config.bar.sizes.innerWidth, Appearance.font.size.large * 1.8)
    implicitHeight: Math.max(Config.bar.sizes.innerWidth, Appearance.font.size.large * 1.8)
    scale: launcherOpen ? 1.04 : stateLayer.containsMouse ? 1.025 : 1
    transformOrigin: Item.Center

    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    StateLayer {
        id: stateLayer

        anchors.fill: parent
        radius: Appearance.rounding.full
        color: root.launcherOpen ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3primary

        function onClicked(): void {
            root.visibilities.launcher = !root.visibilities.launcher;
        }
    }

    Loader {
        anchors.centerIn: parent
        sourceComponent: SysInfo.isDefaultLogo ? caelestiaLogo : distroIcon
    }

    Component {
        id: caelestiaLogo

        Logo {
            implicitWidth: Appearance.font.size.large * 1.8
            implicitHeight: Appearance.font.size.large * 1.8
            topColour: root.launcherOpen ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3primary
            bottomColour: root.launcherOpen ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3tertiary
        }
    }

    Component {
        id: distroIcon

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: Appearance.font.size.large * 1.2
            colour: root.launcherOpen ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3primary
        }
    }
}
