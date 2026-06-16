pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    readonly property bool enabled: true
    readonly property bool safeMode: true
    readonly property bool mischiefEnabled: true
    readonly property int mischiefLevel: 2
    readonly property string homePosition: "bottom-left"
    readonly property int frameInterval: 50
    readonly property real breatheSpeed: 0.055
    readonly property real tailSpeed: 0.065
    readonly property int cursorPollInterval: 120
    readonly property int idleCursorPollInterval: 360
    readonly property int activeWindowPollInterval: 1600
    readonly property int firstAttentionDelay: 180000
    readonly property int attentionInterval: 180000
    readonly property int chewDuration: 9000
    readonly property int lickDuration: 8000
    readonly property int attentionDuration: 9000
    readonly property int chewCooldown: 600000
    readonly property int walkDuration: 5200
}
