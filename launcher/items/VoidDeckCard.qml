import "../services"
import qs.components
import qs.config
import qs.services
import qs.utils
import Quickshell
import Quickshell.Widgets
import QtQuick

Item {
    id: root

    required property int index
    required property var modelData
    required property PersistentProperties visibilities
    required property var slot
    required property real deckProgress
    required property real originX
    required property real originY
    property bool selected
    property real offsetX
    property real offsetY
    property real rotationOffset
    property real lift
    property real grabStrength
    readonly property Item launchSourceItem: root

    readonly property bool hovered: mouse.containsMouse
    readonly property bool favourite: !!modelData && Strings.testRegexList(Config.launcher.favouriteApps, modelData.id)
    readonly property real mass: slotValue("mass", 1)
    readonly property real targetScale: Math.max(slotValue("scale", 0.86), favourite ? 1.08 : 0.68)
    readonly property real openProgress: clamp((deckProgress - slotValue("delay", 0)) / Math.max(0.01, 1 - slotValue("delay", 0)), 0, 1)
    readonly property real travelProgress: openProgress
    readonly property real easedProgress: easeOutCubic(travelProgress)
    readonly property real branchStart: slotValue("branchStart", 0.58)
    readonly property real trunkProgress: clamp(travelProgress / branchStart, 0, 1)
    readonly property real fanProgress: clamp((travelProgress - branchStart) / Math.max(0.01, 1 - branchStart), 0, 1)
    readonly property real fanEase: easeOutCubic(fanProgress)
    readonly property real trunkEase: smooth(trunkProgress)
    readonly property real scaleProgress: smooth(clamp(travelProgress / 0.34, 0, 1))
    readonly property real depth: slotValue("z", 30)
    readonly property real deckWidth: parent?.width ?? 1
    readonly property real deckHeight: parent?.height ?? 1
    readonly property real trunkY: slotValue("trunkYRatio", 0.82) * deckHeight
    readonly property real branchX: slotValue("branchXRatio", 0.5) * deckWidth
    readonly property real branchY: slotValue("branchYRatio", 0.58) * deckHeight
    readonly property real endX: slotValue("endXRatio", 0.5) * deckWidth
    readonly property real endY: slotValue("endYRatio", 0.5) * deckHeight
    readonly property real centerX: fanProgress <= 0 ? originX : cubic(originX, branchX, branchX, endX, fanEase)
    readonly property real centerY: fanProgress <= 0 ? lerp(originY, trunkY, trunkEase) : cubic(trunkY, branchY, branchY, endY, fanEase)
    readonly property real visualScale: (hovered || selected ? targetScale * 1.08 : targetScale) * (1 + Math.min(0.1, lift * 0.004)) * (0.08 + 0.92 * scaleProgress)
    readonly property real readableRotation: hovered || selected ? 0 : slotValue("rotation", 0) + rotationOffset * deckProgress

    implicitWidth: favourite ? 92 : 74
    implicitHeight: implicitWidth
    width: implicitWidth
    height: implicitHeight
    transformOrigin: Item.Center

    x: centerX - width / 2 + offsetX * fanEase
    y: centerY - height / 2 + offsetY * fanEase
    scale: visualScale
    rotation: lerp(slotValue("startRotation", -18), readableRotation, easedProgress)
    opacity: travelProgress <= 0.01 ? 0 : Math.min(1, travelProgress * 3)
    z: hovered || selected ? 1200 : depth + lift
    visible: opacity > 0

    function slotValue(key: string, fallback: real): real {
        return root.slot && root.slot[key] !== undefined ? root.slot[key] : fallback;
    }

    function clamp(value: real, min: real, max: real): real {
        return Math.max(min, Math.min(max, value));
    }

    function lerp(a: real, b: real, t: real): real {
        return a + (b - a) * t;
    }

    function cubic(a: real, b: real, c: real, d: real, t: real): real {
        const u = 1 - t;
        return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d;
    }

    function smooth(t: real): real {
        return t * t * (3 - 2 * t);
    }

    function easeOutBack(t: real): real {
        const c1 = 1.70158;
        const c3 = c1 + 1;
        return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
    }

    function easeInCubic(t: real): real {
        return t * t * t;
    }

    function easeOutCubic(t: real): real {
        return 1 - Math.pow(1 - t, 3);
    }

    function arcY(startY: real, finishY: real, t: real, arcHeight: real): real {
        return lerp(startY, finishY, easeOutCubic(t)) - Math.sin(t * Math.PI) * arcHeight;
    }

    Behavior on scale {
        Anim {
            duration: Appearance.anim.durations.small
            easing.bezierCurve: Appearance.anim.curves.standardDecel
        }
    }

    Behavior on rotation {
        Anim {
            duration: Appearance.anim.durations.small
            easing.bezierCurve: Appearance.anim.curves.standardDecel
        }
    }

    IconImage {
        asynchronous: true
        source: Quickshell.iconPath(root.modelData?.icon, "image-missing")
        implicitSize: parent.width * (root.favourite ? 0.82 : 0.78)
        opacity: root.hovered || root.selected || root.grabStrength > 0 ? 1 : 0.92

        anchors.centerIn: parent

        Behavior on opacity {
            Anim {
                duration: Appearance.anim.durations.small
            }
        }
    }

    MouseArea {
        id: mouse

        property real lastDeckX
        property real lastDeckY
        property bool dragged

        anchors.fill: parent
        enabled: root.visibilities.launcher
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: event => {
            const deckPoint = root.mapToItem(root.parent, event.x, event.y);
            lastDeckX = deckPoint.x;
            lastDeckY = deckPoint.y;
            dragged = false;
            if (root.parent && root.parent.beginClump)
                root.parent.beginClump(root.index, deckPoint.x, deckPoint.y);
        }

        onPositionChanged: event => {
            if (!pressed || !root.parent || !root.parent.dragClump)
                return;

            const deckPoint = root.mapToItem(root.parent, event.x, event.y);
            const dx = deckPoint.x - lastDeckX;
            const dy = deckPoint.y - lastDeckY;
            if (Math.abs(dx) + Math.abs(dy) > 3)
                dragged = true;

            root.parent.dragClump(deckPoint.x, deckPoint.y, dx, dy);
            lastDeckX = deckPoint.x;
            lastDeckY = deckPoint.y;
        }

        onReleased: {
            if (root.parent && root.parent.endClump)
                root.parent.endClump();
        }

        onCanceled: {
            if (root.parent && root.parent.endClump)
                root.parent.endClump();
        }

        onClicked: {
            if (dragged)
                return;

            Apps.launch(root.modelData, root);
            root.visibilities.launcher = false;
        }
    }
}
