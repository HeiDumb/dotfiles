pragma ComponentBehavior: Bound

import qs.components.containers
import qs.services
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
    id: inkcatRoot

    property var controller: null

    function callController(action: string): string {
        if (!controller)
            return "inkcat unavailable";

        if (action === "walk")
            return controller.forceWalk();
        if (action === "roam")
            return controller.forceWalk();
        if (action === "chew")
            return controller.forceChew();
        if (action === "lick")
            return controller.forceLick();
        if (action === "attention")
            return controller.forceAttention();
        if (action === "pet")
            return controller.forcePet();
        if (action === "tail")
            return controller.forceTailPull();
        if (action === "nap")
            return controller.forceNap();
        if (action === "home")
            return controller.forceHome();
        return controller.catStatus();
    }

    IpcHandler {
        function walk(): string {
            return inkcatRoot.callController("walk");
        }

        function chew(): string {
            return inkcatRoot.callController("chew");
        }

        function lick(): string {
            return inkcatRoot.callController("lick");
        }

        function roam(): string {
            return inkcatRoot.callController("roam");
        }

        function attention(): string {
            return inkcatRoot.callController("attention");
        }

        function pet(): string {
            return inkcatRoot.callController("pet");
        }

        function tail(): string {
            return inkcatRoot.callController("tail");
        }

        function nap(): string {
            return inkcatRoot.callController("nap");
        }

        function home(): string {
            return inkcatRoot.callController("home");
        }

        function state(): string {
            return inkcatRoot.callController("state");
        }

        target: "inkcat"
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: scope

            required property ShellScreen modelData

            CatConfig {
                id: catConfig
            }

            StyledWindow {
                id: win

                property real cursorX: -1
                property real cursorY: -1
                property real activeWindowX: 0
                property real activeWindowY: 0
                property real activeWindowWidth: 0
                property real activeWindowHeight: 0
                property string activeWindowClass: ""
                property bool activeWindowMapped
                property bool activeWindowHidden: true
                property real chewOverlayX: 0
                property real chewOverlayY: 0
                property bool chewRightEdge
                property string chewTargetClass: ""
                property real chewBiteX: 0
                property real chewBiteY: 0
                property int attentionStep
                property real lastChewTime: 0
                property bool pendingChew
                property bool pendingLick
                property bool chewAfterWindowRefresh
                property real queuedWalkX: 0
                property real queuedWalkY: 0
                property int queuedWalkDuration: 0
                property bool queuedWalkMove

                readonly property var monitor: Hypr.monitorFor(screen)
                readonly property real monitorOffsetX: monitor && monitor.x !== undefined ? monitor.x : 0
                readonly property real monitorOffsetY: monitor && monitor.y !== undefined ? monitor.y : 0

                function localWindowX(value: real): real {
                    return value - monitorOffsetX;
                }

                function localWindowY(value: real): real {
                    return value - monitorOffsetY;
                }

                readonly property var workspace: monitor && monitor.activeWorkspace ? monitor.activeWorkspace : null
                readonly property int workspaceId: workspace ? workspace.id : -1
                readonly property bool hasFullscreen: workspaceId > 0 && Hypr.workspaceHasFullscreen(workspaceId)
                readonly property bool shouldHide: catConfig.safeMode && (GameMode.enabled || hasFullscreen)
                readonly property bool hasActivePlayer: Players.active !== null
                readonly property bool playerPlaying: hasActivePlayer && Players.active.isPlaying
                readonly property bool musicPlaying: playerPlaying || (!hasActivePlayer && Audio.hasPlayback)
                readonly property bool canPlay: catConfig.enabled && !shouldHide && width > 0 && height > 0
                readonly property bool cursorKnown: cursorX >= 0 && cursorY >= 0
                readonly property bool cursorNearCat: cursorKnown && cursorX > cat.x - 360 && cursorX < cat.x + cat.width + 360 && cursorY > cat.y - 280 && cursorY < cat.y + cat.height + 280
                readonly property real catMouthLeftX: 82
                readonly property real catMouthRightInset: 82
                readonly property real catMouthY: 101
                readonly property bool catActing: catState.name !== catState.stateSleeping && catState.name !== catState.stateBoxNap
                readonly property real bedX: 46
                readonly property real bedY: Math.max(0, height - 72)

            screen: scope.modelData
            name: "inkcat"
            color: "transparent"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            surfaceFormat.opaque: false
            mask: CatInputRegion {
                cat: cat
                hidden: !catConfig.enabled || catState.hidden
            }

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Component.onCompleted: {
                if (!inkcatRoot.controller)
                    inkcatRoot.controller = win;
            }

            function clampX(value: real): real {
                return Math.max(-60, Math.min(win.width - cat.width + 60, value));
            }

            function clampY(value: real): real {
                return Math.max(10, Math.min(win.height - cat.height - 10, value));
            }

            function moveCat(valueX: real, valueY: real): void {
                cat.moveTo(clampX(valueX), clampY(valueY));
            }

            function startWalkTo(valueX: real, valueY: real, duration: int, faceRight: bool): int {
                const targetX = clampX(valueX);
                const targetY = clampY(valueY);
                const distanceX = targetX - cat.x;
                const distanceY = targetY - cat.y;
                const travelDistance = Math.sqrt(distanceX * distanceX + distanceY * distanceY);
                const effectiveDuration = Math.max(duration, Math.min(13000, Math.round(travelDistance * 8.2)));

                queuedWalkX = targetX;
                queuedWalkY = targetY;
                queuedWalkDuration = effectiveDuration;
                queuedWalkMove = true;
                cat.facingRight = faceRight;
                cat.walkMoveDuration = effectiveDuration;
                catState.awake = true;
                catState.walk(effectiveDuration + 240);
                walkMoveDelay.restart();
                return effectiveDuration;
            }

            function walkCatRoam(duration: int): int {
                const maxX = Math.max(1, win.width - cat.width - 20);
                const maxY = Math.max(1, win.height - cat.height - 20);
                const targetX = 10 + Math.random() * maxX;
                const targetY = 10 + Math.random() * maxY;
                return startWalkTo(targetX, targetY, duration, targetX > cat.x);
            }

            function walkCatHome(duration: int): int {
                return startWalkTo(win.bedX, Math.max(0, win.bedY - cat.height + 42), duration, false);
            }

            function applyActiveWindowData(data: var): bool {
                if (!data || !data.at || !data.size || data.size.length < 2)
                    return false;

                activeWindowX = localWindowX(data.at[0] || 0);
                activeWindowY = localWindowY(data.at[1] || 0);
                activeWindowWidth = data.size[0] || 0;
                activeWindowHeight = data.size[1] || 0;
                activeWindowClass = data.class || "";
                activeWindowMapped = data.mapped === true;
                activeWindowHidden = data.hidden === true;
                return activeWindowClass.length > 0 && activeWindowWidth > 0 && activeWindowHeight > 0;
            }

            function syncActiveWindowFromHypr(): bool {
                const topLevel = Hypr.activeToplevel;
                if (topLevel && topLevel.lastIpcObject && applyActiveWindowData(topLevel.lastIpcObject))
                    return true;

                if (topLevel && topLevel.address && Hypr.clients) {
                    const activeAddress = `${topLevel.address}`.replace(/^0x/i, "");
                    const match = Hypr.clients.find(client => client && client.address === activeAddress);
                    if (match && match.lastIpcObject && applyActiveWindowData(match.lastIpcObject))
                        return true;
                }

                return activeWindowClass.length > 0 && activeWindowWidth > 0 && activeWindowHeight > 0;
            }

            function isChewableWindowClass(): bool {
                const windowClass = activeWindowClass.toLowerCase();
                return windowClass.length > 0
                    && windowClass.indexOf("steam_app_431960") < 0
                    && windowClass.indexOf("wallpaper") < 0
                    && windowClass.indexOf("linux-wallpaperengine") < 0;
            }

            function walkCatToWindowChew(duration: int): int {
                syncActiveWindowFromHypr();

                if (!isChewableWindowClass() || activeWindowWidth <= 120 || activeWindowHeight <= 120)
                    return 0;

                const catCenterX = cat.x + cat.width / 2;
                const leftDistance = Math.abs(catCenterX - activeWindowX);
                const rightDistance = Math.abs(catCenterX - (activeWindowX + activeWindowWidth));
                const preferRight = rightDistance < leftDistance;
                const edgeX = preferRight ? activeWindowX + activeWindowWidth : activeWindowX;
                const biteX = preferRight ? edgeX - 2 : edgeX + 2;

                const biteY = activeWindowY + Math.max(
                    92,
                    Math.min(activeWindowHeight - 92, activeWindowHeight * 0.16)
                );

                const mouthLocalX = preferRight ? cat.width - catMouthRightInset : catMouthLeftX;
                const mouthLocalY = catMouthY;

                chewRightEdge = preferRight;
                chewTargetClass = activeWindowClass;
                chewBiteX = biteX;
                chewBiteY = biteY;
                chewOverlayX = biteX;
                chewOverlayY = biteY;

                return startWalkTo(biteX - mouthLocalX, biteY - mouthLocalY, duration, preferRight);
            }

            function moveCatHome(): void {
                moveCat(win.bedX, Math.max(0, win.bedY - cat.height + 42));
            }

            function moveCatRoam(): void {
                const maxX = Math.max(1, win.width - cat.width - 20);
                const maxY = Math.max(1, win.height - cat.height - 20);
                moveCat(10 + Math.random() * maxX, 10 + Math.random() * maxY);
            }

            function attentionSeek(): void {
                if (!canPlay || cat.dragging || catState.name === catState.statePet || catState.name === catState.stateTailPull)
                    return;

                attentionStep++;
                if (catConfig.mischiefEnabled && catConfig.mischiefLevel > 1 && Date.now() - lastChewTime > catConfig.chewCooldown) {
                    lastChewTime = Date.now();
                    pendingChew = true;
                    let walkMs = walkCatToWindowChew(catConfig.walkDuration);
                    if (walkMs <= 0) {
                        pendingChew = false;
                        return;
                    }
                    chewDelay.interval = walkMs + 220;
                    chewDelay.restart();
                    return;
                }

                if (attentionStep % 3 === 0) {
                    moveCatHome();
                    catState.boxNap();
                } else if (attentionStep % 2 === 0) {
                    const walkMs = walkCatRoam(catConfig.walkDuration);
                    stareDelay.interval = walkMs + 180;
                    stareDelay.restart();
                } else {
                    const walkMs = walkCatRoam(catConfig.walkDuration);
                    stareDelay.interval = walkMs + 180;
                    stareDelay.restart();
                }
            }

            function forceWalk(): string {
                if (!canPlay)
                    return "blocked: hidden or disabled";

                pendingChew = false;
                pendingLick = false;
                chewTargetClass = "";
                chewDelay.stop();
                lickDelay.stop();
                const walkMs = walkCatRoam(catConfig.walkDuration + 1200);
                stareDelay.interval = walkMs + 180;
                stareDelay.restart();
                return catStatus();
            }

            function forceChew(): string {
                if (!canPlay)
                    return "blocked: hidden or disabled";

                lastChewTime = Date.now();
                pendingLick = false;
                pendingChew = true;
                chewTargetClass = "";
                stareDelay.stop();
                lickDelay.stop();
                let walkMs = walkCatToWindowChew(catConfig.walkDuration);
                if (walkMs <= 0) {
                    chewAfterWindowRefresh = true;
                    if (!activeWindowProc.running)
                        activeWindowProc.running = true;
                    return "queued: refreshing active window";
                }
                chewDelay.interval = walkMs + 220;
                chewDelay.restart();

                return catStatus();
            }

            function forceLick(): string {
                if (!canPlay)
                    return "blocked: hidden or disabled";

                pendingChew = false;
                pendingLick = true;
                chewTargetClass = "";
                stareDelay.stop();
                chewDelay.stop();
                const walkMs = walkCatRoam(catConfig.walkDuration);
                lickDelay.interval = walkMs + 180;
                lickDelay.restart();
                return catStatus();
            }

            function forceAttention(): string {
                attentionSeek();
                return catStatus();
            }

            function forcePet(): string {
                if (!canPlay)
                    return "blocked: hidden or disabled";

                catState.pet();
                return catStatus();
            }

            function forceTailPull(): string {
                if (!canPlay)
                    return "blocked: hidden or disabled";

                cat.tailPulled = true;
                catState.tailPull(true);
                tailIpcRelease.restart();
                return catStatus();
            }

            function forceNap(): string {
                pendingChew = false;
                pendingLick = false;
                chewTargetClass = "";
                stareDelay.stop();
                chewDelay.stop();
                lickDelay.stop();
                moveCatHome();
                catState.boxNap();
                return catStatus();
            }

            function forceHome(): string {
                pendingChew = false;
                pendingLick = false;
                chewTargetClass = "";
                stareDelay.stop();
                chewDelay.stop();
                lickDelay.stop();
                moveCatHome();
                catState.awake = true;
                catState.name = catState.stateIdle;
                return catStatus();
            }

            function catStatus(): string {
                const windowLabel = catState.name === catState.statePawChew || catState.name === catState.stateMischiefChew ? win.chewTargetClass : win.activeWindowClass;
                return `state=${catState.name} x=${Math.round(cat.x)} y=${Math.round(cat.y)} facing=${cat.facingRight ? "right" : "left"} walkMs=${cat.walkMoveDuration} window=${windowLabel || "none"} chewing=${catState.name === catState.statePawChew || catState.name === catState.stateMischiefChew} licking=${catState.name === catState.statePawLick} walking=${catState.name === catState.stateWalking}`;
            }

            Timer {
                id: walkMoveDelay

                interval: 16
                repeat: false
                onTriggered: {
                    if (!win.queuedWalkMove || !win.canPlay)
                        return;

                    win.queuedWalkMove = false;
                    win.moveCat(win.queuedWalkX, win.queuedWalkY);
                }
            }

            Timer {
                id: homeInitDelay

                interval: 140
                repeat: false
                onTriggered: win.moveCatHome()
            }

            Timer {
                id: tailIpcRelease

                interval: 900
                repeat: false
                onTriggered: {
                    cat.tailPulled = false;
                    catState.tailPull(false);
                }
            }

            CatState {
                id: catState

                musicPlaying: win.musicPlaying
                forcedHidden: win.shouldHide || !catConfig.enabled
            }

            CatMood {
                id: catMood

                accent: Colours.palette.m3primary
                onChanged: catState.transformMood()
            }

            CatBed {
                id: bed

                x: win.bedX
                y: win.bedY
                accent: catMood.accent
                occupied: catState.name === catState.stateBoxNap || cat.sleeping
                visible: catConfig.enabled && !win.shouldHide
            }

            CatMischief {
                id: chewMarks

                z: 20
                x: active
                    ? (win.chewRightEdge ? win.chewBiteX - width + 1 : win.chewBiteX - 1)
                    : cat.x + (cat.facingRight ? cat.width - width - 24 : 22)

                y: active
                    ? win.chewBiteY - height / 2 + Math.sin(cat.tailPhase * 5.2) * 0.9
                    : cat.y + 83 + Math.sin(cat.tailPhase * 5.5) * 2

                accent: catMood.accent
                mood: catMood.mood
                phase: cat.tailPhase
                rightEdge: win.chewRightEdge
                active: catState.name === catState.statePawChew && win.chewTargetClass.length > 0
            }

            CatBody {
                id: cat

                catEnabled: catConfig.enabled
                stateName: catState.name
                mood: catMood.mood
                accent: catMood.accent
                musicPlaying: win.musicPlaying
                transforming: catMood.transforming || catState.name === catState.stateWallpaperTransform
                homePosition: catConfig.homePosition
                screenWidth: win.width
                screenHeight: win.height
                globalPointerX: win.cursorX
                globalPointerY: win.cursorY
                frameInterval: catConfig.frameInterval
                breatheSpeed: catConfig.breatheSpeed
                tailSpeed: catConfig.tailSpeed

                onHoverChanged: hovering => catState.setHovering(hovering)
                onPetRequested: catState.pet()
                onSleepToggleRequested: catState.toggleSleep()
                onTailPullChanged: active => catState.tailPull(active)
                onReleasedNearBed: {
                    win.moveCatHome();
                    catState.boxNap();
                }

                Component.onCompleted: homeInitDelay.restart()
            }

            Timer {
                interval: win.cursorNearCat || win.catActing ? catConfig.cursorPollInterval : catConfig.idleCursorPollInterval
                running: win.canPlay
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    if (!cursorProc.running)
                        cursorProc.running = true;
                }
            }

            Process {
                id: cursorProc

                command: ["/usr/bin/hyprctl", "cursorpos"]
                stdout: StdioCollector {
                    id: cursorOut
                }

                onExited: code => {
                    if (code !== 0)
                        return;

                    const parts = cursorOut.text.trim().split(",");
                    if (parts.length < 2)
                        return;

                    const nextX = parseFloat(parts[0]);
                    const nextY = parseFloat(parts[1]);
                    if (!isNaN(nextX) && !isNaN(nextY)) {
                        win.cursorX = nextX;
                        win.cursorY = nextY;
                    }
                }
            }

            Timer {
                interval: catConfig.activeWindowPollInterval
                running: win.canPlay
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    if (!activeWindowProc.running)
                        activeWindowProc.running = true;
                }
            }

            Process {
                id: activeWindowProc

                command: ["/usr/bin/hyprctl", "-j", "activewindow"]
                stdout: StdioCollector {
                    id: activeWindowOut
                }

                onExited: code => {
                    if (code !== 0)
                        return;

                    try {
                        const data = JSON.parse(activeWindowOut.text);
                        win.applyActiveWindowData(data);
                    } catch (error) {
                        win.activeWindowWidth = 0;
                        win.activeWindowHeight = 0;
                        win.activeWindowClass = "";
                        win.activeWindowMapped = false;
                        win.activeWindowHidden = true;
                    }

                    if (win.chewAfterWindowRefresh) {
                        win.chewAfterWindowRefresh = false;
                        const walkMs = win.walkCatToWindowChew(catConfig.walkDuration);
                        if (walkMs > 0) {
                            win.pendingChew = true;
                            chewDelay.interval = walkMs + 220;
                            chewDelay.restart();
                        } else {
                            win.pendingChew = false;
                        }
                    }
                }
            }

            Timer {
                interval: catConfig.attentionInterval
                running: win.canPlay
                repeat: true
                onTriggered: win.attentionSeek()
            }

            Timer {
                interval: catConfig.firstAttentionDelay
                running: win.canPlay
                repeat: false
                onTriggered: win.attentionSeek()
            }

            Timer {
                id: stareDelay

                interval: catConfig.walkDuration
                repeat: false
                onTriggered: catState.stare(catConfig.attentionDuration)
            }

            Timer {
                id: chewDelay

                interval: catConfig.walkDuration
                repeat: false
                onTriggered: {
                    if (win.pendingChew && win.canPlay && !cat.dragging) {
                        win.pendingChew = false;
                        catState.chew(catConfig.chewDuration);
                    }
                }
            }

            Timer {
                id: lickDelay

                interval: catConfig.walkDuration
                repeat: false
                onTriggered: {
                    if (win.pendingLick && win.canPlay && !cat.dragging) {
                        win.pendingLick = false;
                        catState.lick(catConfig.lickDuration);
                    }
                }
            }
        }
    }
}
}
