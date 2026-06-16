pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Region {
    id: root

    required property var bar
    required property var panels
    required property var visibilities
    required property var win

    // Do NOT use win.contentItem.Config here.
    // In this TopBar drawer setup it can be undefined during mask creation.
    readonly property real borderThickness: Math.max(1, win.borderThickness || 1)
    readonly property real sidehubDragStrip: 56
    readonly property real edgeHotspot: 24
    readonly property real dragPad: win.dragMaskPadding || 0
    readonly property bool mangaVisible: !!(visibilities && visibilities.weebcentral)
    readonly property real rightInset: sidehubDragStrip

    readonly property real topInset: Math.max(
        edgeHotspot,
        win.panelTopMargin || 0,
        bar ? (bar.contentHeight || bar.implicitHeight || bar.height || 0) : 0
    )

    // XOR root means the inner app area is click-through,
    // while top/left/right/bottom edge strips stay interactive.
    x: edgeHotspot + dragPad
    y: topInset + dragPad
    width: Math.max(0, win.width - edgeHotspot - rightInset - dragPad * 2)
    height: Math.max(0, win.height - topInset - edgeHotspot - dragPad * 2)
    intersection: Intersection.Xor

    function ok(item) {
        return item !== null && item !== undefined;
    }

    function iw(item) {
        return ok(item) ? Math.max(item.width || 0, item.implicitWidth || 0) : 0;
    }

    function ih(item) {
        return ok(item) ? Math.max(item.height || 0, item.implicitHeight || 0) : 0;
    }

    function off(item) {
        return ok(item) && item.offsetScale !== undefined ? item.offsetScale : 0;
    }

    function shown(item) {
        return ok(item) && (item.visible || off(item) < 1);
    }

    function px(item) {
        return ok(item) && panels ? panels.x + item.x : 0;
    }

    function py(item) {
        return ok(item) && panels ? panels.y + item.y : 0;
    }

    PanelRegion {
        panel: root.panels ? root.panels.dashboard : null
    }

    PanelRegion {
        panel: root.panels ? root.panels.controlCenter : null
    }

    PanelRegion {
        panel: root.panels ? root.panels.launcher : null
        activeWhenShown: !!(root.visibilities && root.visibilities.launcher)
    }

    PanelRegion {
        panel: root.panels ? root.panels.sessionWrapper : null
    }

    PanelRegion {
        panel: root.panels ? root.panels.sidebar : null
    }

    PanelRegion {
        panel: root.panels ? root.panels.utilities : null
    }

    PanelRegion {
        panel: root.panels ? root.panels.yin : null
    }

    PanelRegion {
        panel: root.panels ? root.panels.notifications : null
    }

    PanelRegion {
        panel: root.panels ? root.panels.osdWrapper : null
    }

    PanelRegion {
        panel: root.panels ? root.panels.popouts : null
        activeOverride: root.panels && root.panels.popouts ? root.panels.popouts.hasCurrent : false
    }

    PopoutBridgeRegion {
        panel: root.panels ? root.panels.popouts : null
        activeOverride: root.panels && root.panels.popouts ? root.panels.popouts.hasCurrent : false
    }

    component PanelRegion: Region {
        required property var panel
        property bool activeOverride: false
        property bool activeWhenShown: true

        readonly property bool active: activeOverride || (activeWhenShown && root.shown(panel))

        x: active ? root.px(panel) : 0
        y: active ? root.py(panel) : 0
        width: active ? root.iw(panel) : 0
        height: active ? root.ih(panel) : 0

        intersection: Intersection.Subtract
    }

    component PopoutBridgeRegion: Region {
        required property var panel
        property bool activeOverride: false

        readonly property bool active: activeOverride && root.ok(panel)
        readonly property real pad: root.edgeHotspot * 2
        readonly property real panelX: root.px(panel)
        readonly property real panelY: root.py(panel)

        x: active ? Math.max(0, panelX - pad) : 0
        y: active ? root.topInset : 0
        width: active ? root.iw(panel) + pad * 2 : 0
        height: active ? Math.max(0, panelY - root.topInset + pad) : 0

        intersection: Intersection.Subtract
    }
}
