pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property color accent: "#cba6f7"
    property string mood: "ink"
    property bool active
    property bool transforming
    property real phase

    Repeater {
        model: 7

        Rectangle {
            required property int index

            readonly property real drift: root.phase + index * 0.9
            readonly property real spread: index % 2 === 0 ? 1 : -1

            width: index % 3 === 0 ? 4 : 3
            height: width
            radius: width / 2
            x: 55 + index * 14 + Math.sin(drift) * 5 * spread
            y: 94 - Math.abs(Math.sin(drift * 0.75)) * 18 - index % 3 * 4
            color: root.accent
            opacity: root.active || root.transforming ? 0.18 + Math.abs(Math.sin(drift)) * 0.32 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
