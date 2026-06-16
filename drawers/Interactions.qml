pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.bar.popouts as BarPopouts

CustomMouseArea {
    id: root

    required property ShellScreen screen
    required property BarPopouts.Wrapper popouts
    required property DrawerVisibilities visibilities
    required property var panels
    required property var bar
    required property real borderThickness
    required property bool fullscreen

    property point dragStart: Qt.point(0, 0)
    property bool sidehubEnteredAfterDrag
    property bool sidehubOpenedByDrag
    property bool dashboardShortcutActive
    property bool osdShortcutActive
    property bool launcherShortcutActive
    property bool sidehubSyncing
    property bool sidehubDragArmed
    property real lastMouseX
    property real lastMouseY

    readonly property real sidehubDragStrip: 56
    readonly property real edgeHotspot: 24
    readonly property real topbarHeight: Math.max(
        edgeHotspot,
        bar ? (bar.contentHeight || bar.implicitHeight || bar.height || 0) : 0
    )

    anchors.fill: parent
    acceptedButtons: fullscreen ? Qt.NoButton : Qt.AllButtons
    hoverEnabled: true
    cursorShape: cursorFor(mouseX, mouseY)

    function closeKeyboardDrawer() {
        if (visibilities.launcher)
            visibilities.launcher = false;
        else if (visibilities.session)
            visibilities.session = false;
        else if (visibilities.controlCenter)
            visibilities.controlCenter = false;
        else if (visibilities.dashboard)
            visibilities.dashboard = false;
    }

    function ready() {
        return !!(panels && bar && popouts && visibilities);
    }

    function cursorFor(x, y) {
        if (!ready() || fullscreen)
            return Qt.ArrowCursor;

        if (inTopPopoutSafeArea(x, y)
                || inDashboardHotspot(x, y)
                || inLauncherHotspot(x, y)
                || inRightSessionHotspot(x, y)
                || inSidebarHotspot(x, y)
                || inSidehubHotspot(x, y))
            return pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor;

        return Qt.ArrowCursor;
    }

    function w(item) {
        return item ? Math.max(item.width || 0, item.implicitWidth || 0) : 0;
    }

    function h(item) {
        return item ? Math.max(item.height || 0, item.implicitHeight || 0) : 0;
    }

    function off(item) {
        return item && item.offsetScale !== undefined ? item.offsetScale : 0;
    }

    function px(item) {
        return item && panels ? panels.x + item.x : 0;
    }

    function py(item) {
        return item && panels ? panels.y + item.y : 0;
    }

    function visibleW(item) {
        return w(item) * (1 - off(item));
    }

    function visibleH(item) {
        return h(item) * (1 - off(item));
    }

    function withinPanelHeight(panel, x, y) {
        if (!panel)
            return false;

        const y0 = py(panel);
        return h(panel) > 0 && y >= y0 - Config.border.rounding && y <= y0 + h(panel) + Config.border.rounding;
    }

    function withinPanelWidth(panel, x, y) {
        if (!panel)
            return false;

        const x0 = px(panel);
        return w(panel) > 0 && x >= x0 - Config.border.rounding && x <= x0 + w(panel) + Config.border.rounding;
    }

    function inRect(panel, x, y) {
        return withinPanelWidth(panel, x, y) && withinPanelHeight(panel, x, y);
    }

    function mangaVisible() {
        return !!(visibilities && visibilities.weebcentral);
    }

    function inTopPopoutBridge(x, y) {
        if (!popouts?.hasCurrent || popouts.isDetached || !panels?.popouts)
            return false;

        const panel = panels.popouts;
        const pad = Math.max(Config.border.rounding * 1.5, edgeHotspot);
        const x0 = px(panel) - pad;
        const x1 = px(panel) + w(panel) + pad;
        const y0 = topbarHeight - pad;
        const y1 = py(panel) + pad;

        return w(panel) > 0 && h(panel) > 0 && x >= x0 && x <= x1 && y >= y0 && y <= y1;
    }

    function inTopPopoutSafeArea(x, y) {
        return inRect(panels.popouts, x, y) || popouts.hovered || inTopPopoutBridge(x, y);
    }


    function inPanelRect(panel, x, y) {
        return inRect(panel, x, y);
    }

    function inTopPanel(panel, x, y) {
        if (!panel)
            return false;

        const activeH = Math.max(edgeHotspot, visibleH(panel));
        return y <= py(panel) + activeH + Config.border.rounding && withinPanelWidth(panel, x, y);
    }

    function inBottomPanel(panel, x, y) {
        if (!panel)
            return false;

        const activeH = Math.max(edgeHotspot, visibleH(panel));
        return y >= py(panel) + h(panel) - activeH - Config.border.rounding && withinPanelWidth(panel, x, y);
    }

    function inRightPanel(panel, x, y) {
        if (!panel)
            return false;

        const activeW = Math.max(edgeHotspot, visibleW(panel));
        return x >= px(panel) + w(panel) - activeW - Config.border.rounding
            && withinPanelHeight(panel, x, y);
    }

    function inDashboardHotspot(x, y) {
        return x <= edgeHotspot || inTopPanel(panels.dashboard, x, y);
    }

    function inLauncherHotspot(x, y) {
        return y >= height - edgeHotspot || inBottomPanel(panels.launcher, x, y);
    }

    function inRightSessionHotspot(x, y) {
        return x >= width - edgeHotspot || inRightPanel(panels.sessionWrapper, x, y);
    }

    Shortcut {
        sequence: "Esc"
        enabled: root.visibilities.launcher || root.visibilities.session || root.visibilities.controlCenter || root.visibilities.dashboard
        context: Qt.ApplicationShortcut
        onActivated: root.closeKeyboardDrawer()
    }

    function inSidebarHotspot(x, y) {
        return x >= width - Math.max(edgeHotspot, visibleW(panels.sidebar)) || inRightPanel(panels.sidebar, x, y);
    }

    function setSidehub(open) {
        sidehubSyncing = true;
        visibilities.sidebar = open;
        visibilities.utilities = open;
        sidehubSyncing = false;

        if (!open) {
            sidehubOpenedByDrag = false;
            sidehubEnteredAfterDrag = false;
            setSidehubDragProgress(0);
        }
    }

    function setSidehubDragProgress(progress) {
        if (!ready() || panels.sidehubDragProgress === undefined)
            return;

        panels.sidehubDragProgress = Math.max(0, Math.min(1, progress));
    }

    function closeSidehub() {
        setSidehub(false);
    }

    function sidehubActive() {
        return visibilities.sidebar || visibilities.utilities;
    }


    function inSidehubArea(x, y) {
        if (!ready())
            return false;

        return inPanelRect(panels.sidebar, x, y)
            || inPanelRect(panels.utilities, x, y)
            || inPanelRect(panels.notifications, x, y)
            || inRightSessionHotspot(x, y);
    }


    function inSidehubHotspot(x, y) {
        if (!ready())
            return false;

        return inRightSessionHotspot(x, y)
            || inPanelRect(panels.sidebar, x, y)
            || inPanelRect(panels.utilities, x, y)
            || inPanelRect(panels.notifications, x, y);
    }


    function sidehubDragStartArea(x, y) {
        if (!ready())
            return false;

        return x >= root.width - sidehubDragStrip
            || inRightSessionHotspot(x, y)
            || inPanelRect(panels.sessionWrapper, x, y);
    }

    function sidehubVisibleWidth() {
        if (!ready())
            return 0;

        const sidebarVisibleWidth = panels.sidebar
            ? panels.sidebar.width * (1 - (panels.sidebar.offsetScale ?? 1))
            : 0;

        const utilitiesVisibleWidth = panels.utilities
            ? panels.utilities.width * (1 - (panels.utilities.offsetScale ?? 1))
            : 0;

        const notificationsVisibleWidth = panels.notifications && panels.notifications.visible
            ? panels.notifications.width
            : 0;

        return Math.max(sidebarVisibleWidth, utilitiesVisibleWidth, notificationsVisibleWidth);
    }

    function sidehubKeepOpen(x, y) {
        if (!ready())
            return false;

        const visibleWidth = sidehubVisibleWidth();

        return visibleWidth > 0
            && x >= root.width - visibleWidth - Math.max(Config.border.rounding, edgeHotspot / 2);
    }

    function closeTopPopoutNow(force) {
        if (!ready())
            return;

        if (force || !inTopPopoutSafeArea(lastMouseX, lastMouseY)) {
            popouts.hasCurrent = false;

            if (bar.closeTray)
                bar.closeTray();
        }
    }

    function closeTopPopout(force) {
        if (!ready())
            return;

        topPopoutCloseTimer.forceClose = !!force;
        topPopoutCloseTimer.restart();
    }

    function updatePopout(x, y) {
        if (!ready())
            return;

        lastMouseX = x;
        lastMouseY = y;

        if (y <= topbarHeight + Config.border.rounding) {
            if (Config.bar.showOnHover)
                bar.isHovered = true;

            topPopoutCloseTimer.stop();

            if (bar.checkPopout)
                bar.checkPopout(x);

            return;
        }

        if (inTopPopoutSafeArea(x, y))
            topPopoutCloseTimer.stop();
        else
            closeTopPopout(true);
    }

    function updateHover(x, y, dragX, dragY) {
        if (!ready() || fullscreen)
            return;

        const startedInSidebar = inSidebarHotspot(dragStart.x, dragStart.y);

        updatePopout(x, y);

        if (pressed && !sidehubDragArmed && dragStart.x >= root.width - sidehubDragStrip)
            sidehubDragArmed = true;

        const keepSidehubOpen = sidehubKeepOpen(x, y);
        const dragThreshold = Math.max(1, Config.sidebar.dragThreshold || sidehubDragStrip);
        const dragProgress = pressed && sidehubDragArmed ? (dragStart.x - x) / dragThreshold : 0;
        const draggedLeftEnough = pressed && sidehubDragArmed && dragProgress >= 1;
        const draggedRightEnough = pressed && sidehubActive() && startedInSidebar && (x - dragStart.x) > dragThreshold;

        setSidehubDragProgress(dragProgress);

        if (draggedRightEnough) {
            closeSidehub();
            visibilities.session = false;
            return;
        }

        if (draggedLeftEnough) {
            setSidehubDragProgress(1);
            setSidehub(true);
            sidehubOpenedByDrag = true;
            sidehubEnteredAfterDrag = false;
            visibilities.session = false;
            visibilities.dashboard = false;
            return;
        }

        if (sidehubActive() && sidehubOpenedByDrag && keepSidehubOpen)
            sidehubEnteredAfterDrag = true;

        if (!pressed && sidehubActive() && !sidehubOpenedByDrag && !keepSidehubOpen) {
            closeSidehub();
            visibilities.session = false;
        }

        if (!pressed && sidehubActive() && sidehubOpenedByDrag && sidehubEnteredAfterDrag && !keepSidehubOpen) {
            closeSidehub();
            visibilities.session = false;
        }

        const showSession = Config.session.enabled && !sidehubActive() && inRightSessionHotspot(x, y);

        if (!pressed)
            visibilities.session = showSession;
        else if (sidehubDragArmed)
            visibilities.session = true;

        const showDashboard = Config.dashboard.showOnHover && inDashboardHotspot(x, y);

        if (!dashboardShortcutActive)
            visibilities.dashboard = showDashboard;
        else if (showDashboard)
            dashboardShortcutActive = false;

        const showLauncher = Config.launcher.showOnHover && inLauncherHotspot(x, y);

        if (!launcherShortcutActive)
            visibilities.launcher = showLauncher;
        else if (showLauncher)
            launcherShortcutActive = false;

        const showOsd = !showSession && !sidehubActive() && inRightPanel(panels.osdWrapper, x, y);

        if (!osdShortcutActive) {
            visibilities.osd = showOsd;

            if (panels.osd)
                panels.osd.hovered = showOsd;
        } else if (showOsd) {
            osdShortcutActive = false;

            if (panels.osd)
                panels.osd.hovered = true;
        }
    }

    function onWheel(event) {
        if (!ready() || fullscreen)
            return;

        if (event.y <= topbarHeight && bar.handleWheel)
            bar.handleWheel(event.x, event.angleDelta);
    }

    onPressed: event => {
        lastMouseX = event.x;
        lastMouseY = event.y;
        dragStart = Qt.point(event.x, event.y);
        setSidehubDragProgress(0);
        sidehubDragArmed = ready() && sidehubDragStartArea(event.x, event.y);

        if (sidehubDragArmed && !sidehubActive())
            visibilities.session = Config.session.enabled;
    }

    onReleased: event => {
        lastMouseX = event.x;
        lastMouseY = event.y;
        sidehubDragArmed = false;
        setSidehubDragProgress(0);

        if (ready() && !sidehubActive() && !inRightSessionHotspot(event.x, event.y))
            visibilities.session = false;
    }

    onContainsMouseChanged: {
        if (!containsMouse && ready()) {
            closeSidehub();
            setSidehubDragProgress(0);
            sidehubDragArmed = false;
            if (!osdShortcutActive) {
                visibilities.osd = false;

                if (panels.osd)
                    panels.osd.hovered = false;
            }

            if (!dashboardShortcutActive)
                visibilities.dashboard = false;

            if (!launcherShortcutActive)
                visibilities.launcher = false;

            closeSidehub();
            visibilities.session = false;

            closeTopPopout(true);

            if (Config.bar.showOnHover)
                bar.isHovered = false;
        }
    }

    onPositionChanged: event => {
        lastMouseX = event.x;
        lastMouseY = event.y;

        if (!ready() || popouts.isDetached)
            return;

        updateHover(event.x, event.y, event.x - dragStart.x, event.y - dragStart.y);
    }

    Timer {
        id: topPopoutCloseTimer

        interval: 360
        repeat: false
        property bool forceClose

        onTriggered: {
            const force = forceClose;
            forceClose = false;
            root.closeTopPopoutNow(force);
        }
    }

    Connections {
        target: root.visibilities

        function onSidebarChanged() {
            if (!root.ready() || root.sidehubSyncing)
                return;

            root.setSidehub(root.visibilities.sidebar);

            if (root.visibilities.sidebar)
                root.visibilities.session = false;
        }

        function onUtilitiesChanged() {
            if (!root.ready() || root.sidehubSyncing)
                return;

            root.setSidehub(root.visibilities.utilities);
        }

        function onDashboardChanged() {
            if (!root.ready())
                return;

            if (root.visibilities.dashboard) {
                const inArea = root.inDashboardHotspot(root.mouseX, root.mouseY);

                if (!inArea)
                    root.dashboardShortcutActive = true;
            } else {
                root.dashboardShortcutActive = false;
            }
        }

        function onLauncherChanged() {
            if (!root.ready())
                return;

            if (root.visibilities.launcher) {
                const inArea = root.inLauncherHotspot(root.mouseX, root.mouseY);

                if (!inArea)
                    root.launcherShortcutActive = true;
            } else {
                root.launcherShortcutActive = false;
            }
        }

        function onOsdChanged() {
            if (!root.ready())
                return;

            if (root.visibilities.osd) {
                const inArea = root.inRightPanel(root.panels.osdWrapper, root.mouseX, root.mouseY);

                if (!inArea)
                    root.osdShortcutActive = true;
            } else {
                root.osdShortcutActive = false;
            }
        }
    }
}
