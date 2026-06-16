pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components.effects
import qs.services
import qs.utils

MouseArea {
    id: root

    required property SystemTrayItem modelData
    required property int index
    property var bar: null
    property var popouts: null
    property var popoutHost: null

    QsMenuAnchor {
        id: trayNativeMenu

        menu: root.modelData.menu
        anchor.item: root
    }

    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    implicitWidth: Tokens.font.size.small * 2
    implicitHeight: Tokens.font.size.small * 2

    function effectivePopouts(): var {
        return root.popouts ?? root.bar?.popouts ?? null;
    }

    function effectiveHost(): var {
        return root.popoutHost ?? root.bar ?? null;
    }

    function openMenu(): void {
        if (!root.modelData.hasMenu || !root.modelData.menu) {
            root.modelData.activate();
            return;
        }

        const host = effectiveHost();
        if (host?.setPopout) {
            host.setPopout(`traymenu${root.index}`, root);
            return;
        }

        const popouts = effectivePopouts();
        if (popouts) {
            popouts.currentName = `traymenu${root.index}`;
            popouts.hasCurrent = true;
            return;
        }

        const pos = root.mapToItem(null, root.width / 2, root.height / 2);

        try {
            root.modelData.display(QsWindow.window, Math.round(pos.x), Math.round(pos.y));
        } catch (e) {
            if (trayNativeMenu.visible)
                trayNativeMenu.close();
            trayNativeMenu.open();
        }
    }

    onClicked: event => {
        if ((event.button === Qt.RightButton || root.modelData.onlyMenu) && root.modelData.hasMenu)
            openMenu();
        else if (event.button === Qt.LeftButton)
            root.modelData.activate();
        else
            root.modelData.secondaryActivate();
    }



    ColouredIcon {
        id: icon

        anchors.fill: parent
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon)
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour
    }
}
