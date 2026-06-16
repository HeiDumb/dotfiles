pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Region {
    id: root

    required property Item cat
    property bool hidden
    readonly property real pad: 10
    readonly property bool active: !hidden && cat.visible && cat.opacity > 0.05 && cat.hitboxScale > 0.05

    x: active ? Math.round(cat.x + cat.hitboxX * cat.hitboxScale - pad) : 0
    y: active ? Math.round(cat.y + cat.hitboxY * cat.hitboxScale - pad) : 0
    width: active ? Math.round(cat.hitboxWidth * cat.hitboxScale + pad * 2) : 0
    height: active ? Math.round(cat.hitboxHeight * cat.hitboxScale + pad * 2) : 0
}
