pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.config
import qs.services
import qs.utils
import Caelestia
import Quickshell
import QtQuick

Item {
    id: root

    required property PersistentProperties visibilities
    readonly property PersistentProperties dashState: PersistentProperties {
        property int currentTab
        property date currentDate: new Date()

        reloadableId: "dashboardState"
    }
    readonly property FileDialog facePicker: FileDialog {
        title: qsTr("Select a profile picture")
        filterLabel: qsTr("Image files")
        filters: Images.validImageExtensions
        onAccepted: path => {
            if (CUtils.copyFile(Qt.resolvedUrl(path), Qt.resolvedUrl(`${Paths.home}/.face`)))
                Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "low", "-h", `STRING:image-path:${path}`, "Profile picture changed", `Profile picture changed to ${Paths.shortenHome(path)}`]);
            else
                Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "critical", "Unable to change profile picture", `Failed to change profile picture to ${Paths.shortenHome(path)}`]);
        }
    }

    readonly property real nonAnimHeight: state === "visible" ? (content.item?.nonAnimHeight ?? 0) : 0
    readonly property int panelPadding: Appearance.padding.large
    readonly property real availableWidth: parent?.width ?? 1200
    readonly property real availableHeight: parent?.height ?? 800
    readonly property real targetWidth: Math.min(380, Math.max(340, availableWidth - Appearance.padding.large * 2))
    readonly property real targetHeight: Math.max(0, availableHeight)

    visible: root.visibilities.dashboard && Config.dashboard.enabled
    implicitHeight: targetHeight
    implicitWidth: 0
    opacity: targetWidth > 0 ? Math.min(1, implicitWidth / Math.max(1, targetWidth)) : 0
    clip: false

    onStateChanged: {
        if (state === "visible" && timer.running) {
            timer.triggered();
            timer.stop();
        }
    }

    states: State {
        name: "visible"
        when: root.visibilities.dashboard && Config.dashboard.enabled

        PropertyChanges {
            root.implicitWidth: root.targetWidth
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "implicitWidth"
                duration: Appearance.anim.durations.large
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "implicitWidth"
                duration: Appearance.anim.durations.large
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        }
    ]

    Timer {
        id: timer

        running: true
        interval: Appearance.anim.durations.extraLarge
        onTriggered: {
            scroller.visible = true;
        }
    }

    Flickable {
        id: scroller

        anchors.fill: parent
        anchors.margins: root.panelPadding
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight

        visible: false

        Loader {
            id: content

            width: scroller.width
            active: true

            sourceComponent: VerticalContent {
                width: content.width
                visibilities: root.visibilities
                state: root.dashState
                facePicker: root.facePicker
            }
        }
    }
}
