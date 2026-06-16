pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    readonly property string stateSleeping: "sleeping"
    readonly property string stateIdle: "idle"
    readonly property string stateWatchingCursor: "watchingCursor"
    readonly property string statePet: "pet"
    readonly property string stateWalking: "walking"
    readonly property string stateStare: "stareAtUser"
    readonly property string stateTailPull: "tailPull"
    readonly property string stateBoxNap: "boxNap"
    readonly property string statePawLick: "pawLick"
    readonly property string statePawChew: "pawChew"
    readonly property string stateMusicReactive: "musicReactive"
    readonly property string stateNotificationAlert: "notificationAlert"
    readonly property string stateWindowGuard: "windowGuard"
    readonly property string stateWorkspaceJump: "workspaceJump"
    readonly property string stateWallpaperTransform: "wallpaperTransform"
    readonly property string stateMischiefChew: "mischiefChew"
    readonly property string stateWarning: "warning"
    readonly property string stateHidden: "hidden"

    property string name: stateSleeping
    property bool hovered
    property bool musicPlaying
    property bool forcedHidden
    property bool awake
    readonly property bool hidden: name === stateHidden

    visible: false

    function applyBaseState(): void {
        if (root.forcedHidden) {
            root.name = root.stateHidden;
            return;
        }

        if (root.name === root.statePet
            || root.name === root.stateTailPull
            || root.name === root.stateWalking
            || root.name === root.stateStare
            || root.name === root.stateMischiefChew
            || root.name === root.statePawLick
            || root.name === root.statePawChew
            || root.name === root.stateBoxNap
            || root.name === root.stateWallpaperTransform)
            return;

        if (root.hovered) {
            root.name = root.stateWatchingCursor;
            return;
        }

        if (root.musicPlaying) {
            root.awake = true;
            root.name = root.stateMusicReactive;
            return;
        }

        root.name = root.awake ? root.stateIdle : root.stateSleeping;
    }

    function setHovering(value: bool): void {
        root.hovered = value;
        if (value)
            root.awake = true;
        applyBaseState();
    }

    function pet(): void {
        if (root.forcedHidden)
            return;

        root.awake = true;
        root.name = root.statePet;
        petReset.restart();
    }

    function walk(duration: int): void {
        if (root.forcedHidden)
            return;

        root.awake = true;
        root.name = root.stateWalking;
        actionReset.interval = duration;
        actionReset.restart();
    }

    function stare(duration: int): void {
        if (root.forcedHidden)
            return;

        root.awake = true;
        root.name = root.stateStare;
        actionReset.interval = duration;
        actionReset.restart();
    }

    function chew(duration: int): void {
        if (root.forcedHidden)
            return;

        root.awake = true;
        root.name = root.statePawChew;
        actionReset.interval = duration;
        actionReset.restart();
    }

    function lick(duration: int): void {
        if (root.forcedHidden)
            return;

        root.awake = true;
        root.name = root.statePawLick;
        actionReset.interval = duration;
        actionReset.restart();
    }

    function boxNap(): void {
        if (root.forcedHidden)
            return;

        root.awake = false;
        root.name = root.stateBoxNap;
        actionReset.stop();
    }

    function tailPull(active: bool): void {
        if (root.forcedHidden)
            return;

        root.awake = true;
        if (active) {
            root.name = root.stateTailPull;
            actionReset.stop();
        } else {
            actionReset.interval = 900;
            actionReset.restart();
        }
    }

    function toggleSleep(): void {
        if (root.forcedHidden)
            return;

        root.awake = !root.awake;
        root.name = root.awake ? root.stateIdle : root.stateSleeping;
    }

    function transformMood(): void {
        if (root.forcedHidden)
            return;

        const previous = root.name;
        root.name = root.stateWallpaperTransform;
        transformReset.previousState = previous;
        transformReset.restart();
    }

    onMusicPlayingChanged: applyBaseState()
    onForcedHiddenChanged: applyBaseState()

    Timer {
        id: petReset

        interval: 1350
        repeat: false
        onTriggered: root.applyBaseState()
    }

    Timer {
        id: actionReset

        interval: 1200
        repeat: false
        onTriggered: root.applyBaseState()
    }

    Timer {
        id: transformReset

        property string previousState: root.stateIdle

        interval: 900
        repeat: false
        onTriggered: root.applyBaseState()
    }
}
