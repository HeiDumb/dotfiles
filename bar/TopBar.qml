pragma ComponentBehavior: Bound

import qs.components
import qs.config
import qs.services
import qs.utils
import "components"
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property var popouts
    property var osd: null

    readonly property int barHeight: Math.max(44, Config.bar.sizes.innerWidth + Appearance.padding.normal)
    readonly property bool hasFullscreen: Hypr.workspaceHasFullscreen(Hypr.monitorFor(screen)?.activeWorkspace?.id ?? -1)

    implicitHeight: barHeight

    function closeTray(): void {
        const tray = findItem("tray");
        if (tray)
            tray.expanded = false;
    }

    function findItem(id: string): Item {
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (item?.enabled && item.id === id)
                return item.item;
        }
        return null;
    }

    function itemWidth(id: string): real {
        const item = findItem(id);
        return item ? Math.max(item.implicitWidth || 0, item.width || 0) : 0;
    }

    readonly property real leftClusterWidth: itemWidth("logo") + itemWidth("workspaces") + Appearance.spacing.normal
    readonly property real rightClusterWidth: itemWidth("tray") + itemWidth("clock") + itemWidth("statusIcons") + itemWidth("manga") + itemWidth("power") + Appearance.spacing.normal * 5
    readonly property real centerChipOffset: Math.max(-root.width * 0.14, Math.min(root.width * 0.14, (rightClusterWidth - leftClusterWidth) / 2))

    function setPopout(name: string, item: Item): void {
        popouts.detachedMode = "";
        popouts.queuedMode = "";
        popouts.currentName = name;
        popouts.currentCenter = item.mapToItem(root, item.implicitWidth / 2, 0).x;
        popouts.hasCurrent = true;
    }

    function closePopout(): void {
        popouts.hasCurrent = false;
    }

    function bluetoothDevices(): var {
        return Bluetooth.devices.values.filter(device => device);
    }

    function hasConnectedBluetoothDevice(): bool {
        return bluetoothDevices().some(device => device?.connected || device?.state === BluetoothDeviceState.Connected);
    }

    function shouldHoldTrayMenu(x: real): bool {
        const pad = Math.max(barHeight, Config.border.rounding * 3);
        return Math.abs(x - popouts.currentCenter) <= pad;
    }

    function checkPopout(x: real): void {
        if (popouts.isDetached)
            return;

        const currentIsTrayMenu = String(popouts.currentName).startsWith("traymenu");
        const pos = root.mapToItem(layout, x, root.height / 2);
        const ch = layout.childAt(pos.x, pos.y) as WrappedLoader;

        if (ch?.id !== "tray" && !currentIsTrayMenu)
            closeTray();

        if (!ch || !ch.item) {
            if (currentIsTrayMenu && shouldHoldTrayMenu(x))
                return;

            popouts.hasCurrent = false;
            if (currentIsTrayMenu)
                closeTray();
            return;
        }

        if (ch.id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = ch.item.items;
            const iconPos = root.mapToItem(items, x, root.height / 2);
            const icon = items.childAt(iconPos.x, iconPos.y);
            if (icon?.name) {
                setPopout(icon.name, icon);
                return;
            }
        } else if (ch.id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item;
            const items = tray.items;
            const iconPos = root.mapToItem(items, x, root.height / 2);
            let icon = items.childAt(iconPos.x, iconPos.y);
            if (icon && icon.index === undefined && icon.parent?.index !== undefined)
                icon = icon.parent;
            if (icon && icon.index !== undefined) {
                setPopout(`traymenu${icon.index}`, icon);
                return;
            }
        } else if (ch.id === "activeWindow" && Config.bar.popouts.activeWindow) {
            setPopout("activewindow", ch.item);
            return;
        }

        if (currentIsTrayMenu && shouldHoldTrayMenu(x))
            return;

        popouts.hasCurrent = false;
        if (currentIsTrayMenu)
            closeTray();
    }

    function handleWheel(x: real, angleDelta: point): void {
        const pos = root.mapToItem(layout, x, root.height / 2);
        const ch = layout.childAt(pos.x, pos.y) as WrappedLoader;
        if (ch?.id === "workspaces" && Config.bar.scrollActions.workspaces) {
            const mon = Config.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor;
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(`togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (Config.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatch(`workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (x < width * 0.72 && Config.bar.scrollActions.volume) {
            showOsd();
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            const monitor = Brightness.getMonitorForScreen(screen);
            if (!monitor)
                return;
            showOsd();
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + Config.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - Config.services.brightnessIncrement);
        }
    }

    function showOsd(): void {
        if (root.osd?.show)
            root.osd.show();
        else
            root.visibilities.osd = true;
    }

    ConnectedSurface {
        anchors.fill: parent
        anchors.margins: Math.max(2, Config.border.thickness / 3)
        surfaceColor: Colours.tPalette.m3surface
        radius: Appearance.rounding.full
        outlineOpacity: root.hasFullscreen ? 0.18 : 0.26
        accentOpacity: root.hasFullscreen ? 0.05 : 0.1
        glossOpacity: root.hasFullscreen ? 0.04 : 0.1
    }

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.large
        anchors.rightMargin: Appearance.padding.large
        anchors.topMargin: Appearance.padding.small
        anchors.bottomMargin: Appearance.padding.small
        spacing: Appearance.spacing.normal

        Repeater {
            id: repeater

            model: Config.bar.entries

            DelegateChooser {
                role: "id"

                DelegateChoice {
                    roleValue: "spacer"
                    delegate: Item {
                        required property bool enabled
                        required property string id

                        visible: enabled
                        Layout.fillWidth: enabled
                    }
                }
                DelegateChoice {
                    roleValue: "logo"
                    delegate: WrappedLoader {
                        sourceComponent: OsIcon {
                            visibilities: root.visibilities
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "workspaces"
                    delegate: WrappedLoader {
                        sourceComponent: TopWorkspaces {}
                    }
                }
                DelegateChoice {
                    roleValue: "activeWindow"
                    delegate: WrappedLoader {
                        Layout.maximumWidth: Math.max(260, root.width * 0.28)
                        Layout.preferredWidth: item?.implicitWidth ?? Math.max(220, root.width * 0.2)
                        Layout.preferredHeight: item?.implicitHeight ?? Config.bar.sizes.innerWidth
                        visible: enabled && !root.hasFullscreen
                        sourceComponent: WindowChip {}

                        transform: Translate {
                            x: root.centerChipOffset
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "tray"
                    delegate: WrappedLoader {
                        visible: enabled && !root.hasFullscreen
                        sourceComponent: TopTray {}
                    }
                }
                DelegateChoice {
                    roleValue: "clock"
                    delegate: WrappedLoader {
                        visible: enabled && !root.hasFullscreen
                        sourceComponent: TopClock {}
                    }
                }
                DelegateChoice {
                    roleValue: "statusIcons"
                    delegate: WrappedLoader {
                        visible: enabled && !root.hasFullscreen
                        sourceComponent: TopStatusIcons {}
                    }
                }
                DelegateChoice {
                    roleValue: "manga"
                    delegate: WrappedLoader {
                        visible: enabled && !root.hasFullscreen
                        sourceComponent: MangaButton {}
                    }
                }
                DelegateChoice {
                    roleValue: "power"
                    delegate: WrappedLoader {
                        sourceComponent: Power {
                            visibilities: root.visibilities
                        }
                    }
                }
            }
        }
    }

    component WrappedLoader: Loader {
        required property bool enabled
        required property string id
        required property int index

        Layout.alignment: Qt.AlignVCenter
        visible: enabled
        active: enabled
    }

    component TopWorkspaces: StyledClippingRect {
        id: workspacesRoot

        readonly property int activeWsId: Config.bar.workspaces.perMonitorWorkspaces ? (Hypr.monitorFor(root.screen).activeWorkspace?.id ?? 1) : Hypr.activeWsId
        readonly property var occupied: Hypr.workspaces.values.reduce((acc, curr) => {
            acc[curr.id] = curr.lastIpcObject.windows > 0;
            return acc;
        }, {})
        readonly property int groupOffset: Math.floor((activeWsId - 1) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown

        implicitWidth: workspaceRow.implicitWidth + Appearance.padding.small * 2
        implicitHeight: Config.bar.sizes.innerWidth
        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.full

        RowLayout {
            id: workspaceRow

            anchors.centerIn: parent
            spacing: Math.floor(Appearance.spacing.small / 2)

            Repeater {
                model: Config.bar.workspaces.shown

                StyledRect {
                    id: ws

                    required property int index
                    readonly property int workspaceId: workspacesRoot.groupOffset + index + 1
                    readonly property bool active: workspacesRoot.activeWsId === workspaceId
                    readonly property bool occupied: workspacesRoot.occupied[workspaceId] ?? false

                    Layout.preferredWidth: Config.bar.sizes.innerWidth - Appearance.padding.small
                    Layout.preferredHeight: Config.bar.sizes.innerWidth - Appearance.padding.small
                    radius: Appearance.rounding.full
                    color: active ? Colours.palette.m3primary : occupied && Config.bar.workspaces.occupiedBg ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 2) : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: {
                            const workspace = Hypr.workspaces.values.find(w => w.id === ws.workspaceId);
                            const name = !workspace || workspace.name == ws.workspaceId ? ws.workspaceId : workspace.name[0];
                            let displayName = name.toString();
                            if (Config.bar.workspaces.capitalisation.toLowerCase() === "upper")
                                displayName = displayName.toUpperCase();
                            else if (Config.bar.workspaces.capitalisation.toLowerCase() === "lower")
                                displayName = displayName.toLowerCase();

                            const label = Config.bar.workspaces.label || displayName;
                            const occupiedLabel = Config.bar.workspaces.occupiedLabel || label;
                            const activeLabel = Config.bar.workspaces.activeLabel || (ws.occupied ? occupiedLabel : label);
                            return ws.active ? activeLabel : ws.occupied ? occupiedLabel : label;
                        }
                        color: ws.active ? Colours.palette.m3onPrimary : ws.occupied ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Hypr.activeWsId !== ws.workspaceId)
                                Hypr.dispatch(`workspace ${ws.workspaceId}`);
                            else
                                Hypr.dispatch("togglespecialworkspace special");
                        }
                    }

                    Behavior on color {
                        CAnim {}
                    }
                }
            }
        }
    }

    component WindowChip: StyledClippingRect {
        id: windowChip

        readonly property string appClass: Hypr.activeToplevel?.lastIpcObject.class ?? ""
        readonly property string windowTitle: Hypr.activeToplevel?.title ?? ""
        readonly property var appEntry: appClass ? DesktopEntries.heuristicLookup(appClass) : null
        readonly property string appName: appEntry?.name || (appClass && appClass !== "qml6" ? appClass : windowTitle) || qsTr("Desktop")

        readonly property string displayText: appName

        implicitWidth: Math.min(titleMetrics.implicitWidth + icon.implicitWidth + Appearance.padding.large * 2 + Appearance.spacing.small, Math.max(220, Math.min(360, root.width * 0.24)))
        implicitHeight: Config.bar.sizes.innerWidth
        width: implicitWidth
        height: implicitHeight
        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.full

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.normal
            spacing: Appearance.spacing.small

            MaterialIcon {
                id: icon

                animate: true
                text: Icons.getAppCategoryIcon(Hypr.activeToplevel?.lastIpcObject.class, "desktop_windows")
                color: Colours.palette.m3primary
            }

            StyledText {
                id: titleText

                Layout.fillWidth: true
                text: windowChip.displayText
                elide: Text.ElideRight
                color: Colours.palette.m3primary
                font.family: Appearance.font.family.mono
                font.pointSize: Appearance.font.size.smaller

            }
        }

        TextMetrics {
            id: titleMetrics

            text: windowChip.displayText
            font: titleText.font
        }
    }

    component TopTray: StyledClippingRect {
        id: trayRoot

        readonly property alias items: trayItems
        readonly property var trayModel: TrayItems.build(SystemTray.items.values, Config.bar.tray.hiddenIcons)
        property bool expanded: true

        implicitWidth: trayItems.count > 0 ? Math.max(Config.bar.sizes.innerWidth, trayRow.implicitWidth + Appearance.padding.small * 2) : 0
        implicitHeight: trayItems.count > 0 ? Config.bar.sizes.innerWidth : 0
        visible: trayItems.count > 0
        color: Config.bar.tray.background ? Colours.tPalette.m3surfaceContainer : "transparent"
        radius: Appearance.rounding.full

        Row {
            id: trayRow

            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            Repeater {
                id: trayItems

                model: ScriptModel {
                    values: trayRoot.trayModel
                }

                TrayItem {
                    popouts: root.popouts
                    popoutHost: root
                }
            }
        }
    }

    component TopClock: StyledClippingRect {
        implicitWidth: clockRow.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: Config.bar.sizes.innerWidth
        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.full

        StateLayer {
            radius: Appearance.rounding.full

            function onClicked(): void {
                const show = !root.visibilities.dashboard;
                root.visibilities.launcher = false;
                root.visibilities.sidebar = false;
                root.visibilities.utilities = false;
                root.visibilities.controlCenter = false;
                root.visibilities.yin = false;
                root.visibilities.dashboard = show;
            }
        }

        RowLayout {
            id: clockRow

            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            Loader {
                active: Config.bar.clock.showIcon
                visible: active
                sourceComponent: MaterialIcon {
                    text: "calendar_month"
                    color: Colours.palette.m3tertiary
                }
            }

            StyledText {
                text: Time.format(Config.services.useTwelveHourClock ? "hh:mm A" : "hh:mm")
                font.pointSize: Appearance.font.size.smaller
                font.family: Appearance.font.family.mono
                color: Colours.palette.m3tertiary
            }
        }
    }

    component TopStatusIcons: StyledClippingRect {
        id: statusRoot

        readonly property alias items: statusRow

        implicitWidth: statusRow.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: Config.bar.sizes.innerWidth
        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.full

        RowLayout {
            id: statusRow

            anchors.centerIn: parent
            spacing: Appearance.spacing.smaller

            StatusIcon {
                name: "audio"
                visible: Config.bar.status.showAudio
                icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
            }

            StatusIcon {
                name: "audio"
                visible: Config.bar.status.showMicrophone
                icon: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
            }

            StatusText {
                name: "kblayout"
                visible: Config.bar.status.showKbLayout
                label: Hypr.kbLayout
            }

            StatusIcon {
                name: "network"
                visible: Config.bar.status.showNetwork && (!Nmcli.activeEthernet || Config.bar.status.showWifi)
                icon: Nmcli.displayWifiActive ? Icons.getNetworkIcon(Nmcli.displayWifiStrength) : "wifi_off"
            }

            StatusIcon {
                name: "ethernet"
                visible: Config.bar.status.showNetwork && Nmcli.activeEthernet
                icon: "cable"
            }

            StatusIcon {
                name: "bluetooth"
                visible: Config.bar.status.showBluetooth
                icon: {
                    if (!Bluetooth.defaultAdapter?.enabled)
                        return "bluetooth_disabled";
                    if (root.hasConnectedBluetoothDevice())
                        return "bluetooth_connected";
                    return "bluetooth";
                }
            }

            StatusIcon {
                name: "battery"
                visible: Config.bar.status.showBattery
                icon: {
                    if (!UPower.displayDevice.isLaptopBattery)
                        return "balance";

                    const perc = UPower.displayDevice.percentage;
                    const charging = [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state);

                    if (perc === 1)
                        return charging ? "battery_charging_full" : "battery_full";

                    let level = Math.floor(perc * 7);

                    if (charging && (level === 4 || level === 1))
                        level--;

                    return charging ? `battery_charging_${(level + 3) * 10}` : `battery_${level}_bar`;
                }
                colour: !UPower.onBattery || UPower.displayDevice.percentage > 0.2 ? Colours.palette.m3secondary : Colours.palette.m3error
            }
        }
    }

    component MangaButton: StyledClippingRect {
        implicitWidth: Config.bar.sizes.innerWidth
        implicitHeight: Config.bar.sizes.innerWidth
        color: root.visibilities.weebcentral ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.full

        StateLayer {
            function onClicked(): void {
                const show = !root.visibilities.weebcentral;
                root.visibilities.weebcentral = show;
                Quickshell.execDetached([
                    "/home/hei/.local/bin/toggle-weebcentral-panel",
                    show ? "show" : "hide"
                ]);
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "menu_book"
            fill: root.visibilities.weebcentral ? 1 : 0
            color: root.visibilities.weebcentral ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3secondary
            font.pointSize: Appearance.font.size.large

            Behavior on fill {
                Anim {}
            }
        }

        Behavior on color {
            CAnim {}
        }
    }

    component StatusIcon: Item {
        required property string name
        required property string icon
        property color colour: Colours.palette.m3secondary

        implicitWidth: iconItem.implicitWidth
        implicitHeight: iconItem.implicitHeight

        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        MaterialIcon {
            id: iconItem

            anchors.centerIn: parent
            animate: true
            text: icon
            color: colour
            fill: 1
        }
    }

    component StatusText: Item {
        required property string name
        required property string label

        implicitWidth: labelItem.implicitWidth
        implicitHeight: labelItem.implicitHeight

        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        StyledText {
            id: labelItem

            anchors.centerIn: parent
            text: label
            color: Colours.palette.m3secondary
            font.family: Appearance.font.family.mono
        }
    }
}
