pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.bar.popouts

Item {
    id: root

    required property ShellScreen screen
    required property real borderThickness

    readonly property alias content: content
    property real offsetScale: content.hasCurrent ? 0 : 1

    visible: true
    clip: false

    implicitWidth: parent ? parent.width : screen.width
    implicitHeight: parent ? parent.height : screen.height

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale
    }
}
