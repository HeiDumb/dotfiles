pragma ComponentBehavior: Bound

import "dash"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.filedialog
import qs.components.images
import qs.components.misc
import qs.config
import qs.services
import qs.utils
import Caelestia.Services
import Quickshell
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property PersistentProperties visibilities
    required property PersistentProperties state
    required property FileDialog facePicker

    readonly property int panelWidth: 372
    readonly property real nonAnimWidth: panelWidth
    readonly property real nonAnimHeight: stack.implicitHeight
    readonly property real playerProgress: {
        const active = Players.active;
        return active?.length ? active.position / active.length : 0;
    }

    implicitWidth: panelWidth
    implicitHeight: stack.implicitHeight

    function displayTemp(temp: real): string {
        if (temp <= 0)
            return qsTr("--");
        return `${Math.ceil(Config.services.useFahrenheitPerformance ? temp * 1.8 + 32 : temp)}°${Config.services.useFahrenheitPerformance ? "F" : "C"}`;
    }

    function lengthStr(length: int): string {
        if (length < 0)
            return "-:--";

        const hours = Math.floor(length / 3600);
        const mins = Math.floor((length % 3600) / 60);
        const secs = Math.floor(length % 60).toString().padStart(2, "0");

        if (hours > 0)
            return `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
        return `${mins}:${secs}`;
    }

    ColumnLayout {
        id: stack

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Appearance.spacing.normal

        HeaderCard {}
        MediaCard {}
        PerformanceCard {}
        PanelCard {
            Item {
                Layout.fillWidth: true
                implicitHeight: calendar.implicitHeight

                Calendar {
                    id: calendar

                    anchors.left: parent.left
                    anchors.right: parent.right
                    state: root.state
                }
            }
        }
    }

    component PanelCard: StyledRect {
        id: card

        default property alias content: body.data
        property string title: ""
        property string icon: ""

        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + Appearance.padding.large * 2
        radius: Appearance.rounding.large
        color: Qt.alpha(Colours.tPalette.m3surface, 0.92)
        border.width: 0
        border.color: "transparent"

        ColumnLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.normal
        }
    }

    component HeaderCard: PanelCard {
        Component.onCompleted: Weather.reload()

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledClippingRect {
                Layout.preferredWidth: 58
                Layout.preferredHeight: 58
                radius: Appearance.rounding.large
                color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "person"
                    fill: 1
                    font.pointSize: Appearance.font.size.extraLarge
                    color: Colours.palette.m3onSurfaceVariant
                }

                CachingImage {
                    anchors.fill: parent
                    path: `${Paths.home}/.face`
                }

                StateLayer {
                    function onClicked(): void {
                        root.visibilities.launcher = false;
                        root.facePicker.open();
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: SysInfo.osPrettyName || SysInfo.osName || qsTr("Caelestia")
                    elide: Text.ElideRight
                    font.pointSize: Appearance.font.size.normal
                    font.weight: 600
                }

                StyledText {
                    Layout.fillWidth: true
                    text: `${SysInfo.wm} • up ${SysInfo.uptime}`
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.small
                }
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Text
                onClicked: Weather.reload()
            }

            IconButton {
                icon: "close"
                type: IconButton.Text
                onClicked: root.visibilities.dashboard = false
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledText {
                text: Time.format(Config.services.useTwelveHourClock ? "hh:mm A" : "hh:mm")
                color: Colours.palette.m3primary
                font.family: Appearance.font.family.clock
                font.pointSize: Appearance.font.size.extraLarge
                font.weight: 600
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Time.format("dddd")
                    elide: Text.ElideRight
                    font.pointSize: Appearance.font.size.normal
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Time.format("MMMM d")
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.small
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: weatherRow.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.large
            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

            RowLayout {
                id: weatherRow

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                StyledRect {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: Appearance.rounding.full
                    color: Colours.palette.m3secondaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        animate: true
                        text: Weather.icon
                        color: Colours.palette.m3onSecondaryContainer
                        font.pointSize: Appearance.font.size.extraLarge
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Weather.temp || qsTr("--")
                        color: Colours.palette.m3primary
                        font.pointSize: Appearance.font.size.large
                        font.weight: 700
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Weather.description || Weather.city || qsTr("Weather")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }
                }

                ColumnLayout {
                    spacing: 0

                    StyledText {
                        text: qsTr("Humidity")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.smaller
                    }

                    StyledText {
                        text: Weather.humidity ? `${Weather.humidity}%` : qsTr("--")
                        color: Colours.palette.m3secondary
                        font.pointSize: Appearance.font.size.small
                        font.weight: 600
                    }
                }

                ColumnLayout {
                    spacing: 0

                    StyledText {
                        text: qsTr("Wind")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.smaller
                    }

                    StyledText {
                        text: Weather.windSpeed ? `${Weather.windSpeed} km/h` : qsTr("--")
                        color: Colours.palette.m3tertiary
                        font.pointSize: Appearance.font.size.small
                        font.weight: 600
                    }
                }
            }
        }
    }

    component WeatherCard: PanelCard {
        Component.onCompleted: Weather.reload()

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledRect {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: Appearance.rounding.full
                color: Colours.palette.m3secondaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    animate: true
                    text: Weather.icon
                    color: Colours.palette.m3onSecondaryContainer
                    font.pointSize: Appearance.font.size.extraLarge
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Weather.temp || qsTr("--")
                    color: Colours.palette.m3primary
                    font.pointSize: Appearance.font.size.large
                    font.weight: 700
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Weather.description || Weather.city || qsTr("Weather")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Text
                onClicked: Weather.reload()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            WeatherInfoLine {
                Layout.fillWidth: true
                icon: "water_drop"
                label: qsTr("Humidity")
                value: Weather.humidity ? `${Weather.humidity}%` : qsTr("--")
                colour: Colours.palette.m3secondary
            }

            WeatherInfoLine {
                Layout.fillWidth: true
                icon: "air"
                label: qsTr("Wind")
                value: Weather.windSpeed ? `${Weather.windSpeed} km/h` : qsTr("--")
                colour: Colours.palette.m3tertiary
            }
        }
    }

    component PerformanceCard: PanelCard {
        Ref {
            service: SystemUsage
        }

        Ref {
            service: NetworkUsage
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Performance")
            font.pointSize: Appearance.font.size.normal
            font.weight: 600
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            MetricTile {
                icon: "memory"
                label: qsTr("CPU")
                value: `${Math.round(SystemUsage.cpuPerc * 100)}%`
                colour: Colours.palette.m3primary
            }

            MetricTile {
                icon: "memory_alt"
                label: qsTr("RAM")
                value: `${Math.round(SystemUsage.memPerc * 100)}%`
                colour: Colours.palette.m3secondary
            }
        }

        MeterRow {
            visible: Config.dashboard.performance.showCpu
            icon: "memory"
            label: qsTr("CPU")
            value: SystemUsage.cpuPerc
            detail: SystemUsage.cpuTemp > 0 ? root.displayTemp(SystemUsage.cpuTemp) : `${Math.round(SystemUsage.cpuPerc * 100)}%`
            colour: Colours.palette.m3primary
        }

        MeterRow {
            visible: Config.dashboard.performance.showGpu && SystemUsage.gpuType !== "NONE"
            icon: "desktop_windows"
            label: qsTr("GPU")
            value: SystemUsage.gpuPerc
            detail: SystemUsage.gpuTemp > 0 ? root.displayTemp(SystemUsage.gpuTemp) : `${Math.round(SystemUsage.gpuPerc * 100)}%`
            colour: Colours.palette.m3secondary
        }

        MeterRow {
            visible: Config.dashboard.performance.showMemory
            icon: "memory_alt"
            label: qsTr("Memory")
            value: SystemUsage.memPerc
            detail: {
                const used = SystemUsage.formatKib(SystemUsage.memUsed);
                const total = SystemUsage.formatKib(SystemUsage.memTotal);
                return `${used.value.toFixed(1)} / ${Math.floor(total.value)} ${total.unit}`;
            }
            colour: Colours.palette.m3secondary
        }

        MeterRow {
            visible: Config.dashboard.performance.showStorage
            icon: "hard_disk"
            label: qsTr("Storage")
            value: SystemUsage.dashboardStoragePerc
            detail: `${Math.round(SystemUsage.dashboardStoragePerc * 100)}%`
            colour: Colours.palette.m3tertiary
        }

        Repeater {
            model: Config.dashboard.performance.showStorage && SystemUsage.dashboardStorage ? [SystemUsage.dashboardStorage] : []

            DiskRow {
                required property var modelData

                disk: modelData
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: Config.dashboard.performance.showNetwork
            spacing: Appearance.spacing.smaller

            InfoRow {
                icon: "download"
                label: qsTr("Download")
                value: {
                    const fmt = NetworkUsage.formatBytes(NetworkUsage.downloadSpeed ?? 0);
                    return `${fmt.value.toFixed(1)} ${fmt.unit}`;
                }
                colour: Colours.palette.m3tertiary
            }

            InfoRow {
                icon: "upload"
                label: qsTr("Upload")
                value: {
                    const fmt = NetworkUsage.formatBytes(NetworkUsage.uploadSpeed ?? 0);
                    return `${fmt.value.toFixed(1)} ${fmt.unit}`;
                }
                colour: Colours.palette.m3secondary
            }

            InfoRow {
                icon: "history"
                label: qsTr("Total")
                value: {
                    const down = NetworkUsage.formatBytesTotal(NetworkUsage.downloadTotal ?? 0);
                    const up = NetworkUsage.formatBytesTotal(NetworkUsage.uploadTotal ?? 0);
                    return `↓${down.value.toFixed(1)}${down.unit} ↑${up.value.toFixed(1)}${up.unit}`;
                }
                colour: Colours.palette.m3onSurfaceVariant
            }
        }

        MeterRow {
            visible: UPower.displayDevice.isLaptopBattery && Config.dashboard.performance.showBattery
            icon: "battery_full"
            label: qsTr("Battery")
            value: UPower.displayDevice.percentage
            detail: {
                if (UPower.displayDevice.state === UPowerDeviceState.FullyCharged)
                    return qsTr("Full");
                if (UPower.displayDevice.state === UPowerDeviceState.Charging)
                    return qsTr("Charging");
                const s = UPower.displayDevice.timeToEmpty;
                if (s <= 0)
                    return `${Math.round(UPower.displayDevice.percentage * 100)}%`;
                const hr = Math.floor(s / 3600);
                const min = Math.floor((s % 3600) / 60);
                return hr > 0 ? `${hr}h ${min}m` : `${min}m`;
            }
            colour: Colours.palette.m3primary
        }
    }

    component MediaCard: PanelCard {
        id: mediaCard

        readonly property var activePlayer: Players.active
        readonly property bool hasSound: (mediaCard.activePlayer?.isPlaying ?? false) || (Audio.cava.values ?? []).some(v => v > 0.03)

        ServiceRef {
            service: Audio.cava
        }

        ServiceRef {
            service: Audio.beatTracker
        }

        Timer {
            running: mediaCard.activePlayer?.isPlaying ?? false
            interval: Config.dashboard.mediaUpdateInterval
            triggeredOnStart: true
            repeat: true
            onTriggered: mediaCard.activePlayer?.positionChanged()
        }

        StyledClippingRect {
            Layout.fillWidth: true
            implicitHeight: 282
            radius: Appearance.rounding.large
            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

            Rectangle {
                anchors.fill: parent
                color: "transparent"

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.alpha(Colours.palette.m3surface, 0.18) }
                    GradientStop { position: 0.45; color: Qt.alpha(Colours.palette.m3surface, 0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            StyledRect {
                id: infoPanel

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: Appearance.padding.large
                width: Math.min(180, parent.width * 0.48)
                radius: Appearance.rounding.large
                color: Qt.alpha(Colours.palette.m3surface, 0.56)
                z: 3

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: Appearance.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        StyledClippingRect {
                            Layout.preferredWidth: 72
                            Layout.preferredHeight: 72
                            radius: Appearance.rounding.large
                            color: Colours.tPalette.m3surfaceContainerHigh

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "art_track"
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Appearance.font.size.large
                            }

                            Image {
                                anchors.fill: parent
                                source: activePlayer?.trackArtUrl ?? ""
                                asynchronous: true
                                cache: false
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: width
                                sourceSize.height: height
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Now Playing")
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                                font.pointSize: Appearance.font.size.small
                                font.weight: 500
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: activePlayer?.trackTitle || qsTr("No media")
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                font.pointSize: Appearance.font.size.normal
                                font.weight: 700
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: activePlayer?.trackArtist || activePlayer?.identity || qsTr("Nothing playing")
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Appearance.font.size.small
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        spacing: Appearance.spacing.small

                        IconButton {
                            icon: "skip_previous"
                            type: IconButton.Tonal
                            font.pointSize: Appearance.font.size.large
                            disabled: !(activePlayer?.canGoPrevious ?? false)
                            onClicked: activePlayer?.previous()
                        }

                        IconButton {
                            icon: activePlayer?.isPlaying ? "pause" : "play_arrow"
                            type: IconButton.Filled
                            font.pointSize: Appearance.font.size.extraLarge
                            disabled: !(activePlayer?.canTogglePlaying ?? false)
                            onClicked: activePlayer?.togglePlaying()
                        }

                        IconButton {
                            icon: "skip_next"
                            type: IconButton.Tonal
                            font.pointSize: Appearance.font.size.large
                            disabled: !(activePlayer?.canGoNext ?? false)
                            onClicked: activePlayer?.next()
                        }
                    }

                    StyledSlider {
                        id: mediaSlider

                        Layout.fillWidth: true
                        implicitHeight: Appearance.padding.normal * 3
                        enabled: !!mediaCard.activePlayer

                        onMoved: {
                            const active = mediaCard.activePlayer;
                            if (active?.canSeek && active?.positionSupported)
                                active.position = value * active.length;
                        }

                        Binding {
                            target: mediaSlider
                            property: "value"
                            value: root.playerProgress
                            when: !mediaSlider.pressed
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: Math.max(position.implicitHeight, length.implicitHeight)

                        StyledText {
                            id: position

                            anchors.left: parent.left
                            text: root.lengthStr(mediaCard.activePlayer?.position ?? -1)
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }

                        StyledText {
                            id: length

                            anchors.right: parent.right
                            text: root.lengthStr(mediaCard.activePlayer?.length ?? -1)
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.small
                        }
                    }
                }
            }

            Item {
                id: catStage

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.left: infoPanel.right
                anchors.leftMargin: Appearance.spacing.small
                anchors.topMargin: Appearance.padding.small
                anchors.bottomMargin: Appearance.padding.small
                anchors.rightMargin: Appearance.padding.small
                z: 1

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Appearance.padding.small
                    height: 18
                    radius: Appearance.rounding.full
                    color: Qt.alpha(Colours.palette.m3shadow, 0.16)
                    opacity: 0.28
                }

                AnimatedImage {
                    anchors.centerIn: parent
                    width: Math.min(parent.width * 1.08, 210)
                    height: Math.min(parent.height * 1.08, 230)
                    source: Paths.absolutePath(Config.paths.mediaGif)
                    playing: mediaCard.hasSound
                    asynchronous: true
                    fillMode: AnimatedImage.PreserveAspectFit
                    speed: 0.67
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            IconButton {
                icon: "move_up"
                type: IconButton.Text
                disabled: !(mediaCard.activePlayer?.canRaise ?? false)
                onClicked: {
                    mediaCard.activePlayer?.raise();
                    root.visibilities.dashboard = false;
                }
            }

            SplitButton {
                id: playerSelector

                Layout.fillWidth: true
                disabled: !Players.list.length
                active: menuItems.find(m => m.modelData === mediaCard.activePlayer) ?? menuItems[0] ?? null
                menu.onItemSelected: item => Players.manualActive = item.modelData
                menuItems: playerList.instances
                fallbackIcon: "music_off"
                fallbackText: qsTr("No players")
                label.Layout.maximumWidth: 160
                label.elide: Text.ElideRight
                menuOnTop: true

                Variants {
                    id: playerList

                    model: Players.list

                    PlayerItem {}
                }
            }

            IconButton {
                icon: "delete"
                type: IconButton.Text
                disabled: !(mediaCard.activePlayer?.canQuit ?? false)
                onClicked: mediaCard.activePlayer?.quit()
            }
        }
    }

    component MetricTile: StyledRect {
        id: metricTile

        required property string icon
        required property string label
        required property string value
        required property color colour

        Layout.fillWidth: true
        implicitHeight: 82
        radius: Appearance.rounding.large
        color: Colours.tPalette.m3surfaceContainer

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: 0

            RowLayout {
                Layout.fillWidth: true

                MaterialIcon {
                    text: metricTile.icon
                    color: metricTile.colour
                    fill: 1
                    font.pointSize: Appearance.font.size.large
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: metricTile.value
                    color: metricTile.colour
                    font.pointSize: Appearance.font.size.large
                    font.weight: 700
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: metricTile.label
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
                elide: Text.ElideRight
            }
        }
    }

    component WeatherInfoLine: RowLayout {
        required property string icon
        required property string label
        required property string value
        required property color colour

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        MaterialIcon {
            text: parent.icon
            color: parent.colour
            fill: 1
            font.pointSize: Appearance.font.size.normal
        }

        StyledText {
            text: parent.label
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.small
        }

        Item {
            Layout.fillWidth: true
        }

        StyledText {
            text: parent.value
            color: Colours.palette.m3onSurface
            font.pointSize: Appearance.font.size.small
            font.weight: 600
        }
    }

    component ForecastRow: StyledRect {
        id: forecastRow

        required property string day
        required property string date
        required property string icon
        required property string temp

        Layout.fillWidth: true
        implicitHeight: row.implicitHeight + Appearance.padding.small * 2
        radius: Appearance.rounding.normal
        color: Colours.tPalette.m3surfaceContainer

        RowLayout {
            id: row

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.small

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: forecastRow.day
                    elide: Text.ElideRight
                    font.pointSize: Appearance.font.size.small
                    font.weight: 600
                }

                StyledText {
                    Layout.fillWidth: true
                    text: forecastRow.date
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.smaller
                }
            }

            MaterialIcon {
                text: forecastRow.icon
                color: Colours.palette.m3secondary
                font.pointSize: Appearance.font.size.large
            }

            StyledText {
                text: forecastRow.temp
                color: Colours.palette.m3tertiary
                font.pointSize: Appearance.font.size.small
                font.weight: 600
            }
        }
    }

    component InfoRow: RowLayout {
        required property string icon
        required property string label
        required property string value
        required property color colour

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        MaterialIcon {
            text: parent.icon
            color: parent.colour
            fill: 1
            font.pointSize: Appearance.font.size.normal
        }

        StyledText {
            text: parent.label
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.small
        }

        Item {
            Layout.fillWidth: true
        }

        StyledText {
            text: parent.value
            color: Colours.palette.m3onSurface
            font.pointSize: Appearance.font.size.small
            font.weight: 600
        }
    }

    component DiskRow: InfoRow {
        required property var disk

        icon: "subdirectory_arrow_right"
        label: disk.mount
        value: {
            const used = SystemUsage.formatKib(disk.used);
            const total = SystemUsage.formatKib(disk.total);
            return `${used.value.toFixed(1)} / ${Math.floor(total.value)} ${total.unit}`;
        }
        colour: Colours.palette.m3tertiary
    }

    component PlayerItem: MenuItem {
        required property var modelData

        icon: modelData === Players.active ? "check" : ""
        text: Players.getIdentity(modelData)
        activeIcon: "animated_images"
    }

    component MeterRow: RowLayout {
        required property string icon
        required property string label
        required property real value
        required property string detail
        required property color colour

        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        MaterialIcon {
            text: icon
            color: colour
            fill: 1
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.smaller

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: label
                    font.pointSize: Appearance.font.size.small
                    font.weight: 500
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: detail.length > 0 ? detail : `${Math.round(value * 100)}%`
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.small
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: Appearance.rounding.full
                color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                StyledRect {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.max(0, Math.min(1, value))
                    radius: parent.radius
                    color: colour

                    Behavior on width {
                        Anim {
                            duration: Appearance.anim.durations.large
                        }
                    }
                }
            }
        }
    }
}
