pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property color accent: "#cba6f7"
    property bool sleeping
    property bool hovering
    property bool intense
    property bool transforming
    property real pointerX: width / 2
    property real pointerY: height / 2
    property real phase
    property real smoothLookX: targetLookX
    property real smoothLookY: targetLookY

    readonly property bool blinking: !sleeping && !intense && Math.sin(phase * 0.32) > 0.985
    readonly property real maxLookX: intense || hovering ? 13 : 7
    readonly property real maxLookY: intense || hovering ? 7 : 4
    readonly property real targetLookX: sleeping ? 0 : Math.max(-maxLookX, Math.min(maxLookX, (pointerX - width / 2) / 10))
    readonly property real targetLookY: sleeping ? 0 : Math.max(-maxLookY, Math.min(maxLookY, (pointerY - height / 2) / 12))
    readonly property real eyeOpacity: transforming ? 0.15 : sleeping ? 0.58 : 1
    readonly property real openEyeWidth: intense ? 12 : 11
    readonly property real openEyeHeight: blinking ? 2 : intense ? 8 : 7
    readonly property real pupilX: smoothLookX * 0.28
    readonly property real pupilY: smoothLookY * 0.22

    Behavior on smoothLookX {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    Behavior on smoothLookY {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    component CatEye: Rectangle {
        property real pupilOffsetX: 0
        property real pupilOffsetY: 0
        property bool asleep: false

        width: root.sleeping ? 12 : root.openEyeWidth
        height: root.sleeping ? 1.8 : root.openEyeHeight
        radius: height / 2
        color: root.accent
        opacity: root.eyeOpacity

        Behavior on height {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 12
            height: parent.height + 12
            radius: height / 2
            color: root.accent
            opacity: root.sleeping ? 0 : 0.18
            z: -1
        }

        Rectangle {
            visible: !parent.asleep
            width: 3.8
            height: 5
            radius: width / 2
            x: parent.width / 2 - width / 2 + parent.pupilOffsetX
            y: parent.height / 2 - height / 2 + parent.pupilOffsetY
            color: Qt.rgba(0, 0, 0, 0.88)
        }
    }

    CatEye {
        x: 15
        y: root.sleeping ? 22 : 20
        asleep: root.sleeping
        pupilOffsetX: root.pupilX
        pupilOffsetY: root.pupilY
    }

    CatEye {
        x: 36
        y: root.sleeping ? 22 : 20
        asleep: root.sleeping
        pupilOffsetX: root.pupilX
        pupilOffsetY: root.pupilY
    }
}
