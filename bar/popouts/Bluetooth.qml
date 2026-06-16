pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property PopoutState popouts

    width: 300
    spacing: Tokens.spacing.small

    function devices(): var {
        return Bluetooth.devices.values.filter(device => device);
    }

    function connected(device: var): bool {
        return device?.connected || device?.state === BluetoothDeviceState.Connected;
    }

    function deviceName(device: var): string {
        return device?.name || device?.alias || device?.address || qsTr("Unknown device");
    }

    StyledText {
        Layout.topMargin: Tokens.padding.normal
        Layout.rightMargin: Tokens.padding.small
        text: qsTr("Bluetooth")
        font.weight: 500
    }

    Toggle {
        label: qsTr("Enabled")
        checked: Bluetooth.defaultAdapter?.enabled ?? false // qmllint disable unresolved-type
        toggle.onToggled: {
            const adapter = Bluetooth.defaultAdapter; // qmllint disable unresolved-type
            if (adapter)
                adapter.enabled = checked;
        }
    }

    Toggle {
        label: qsTr("Discovering")
        checked: Bluetooth.defaultAdapter?.discovering ?? false // qmllint disable unresolved-type
        toggle.onToggled: {
            const adapter = Bluetooth.defaultAdapter; // qmllint disable unresolved-type
            if (adapter)
                adapter.discovering = checked;
        }
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.small
        Layout.rightMargin: Tokens.padding.small
        text: {
            const devices = root.devices(); // qmllint disable unresolved-type
            let available = qsTr("%1 device%2 available").arg(devices.length).arg(devices.length === 1 ? "" : "s");
            const connected = devices.filter(device => root.connected(device)).length;
            if (connected > 0)
                available += qsTr(" (%1 connected)").arg(connected);
            return available;
        }
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
    }

    Repeater {
        model: ScriptModel {
            values: root.devices().sort((a, b) => (root.connected(b) - root.connected(a)) || ((b?.paired ?? false) - (a?.paired ?? false)) || root.deviceName(a).localeCompare(root.deviceName(b))).slice(0, 5) // qmllint disable unresolved-type
        }

        RowLayout {
            id: device

            required property BluetoothDevice modelData
            readonly property bool loading: modelData && (modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting) // qmllint disable unresolved-type
            readonly property bool connected: root.connected(modelData)

            Layout.fillWidth: true
            Layout.rightMargin: Tokens.padding.small
            spacing: Tokens.spacing.small

            opacity: 0
            scale: 0.7

            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }

            Behavior on opacity {
                Anim {}
            }

            Behavior on scale {
                Anim {}
            }

            MaterialIcon {
                text: Icons.getBluetoothIcon(device.modelData?.icon ?? "")
            }

            StyledText {
                Layout.leftMargin: Tokens.spacing.small / 2
                Layout.rightMargin: Tokens.spacing.small / 2
                Layout.fillWidth: true
                text: root.deviceName(device.modelData)
                elide: Text.ElideRight
            }

            MaterialIcon {
                visible: device.connected  // qmllint disable unresolved-type
                text: Icons.getBatteryIcon(device.modelData?.batteryAvailable ? device.modelData.battery * 100 : -1)
                color: (device.modelData?.battery ?? 1) < 0.2 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            }

            StyledRect {
                id: connectBtn

                implicitWidth: implicitHeight
                implicitHeight: connectIcon.implicitHeight + Tokens.padding.small

                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3primary, device.connected ? 1 : 0) // qmllint disable unresolved-type

                CircularIndicator {
                    anchors.fill: parent
                    running: device.loading
                }

                StateLayer {
                    color: device.connected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface // qmllint disable unresolved-type
                    disabled: device.loading || !device.modelData
                    onClicked: {
                        if (device.modelData)
                            device.modelData.connected = !device.connected;
                    }
                }

                MaterialIcon {
                    id: connectIcon

                    anchors.centerIn: parent
                    animate: true
                    text: device.connected ? "link_off" : "link"
                    color: device.connected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface // qmllint disable unresolved-type

                    opacity: device.loading ? 0 : 1

                    Behavior on opacity {
                        Anim {}
                    }
                }
            }

            Loader {
                visible: status === Loader.Ready
                asynchronous: true
                active: device.modelData?.bonded ?? false
                sourceComponent: Item {
                    implicitWidth: connectBtn.implicitWidth
                    implicitHeight: connectBtn.implicitHeight

                    StateLayer {
                        radius: Tokens.rounding.full
                        disabled: !device.modelData
                        onClicked: {
                            if (device.modelData)
                                device.modelData.forget();
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "delete"
                    }
                }
            }
        }
    }

    IconTextButton {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.normal
        inactiveColour: Colours.palette.m3primaryContainer
        inactiveOnColour: Colours.palette.m3onPrimaryContainer
        verticalPadding: Tokens.padding.small
        text: qsTr("Open settings")
        icon: "settings"

        onClicked: root.popouts.detachRequested("bluetooth")
    }

    component Toggle: RowLayout {
        required property string label
        property alias checked: toggle.checked
        property alias toggle: toggle

        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.small
        spacing: Tokens.spacing.normal

        StyledText {
            Layout.fillWidth: true
            text: parent.label
        }

        StyledSwitch {
            id: toggle
        }
    }
}
