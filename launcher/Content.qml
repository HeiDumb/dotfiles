pragma ComponentBehavior: Bound

import "services"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import Caelestia.Config

Item {
    id: root

    required property PersistentProperties visibilities
    required property var panels
    required property real maxHeight

    readonly property int padding: Appearance.padding.large
    readonly property int rounding: Tokens.rounding.large
    readonly property bool voidDeckMode: list.currentList?.deckMode ?? false
    readonly property real portalClosedWidth: 88
    readonly property real portalTargetWidth: Math.min(430, Math.max(320, listWrapper.width * 0.44))

    property real portalProgress: visibilities.launcher ? 1 : 0

    implicitWidth: listWrapper.width + padding * 2
    implicitHeight: listWrapper.height + padding
    clip: !voidDeckMode

    function focusSearch(): void {
        if (!root.visibilities.launcher)
            return;

        search.forceActiveFocus();
        search.cursorPosition = search.text.length;
    }

    function requestSearchFocus(): void {
        focusSearch();
        focusSearchTimer.restart();
    }

    Timer {
        id: focusSearchTimer

        interval: 50
        repeat: false
        onTriggered: root.focusSearch()
    }

    Keys.onEscapePressed: root.visibilities.launcher = false

    ConnectedSurface {
        anchors.fill: parent
        surfaceColor: Colours.tPalette.m3surface
        radius: root.rounding
        z: -1
        visible: !root.voidDeckMode
        opacity: root.voidDeckMode ? 0 : 1
        outlineOpacity: 0.24
        accentOpacity: 0.07
        glossOpacity: 0.08

        Behavior on opacity {
            Anim {
                duration: Appearance.anim.durations.small
            }
        }
    }

    Behavior on portalProgress {
        Anim {
            duration: 260
            easing.bezierCurve: root.visibilities.launcher ? Appearance.anim.curves.expressiveDefaultSpatial : Appearance.anim.curves.emphasizedAccel
        }
    }

    Item {
        id: listWrapper

        implicitWidth: list.width
        implicitHeight: list.height + root.padding

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0

        ContentList {
            id: list

            content: root
            visibilities: root.visibilities
            panels: root.panels
            maxHeight: root.maxHeight - searchWrapper.implicitHeight - root.padding * 3
            search: search
            padding: root.padding
            rounding: root.rounding
        }
    }

    StyledRect {
        id: searchWrapper

        visible: !root.voidDeckMode
        color: "transparent"
        radius: root.voidDeckMode ? Tokens.rounding.full : Tokens.rounding.large
        border.width: 0
        opacity: 0

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0

        width: 1

        implicitHeight: 1

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 30
            height: parent.height + 16
            radius: height / 2
            color: Qt.alpha(Colours.palette.m3primary, root.voidDeckMode ? 0.1 : 0.04)
            opacity: root.portalProgress
            z: -2
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large
            height: Math.max(2, 4 + root.portalProgress * 5)
            radius: height / 2
            color: Qt.alpha(Colours.palette.m3primary, root.voidDeckMode ? 0.72 : 0.28)
            opacity: root.voidDeckMode ? 0.9 : 0.45
        }

        MaterialIcon {
            id: searchIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: root.padding

            text: "search"
            color: Colours.palette.m3primary
            opacity: root.portalProgress
        }

        StyledTextField {
            id: search

            anchors.left: searchIcon.right
            anchors.right: clearIcon.left
            anchors.leftMargin: Appearance.spacing.small
            anchors.rightMargin: Appearance.spacing.small

            topPadding: Appearance.padding.larger
            bottomPadding: Appearance.padding.larger

            placeholderText: qsTr("Type \"%1\" for commands").arg(Config.launcher.actionPrefix)
            opacity: root.portalProgress

            onAccepted: {
                const currentItem = list.currentList?.currentItem;
                if (currentItem) {
                    if (list.showWallpapers) {
                        if (Colours.scheme === "dynamic" && currentItem.modelData.path !== Wallpapers.actualCurrent)
                            Wallpapers.previewColourLock = true;
                        Wallpapers.setWallpaper(currentItem.modelData.path);
                        root.visibilities.launcher = false;
                    } else if (text.startsWith(Config.launcher.actionPrefix)) {
                        if (text.startsWith(`${Config.launcher.actionPrefix}calc `))
                            currentItem.onClicked();
                        else
                            currentItem.modelData.onClicked(list.currentList);
                    } else {
                        Apps.launch(currentItem.modelData, currentItem);
                        root.visibilities.launcher = false;
                    }
                }
            }

            Keys.onUpPressed: list.currentList?.decrementCurrentIndex()
            Keys.onDownPressed: list.currentList?.incrementCurrentIndex()

            Keys.onEscapePressed: root.visibilities.launcher = false

            Keys.onPressed: event => {
                if (!Config.launcher.vimKeybinds)
                    return;

                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J) {
                        list.currentList?.incrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K) {
                        list.currentList?.decrementCurrentIndex();
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Tab) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                }
            }

            Component.onCompleted: root.requestSearchFocus()

            Connections {
                target: root.visibilities

                function onLauncherChanged(): void {
                    if (root.visibilities.launcher)
                        root.requestSearchFocus();
                    else
                        search.text = "";
                }

                function onSessionChanged(): void {
                    if (!root.visibilities.session && root.visibilities.launcher)
                        root.requestSearchFocus();
                }
            }
        }

        MaterialIcon {
            id: clearIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: root.padding

            width: search.text ? implicitWidth : implicitWidth / 2
            opacity: {
                if (!search.text)
                    return 0;
                if (mouse.pressed)
                    return 0.7;
                if (mouse.containsMouse)
                    return 0.8;
                return 1;
            }

            text: "close"
            color: Colours.palette.m3primary

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: search.text ? Qt.PointingHandCursor : undefined

                onClicked: search.text = ""
            }

            Behavior on width {
                Anim {
                    duration: Appearance.anim.durations.small
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
