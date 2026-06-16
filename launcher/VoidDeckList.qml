pragma ComponentBehavior: Bound

import "items"
import "services"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.config
import qs.services
import Quickshell
import QtQuick

Item {
    id: root

    required property StyledTextField search
    required property PersistentProperties visibilities

    property Component delegate: appItem
    property int deckCurrentIndex
    property int activeGrabIndex: -1
    property bool draggingClump

    readonly property bool deckMode: state === "apps" && search.text.length === 0
    readonly property bool listMode: !deckMode
    readonly property int deckLimit: 220
    readonly property int count: deckMode ? deckModel.values.length : searchList.count
    readonly property var currentItem: deckMode ? deckRepeater.itemAt(Math.max(0, Math.min(deckCurrentIndex, deckRepeater.count - 1))) : searchList.currentItem

    property real deckProgress

    implicitWidth: deckMode ? Math.min(1880, Math.max(1560, Config.launcher.sizes.itemWidth * 2.85)) : Config.launcher.sizes.itemWidth
    implicitHeight: deckMode ? Math.min(1040, Math.max(900, Config.launcher.sizes.itemHeight * 15.2)) : (Config.launcher.sizes.itemHeight + Appearance.spacing.small) * Math.min(Config.launcher.maxShown, searchList.count) - Appearance.spacing.small
    clip: false

    state: {
        const text = search.text;
        const prefix = Config.launcher.actionPrefix;
        if (text.startsWith(prefix)) {
            for (const action of ["calc", "scheme", "variant"])
                if (text.startsWith(`${prefix}${action} `))
                    return action;

            return "actions";
        }

        return "apps";
    }

    function incrementCurrentIndex(): void {
        if (deckMode)
            deckCurrentIndex = Math.min(deckModel.values.length - 1, deckCurrentIndex + 1);
        else
            searchList.incrementCurrentIndex();
    }

    function decrementCurrentIndex(): void {
        if (deckMode)
            deckCurrentIndex = Math.max(0, deckCurrentIndex - 1);
        else
            searchList.decrementCurrentIndex();
    }

    function resetRummage(): void {
        for (let i = 0; i < deckRepeater.count; i++) {
            const card = deckRepeater.itemAt(i);
            if (!card)
                continue;
            card.offsetX = 0;
            card.offsetY = 0;
            card.rotationOffset = 0;
            card.lift = 0;
            card.grabStrength = 0;
        }
    }

    function textFor(entry: var): string {
        return [
            entry?.id ?? "",
            entry?.name ?? "",
            entry?.genericName ?? "",
            entry?.comment ?? "",
            entry?.execString ?? "",
            (entry?.command ?? []).join(" ")
        ].join(" ").toLowerCase();
    }

    function categoriesFor(entry: var): list<string> {
        return (entry?.categories ?? []).map(c => `${c}`.toLowerCase());
    }

    function hasAnyCategory(entry: var, categories: list<string>): bool {
        const entryCategories = categoriesFor(entry);
        return categories.some(c => entryCategories.includes(c.toLowerCase()));
    }

    function isFavourite(entry: var): bool {
        if (!entry)
            return false;

        const id = `${entry.id ?? ""}`.toLowerCase();
        return Config.launcher.favouriteApps.some(pattern => {
            const lowered = `${pattern}`.toLowerCase();
            return id === lowered || id.includes(lowered) || lowered.includes(id.replace(/\.desktop$/, ""));
        });
    }

    function isDeckApp(entry: var): bool {
        if (!entry)
            return false;

        if (isFavourite(entry))
            return true;

        const text = textFor(entry);
        const blockedWords = [
            "settings", "preferences", "control center", "control-centre", "controlcenter",
            "configuration", "configurator", "tweaks", "tweak tool", "policykit", "polkit",
            "driver", "firmware", "printer", "cups", "avahi", "qt5ct", "qt6ct", "kvantum",
            "ibus", "fcitx", "input method", "mime", "file type", "about ", "manual",
            "documentation", "help", "logs", "journal", "system monitor", "partition",
            "disk utility", "users and groups", "power management", "color management",
            "bluetooth adapter", "network connections", "nvidia settings", "wallpaper"
        ];

        if (blockedWords.some(word => text.includes(word)))
            return false;

        if (hasAnyCategory(entry, ["settings", "system", "utility"]))
            return false;

        return true;
    }

    function deckApps(): list<var> {
        return Apps.search("").filter(entry => isDeckApp(entry)).slice(0, deckLimit);
    }

    function syncDeckProgress(): void {
        const opening = deckMode && visibilities.launcher;
        deckProgressAnim.stop();
        deckProgressAnim.from = deckProgress;
        deckProgressAnim.to = opening ? 1 : 0;
        deckProgressAnim.duration = 1380;
        deckProgressAnim.easing.type = opening ? Easing.OutCubic : Easing.InCubic;
        deckProgressAnim.restart();
    }

    function beginClump(index: int, mouseX: real, mouseY: real): void {
        activeGrabIndex = index;
        draggingClump = true;
        const grabRadius = Math.max(260, Math.min(width, height) * 0.32);

        for (let i = 0; i < deckRepeater.count; i++) {
            const card = deckRepeater.itemAt(i);
            if (!card)
                continue;

            const cx = card.x + card.width / 2;
            const cy = card.y + card.height / 2;
            const vx = cx - mouseX;
            const vy = cy - mouseY;
            const dist = Math.sqrt(vx * vx + vy * vy);

            let strength = dist < grabRadius ? Math.pow(1 - dist / grabRadius, 0.48) : 0;
            if (index === card.index)
                strength = 1.18;

            card.grabStrength = strength < 0.12 ? 0 : strength;
            if (card.grabStrength > 0)
                card.lift = Math.max(card.lift, index === card.index ? 28 : 12 + card.grabStrength * 14);
        }
    }

    function endClump(): void {
        activeGrabIndex = -1;
        draggingClump = false;
        for (let i = 0; i < deckRepeater.count; i++) {
            const card = deckRepeater.itemAt(i);
            if (card)
                card.grabStrength = 0;
        }
    }

    function dragClump(mouseX: real, mouseY: real, dx: real, dy: real): void {
        for (let i = 0; i < deckRepeater.count; i++) {
            const card = deckRepeater.itemAt(i);
            if (!card || card.grabStrength <= 0)
                continue;

            const strength = card.grabStrength;

            card.offsetX = Math.max(-820, Math.min(820, card.offsetX + dx * strength));
            card.offsetY = Math.max(-620, Math.min(620, card.offsetY + dy * strength));
            card.rotationOffset = Math.max(-18, Math.min(18, card.rotationOffset + (dx * 0.01 + dy * 0.004) * strength));
            card.lift = Math.max(card.lift, 14 + strength * 16);
        }
    }

    onStateChanged: {
        if (state === "scheme" || state === "variant")
            Schemes.reload();
    }

    onDeckModeChanged: {
        resetRummage();
        syncDeckProgress();
    }

    Connections {
        target: root.visibilities

        function onLauncherChanged(): void {
            root.syncDeckProgress();
        }
    }

    Component.onCompleted: syncDeckProgress()

    NumberAnimation {
        id: deckProgressAnim

        target: root
        property: "deckProgress"
        from: root.deckProgress
    }

    ScriptModel {
        id: searchModel

        onValuesChanged: {
            searchList.currentIndex = 0;
            root.deckCurrentIndex = 0;
            root.resetRummage();
        }
    }

    ScriptModel {
        id: deckModel

        values: root.deckApps()

        onValuesChanged: {
            root.deckCurrentIndex = 0;
            root.resetRummage();
        }
    }

    states: [
        State {
            name: "apps"

            PropertyChanges {
                searchModel.values: Apps.search(root.search.text)
                deckModel.values: root.deckApps()
                root.delegate: appItem
            }
        },
        State {
            name: "actions"

            PropertyChanges {
                searchModel.values: Actions.query(root.search.text)
                root.delegate: actionItem
            }
        },
        State {
            name: "calc"

            PropertyChanges {
                searchModel.values: [0]
                root.delegate: calcItem
            }
        },
        State {
            name: "scheme"

            PropertyChanges {
                searchModel.values: Schemes.query(root.search.text)
                root.delegate: schemeItem
            }
        },
        State {
            name: "variant"

            PropertyChanges {
                searchModel.values: M3Variants.query(root.search.text)
                root.delegate: variantItem
            }
        }
    ]

    Item {
        id: deck

        anchors.fill: parent
        visible: root.deckProgress > 0
        opacity: root.deckProgress
        scale: 0.97 + root.deckProgress * 0.03
        clip: false

        readonly property real originX: width / 2
        readonly property real originY: height - 16
        readonly property real portalPulse: Math.sin(root.deckProgress * Math.PI)
        readonly property var xSlots: [0.16, 0.24, 0.33, 0.42, 0.51, 0.59, 0.68, 0.77, 0.84, 0.21, 0.3, 0.39, 0.48, 0.57, 0.66, 0.74, 0.28, 0.37, 0.46, 0.55, 0.64, 0.72, 0.35, 0.53]
        readonly property var ySlots: [0.2, 0.31, 0.24, 0.38, 0.27, 0.44, 0.34, 0.5, 0.41, 0.57, 0.47, 0.64, 0.54, 0.7, 0.61, 0.76, 0.68, 0.32, 0.73, 0.39, 0.58, 0.46, 0.67, 0.52]
        readonly property var rotations: [-17, 11, -6, 18, -13, 7, -20, 14, -9, 16, -15, 5, -4, 19, -11, 9]
        readonly property var xDrift: [0, -0.046, 0.037, -0.026, 0.052, -0.034, 0.018, -0.057]
        readonly property var yDrift: [0, 0.044, -0.036, 0.067, -0.02, 0.031, -0.052, 0.018]

        function slotFor(index: int): var {
            const layer = Math.floor(index / xSlots.length);
            const pos = index % xSlots.length;
            const depthBias = ((pos * 7 + layer * 3) % 9) * 2;
            const favourite = index < Config.launcher.favouriteApps.length;
            const hiddenLayer = layer > 1;
            const spreadX = ((layer % 5) - 2) * 0.014 + (pos % 2 === 0 ? -0.01 : 0.012);
            const spreadY = ((layer % 6) - 2.5) * 0.018 + (pos % 3 === 0 ? 0.026 : -0.008);
            const branchSpread = [-0.18, -0.12, -0.065, -0.025, 0.025, 0.065, 0.12, 0.18][pos % 8];
            const branchReach = 0.5 + Math.min(layer, 7) * 0.08;

            return {
                trunkYRatio: 0.82,
                branchXRatio: Math.max(0.2, Math.min(0.8, 0.5 + branchSpread * branchReach)),
                branchYRatio: Math.max(0.24, Math.min(0.76, 0.8 - Math.min(layer, 7) * 0.065 - (pos % 4) * 0.026)),
                endXRatio: Math.max(0.07, Math.min(0.93, xSlots[pos] + xDrift[layer % xDrift.length] + spreadX)),
                endYRatio: Math.max(0.12, Math.min(0.88, ySlots[(pos * 5 + layer * 7) % ySlots.length] + yDrift[layer % yDrift.length] + spreadY)),
                scale: favourite ? 1.14 : Math.max(0.52, 1.02 - Math.min(layer, 8) * 0.046 + (pos % 5) * 0.03),
                rotation: rotations[(pos + layer * 2) % rotations.length],
                z: Math.max(4, 128 - layer * 7 + depthBias),
                arcHeight: Math.max(95, 225 - layer * 14 + (pos % 5) * 8),
                delay: Math.min(0.64, 0.018 + index * 0.011),
                branchStart: 0.58,
                mass: favourite ? 1.28 : hiddenLayer ? 0.72 : 0.92,
                startRotation: rotations[(pos + 5) % rotations.length] * -1.7
            };
        }

        Item {
            id: portal

            readonly property real portalScale: 0.58 + root.deckProgress * 0.34 + deck.portalPulse * 0.08

            width: 128
            height: 104
            x: deck.originX - width / 2
            y: parent.height - height + 6
            opacity: root.deckProgress <= 0 ? 0 : Math.min(1, root.deckProgress * 1.8)
            scale: portalScale
            transformOrigin: Item.Bottom
            z: 1
            visible: opacity > 0

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                width: parent.width * 0.92
                height: 30
                radius: height / 2
                color: "transparent"
                border.width: 2
                border.color: Qt.alpha(Colours.palette.m3primary, 0.72)
                opacity: 0.92
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                width: parent.width * 0.56
                height: 12
                radius: height / 2
                color: Qt.alpha(Colours.palette.m3primary, 0.28 + deck.portalPulse * 0.16)
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3tertiary, 0.58)
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: parent.width * 0.3
                height: 28
                radius: 14
                color: Qt.alpha(Colours.palette.m3primary, 0.12 + deck.portalPulse * 0.08)
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3primary, 0.42)
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 22
                width: 18
                height: 76
                radius: width / 2
                opacity: 0.34 + deck.portalPulse * 0.18
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.65; color: Qt.alpha(Colours.palette.m3tertiary, 0.16) }
                    GradientStop { position: 1; color: Qt.alpha(Colours.palette.m3primary, 0.42) }
                }
                z: -1
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                width: parent.width * 1.18
                height: 40
                radius: height / 2
                color: Qt.alpha(Colours.palette.m3primary, 0.06)
                opacity: 0.64
                z: -1
            }
        }

        function beginClump(index: int, mouseX: real, mouseY: real): void {
            root.beginClump(index, mouseX, mouseY);
        }

        function dragClump(mouseX: real, mouseY: real, dx: real, dy: real): void {
            root.dragClump(mouseX, mouseY, dx, dy);
        }

        function endClump(): void {
            root.endClump();
        }

        MouseArea {
            id: deckBrush

            property real lastX
            property real lastY

            anchors.fill: parent
            enabled: root.visibilities.launcher
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton

            onPressed: mouse => {
                lastX = mouse.x;
                lastY = mouse.y;
                deck.beginClump(-1, mouse.x, mouse.y);
            }

            onPositionChanged: mouse => {
                if (!pressed)
                    return;

                deck.dragClump(mouse.x, mouse.y, mouse.x - lastX, mouse.y - lastY);
                lastX = mouse.x;
                lastY = mouse.y;
            }

            onReleased: deck.endClump()
            onCanceled: deck.endClump()
        }

        Repeater {
            id: deckRepeater

            model: deckModel.values

            VoidDeckCard {
                id: card

                visibilities: root.visibilities
                slot: deck.slotFor(card.index)
                deckProgress: root.deckProgress
                originX: deck.originX
                originY: deck.originY
                selected: root.deckCurrentIndex === card.index
            }
        }
    }

    StyledListView {
        id: searchList

        anchors.fill: parent
        visible: root.listMode
        opacity: root.listMode ? 1 : 0
        scale: root.listMode ? 1 : 0.94
        model: searchModel
        spacing: Appearance.spacing.small
        orientation: Qt.Vertical
        implicitHeight: (Config.launcher.sizes.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing

        preferredHighlightBegin: 0
        preferredHighlightEnd: height
        highlightRangeMode: ListView.ApplyRange

        highlightFollowsCurrentItem: false
        highlight: StyledRect {
            radius: Appearance.rounding.normal
            color: Colours.tPalette.m3surfaceContainerHighest
            opacity: 0.72

            y: searchList.currentItem?.y ?? 0
            implicitWidth: searchList.width
            implicitHeight: searchList.currentItem?.implicitHeight ?? 0

            Behavior on y {
                Anim {
                    duration: Appearance.anim.durations.expressiveDefaultSpatial
                    easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                }
            }
        }

        delegate: root.delegate

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: searchList
        }

        add: Transition {
            enabled: !root.state

            Anim {
                properties: "opacity,scale"
                from: 0
                to: 1
            }
        }

        remove: Transition {
            enabled: !root.state

            Anim {
                properties: "opacity,scale"
                from: 1
                to: 0
            }
        }

        move: Transition {
            Anim {
                property: "y"
            }
            Anim {
                properties: "opacity,scale"
                to: 1
            }
        }

        addDisplaced: Transition {
            Anim {
                property: "y"
                duration: Appearance.anim.durations.small
            }
            Anim {
                properties: "opacity,scale"
                to: 1
            }
        }

        displaced: Transition {
            Anim {
                property: "y"
            }
            Anim {
                properties: "opacity,scale"
                to: 1
            }
        }

        Behavior on opacity {
            Anim {
                duration: Appearance.anim.durations.small
            }
        }

        Behavior on scale {
            Anim {
                duration: Appearance.anim.durations.small
            }
        }
    }

    Timer {
        interval: 16
        repeat: true
        running: root.deckMode && root.visibilities.launcher
        onTriggered: {
            for (let i = 0; i < deckRepeater.count; i++) {
                const card = deckRepeater.itemAt(i);
                if (!card)
                    continue;

                if (!root.draggingClump) {
                    card.offsetX *= 0.985;
                    card.offsetY *= 0.985;
                    card.rotationOffset *= 0.965;
                }
                card.lift *= 0.9;
            }
        }
    }

    transitions: Transition {
        SequentialAnimation {
            ParallelAnimation {
                Anim {
                    target: searchList
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardAccel
                }
                Anim {
                    target: searchList
                    property: "scale"
                    from: 1
                    to: 0.9
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardAccel
                }
            }
            PropertyAction {
                targets: [searchModel, root]
                properties: "values,delegate"
            }
            ParallelAnimation {
                Anim {
                    target: searchList
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
                Anim {
                    target: searchList
                    property: "scale"
                    from: 0.9
                    to: 1
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
            }
        }
    }

    Component {
        id: appItem

        AppItem {
            visibilities: root.visibilities
        }
    }

    Component {
        id: actionItem

        ActionItem {
            list: root
        }
    }

    Component {
        id: calcItem

        CalcItem {
            list: root
        }
    }

    Component {
        id: schemeItem

        SchemeItem {
            list: root
        }
    }

    Component {
        id: variantItem

        VariantItem {
            list: root
        }
    }
}
