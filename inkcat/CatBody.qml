pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property bool catEnabled: true
    property string stateName: "sleeping"
    property string mood: "ink"
    property color accent: "#cba6f7"
    property bool musicPlaying
    property bool transforming
    property string homePosition: "bottom-left"
    property real screenWidth
    property real screenHeight
    property real globalPointerX: -1
    property real globalPointerY: -1
    property int frameInterval: 33
    property int walkMoveDuration: 5200
    property real breatheSpeed: 0.055
    property real tailSpeed: 0.065
    property bool facingRight

    property real breathePhase
    property real tailPhase
    property real pointerX: width / 2
    property real pointerY: height / 2
    property bool hovering
    property bool dragging
    property bool dragCandidate
    property bool tailPulled
    property real pressX
    property real pressY
    property real pressSceneX
    property real pressSceneY
    property real dragOffsetX
    property real dragOffsetY
    property real dragVisualOffsetX
    property real dropFloorY
    property real dropLiftY
    property real dropSquash

    readonly property bool physicallyActive: dragging || dropAnim.running
    readonly property real stride: Math.sin(tailPhase * 2.3)
    readonly property real scruffX: 72
    readonly property real scruffY: 58
    readonly property real dragTilt: dragging ? Math.max(-5, Math.min(5, (x + width / 2 - pressSceneX) / 24)) : 0
    readonly property real bodyHang: dragging ? 4 : dropSquash * 4
    readonly property real headLift: dragging ? -3 : petting ? -4 : -dropSquash * 2
    readonly property real petPulse: petting ? Math.sin(tailPhase * 4) : 0
    readonly property real pseudoDepth: dragging ? 1 : walking ? 0.55 : grooming ? 0.75 : 0
    readonly property real gaitPhase: tailPhase * 2.1
    readonly property real walkLift: walking ? Math.abs(Math.sin(gaitPhase)) * -6 : 0
    readonly property real walkLean: walking ? Math.sin(gaitPhase) * 1.6 : 0
    readonly property real chewPulse: grooming ? Math.sin(tailPhase * (licking ? 4.4 : 5.2)) : 0
    readonly property real chewNod: grooming ? Math.abs(chewPulse) : 0
    readonly property real bodyMotionY: bodyHang + walkLift + chewNod * 1.4
    readonly property real headMotionX: grooming ? -chewNod * 2 : walking ? Math.sin(gaitPhase + Math.PI) * 1.8 : 0
    readonly property real headMotionY: walkLift * 0.55 + (grooming ? chewPulse * 1.2 : 0)

    readonly property bool hidden: !catEnabled || stateName === "hidden"
    readonly property bool sleeping: stateName === "sleeping"
    readonly property bool petting: stateName === "pet"
    readonly property bool walking: stateName === "walking"
    readonly property bool staring: stateName === "stareAtUser"
    readonly property bool chewing: stateName === "pawChew" || stateName === "mischiefChew"
    readonly property bool licking: stateName === "pawLick"
    readonly property bool grooming: chewing || licking
    readonly property bool boxNap: stateName === "boxNap"
    readonly property bool musicReactive: stateName === "musicReactive"
    readonly property color bodyColor: Qt.rgba(0, 0, 0, mood === "spirit" ? 0.7 : mood === "void" ? 0.84 : 0.78)
    readonly property real homeMargin: 58
    readonly property real floorMargin: 44
    readonly property real hitboxScale: hidden ? 0 : 1

    readonly property real hitboxX: dragging ? -160 : 14
    readonly property real hitboxY: dragging ? -120 : 14
    readonly property real hitboxWidth: dragging ? width + 320 : 204
    readonly property real hitboxHeight: dragging ? height + 240 : 128

    signal hoverChanged(bool hovering)
    signal petRequested()
    signal sleepToggleRequested()
    signal tailPullChanged(bool active)
    signal releasedNearBed()

    width: 220
    height: 150
    transformOrigin: Item.TopLeft
    visible: catEnabled
    opacity: hidden ? 0 : transforming ? 0.48 : 1
    scale: hidden ? 0.1 : 1
    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.facingRight ? -1 : 1
        yScale: 1
    }

    function moveTo(valueX: real, valueY: real): void {
        root.x = Math.max(0, Math.min(screenWidth - width, valueX));
        root.y = Math.max(0, Math.min(screenHeight - height, valueY));
    }

    function sceneXFromLocal(localX: real): real {
        return root.x + (root.facingRight ? root.width - localX : localX);
    }

    function sceneYFromLocal(localY: real): real {
        return root.y + localY;
    }

    function setDragAnchor(localX: real, localY: real): void {
        dragOffsetX = localX;
        dragOffsetY = localY;
        dragVisualOffsetX = root.facingRight ? root.width - localX : localX;
    }

    function dragTo(sceneX: real, sceneY: real): void {
        root.moveTo(sceneX - dragVisualOffsetX, sceneY - dragOffsetY);
    }

    function homeX(): real {
        if (homePosition === "bottom-center")
            return Math.max(homeMargin, (screenWidth - width) / 2);
        if (homePosition === "bottom-right")
            return Math.max(homeMargin, screenWidth - width - homeMargin);
        return homeMargin;
    }

    function homeY(): real {
        return Math.max(0, screenHeight - height - floorMargin);
    }

    function updatePointerFromGlobal(): void {
        if (globalPointerX >= 0 && globalPointerY >= 0) {
            pointerX = globalPointerX - root.x;
            pointerY = globalPointerY - root.y;
        }
    }

    function startDrop(): void {
        if (hidden)
            return;

        dropFloorY = Math.max(0, Math.min(screenHeight - height, y + 22));
        dropLiftY = Math.max(0, dropFloorY - 10);
        dropAnim.restart();
    }

    onGlobalPointerXChanged: updatePointerFromGlobal()
    onGlobalPointerYChanged: updatePointerFromGlobal()

    Timer {
        interval: root.frameInterval
        running: root.catEnabled
        repeat: true
        onTriggered: {
            root.breathePhase += root.breatheSpeed;
            root.tailPhase += root.tailSpeed * (root.walking ? 1.55 : root.chewing ? 1.25 : root.petting ? 2.2 : root.musicPlaying ? 1.55 : root.sleeping || root.boxNap ? 0.45 : 1);
        }
    }

    Behavior on x {
        enabled: !root.dragging

        NumberAnimation {
            duration: root.walking ? root.walkMoveDuration : root.staring || root.chewing ? 2800 : 420
            easing.type: root.walking ? Easing.InOutSine : Easing.OutCubic
        }
    }

    Behavior on y {
        enabled: !root.dragging

        NumberAnimation {
            duration: root.walking ? root.walkMoveDuration : root.staring || root.chewing ? 2800 : 420
            easing.type: root.walking ? Easing.InOutSine : Easing.OutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: dropAnim

        ScriptAction { script: root.dropSquash = 0 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "y"; to: root.dropFloorY; duration: 140; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "dropSquash"; to: 0.7; duration: 140; easing.type: Easing.InQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "y"; to: root.dropLiftY; duration: 100; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "dropSquash"; to: 0.2; duration: 100; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "y"; to: root.dropFloorY; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "dropSquash"; to: 0; duration: 160; easing.type: Easing.OutCubic }
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: aura

        x: 32
        y: 48 + Math.sin(root.breathePhase) * (root.sleeping || root.boxNap ? 2 : 4)
        width: 142
        height: 76
        radius: 38
        color: root.accent
        opacity: root.hidden ? 0 : root.petting ? 0.2 : root.sleeping || root.boxNap ? 0.05 : root.chewing ? 0.18 : root.musicPlaying ? 0.14 : 0.09
        scale: 1 + Math.sin(root.breathePhase) * 0.04
    }

    Rectangle {
        id: shadow

        x: 42
        y: 108 + root.dropSquash * 5
        width: 128 + root.dropSquash * 16
        height: 24 - root.dropSquash * 5
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.34)
        scale: 1 + Math.sin(root.breathePhase) * (root.sleeping || root.boxNap ? 0.018 : 0.025)
    }

    CatTail {
        z: 1
        accent: root.accent
        mood: root.mood
        sleeping: root.sleeping
        petting: root.petting
        pulled: root.tailPulled || root.stateName === "tailPull"
        chewing: root.chewing || root.licking
        musicPlaying: root.musicPlaying || root.musicReactive
        transforming: root.transforming
        phase: root.tailPhase
        opacity: root.sleeping ? 0.72 : 1
    }

    Shape {
        id: body

        z: 2
        width: parent.width
        height: parent.height
        y: root.walkLift + root.chewNod * 0.8
        opacity: 0.98
        rotation: root.dragTilt * 0.06 + root.walkLean * 0.35 - root.chewNod * 0.35
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.bodyColor
            strokeColor: "transparent"
            startX: 43
            startY: 94 + root.bodyMotionY + root.petPulse + Math.sin(root.breathePhase) * (root.sleeping || root.boxNap ? 1 : 1.8)

            PathCubic {
                x: 42
                y: 64 + root.headLift
                control1X: 28
                control1Y: 83 + root.headLift
                control2X: 31
                control2Y: 70 + root.headLift
            }
            PathCubic {
                x: 54
                y: 52 + root.headLift
                control1X: 43
                control1Y: 56 + root.headLift
                control2X: 48
                control2Y: 52 + root.headLift
            }
            PathCubic {
                x: 60
                y: 28 + root.headLift
                control1X: 53
                control1Y: 45 + root.headLift
                control2X: 55
                control2Y: 34 + root.headLift
            }
            PathCubic {
                x: 72
                y: 51 + root.headLift
                control1X: 66
                control1Y: 34 + root.headLift
                control2X: 68
                control2Y: 45 + root.headLift
            }
            PathCubic {
                x: 84
                y: 51 + root.headLift
                control1X: 76
                control1Y: 48 + root.headLift
                control2X: 80
                control2Y: 48 + root.headLift
            }
            PathCubic {
                x: 96
                y: 29 + root.headLift
                control1X: 88
                control1Y: 44 + root.headLift
                control2X: 91
                control2Y: 34 + root.headLift
            }
            PathCubic {
                x: 104
                y: 60 + root.headLift
                control1X: 101
                control1Y: 38 + root.headLift
                control2X: 107
                control2Y: 50 + root.headLift
            }
            PathCubic {
                x: 135
                y: 57 + root.bodyMotionY * 0.25
                control1X: 113
                control1Y: 58 + root.headLift
                control2X: 122
                control2Y: 53 + root.bodyMotionY * 0.2
            }
            PathCubic {
                x: 176
                y: 90 + root.bodyMotionY
                control1X: 157
                control1Y: 59 + root.bodyMotionY * 0.35
                control2X: 177
                control2Y: 72 + root.bodyMotionY
            }
            PathCubic {
                x: 147
                y: 116 + root.bodyMotionY + root.dropSquash * 3
                control1X: 180
                control1Y: 105 + root.bodyMotionY
                control2X: 165
                control2Y: 117 + root.bodyMotionY
            }
            PathCubic {
                x: 70
                y: 116 + root.bodyMotionY + root.dropSquash * 2
                control1X: 119
                control1Y: 123 + root.bodyMotionY
                control2X: 91
                control2Y: 121 + root.bodyMotionY
            }
            PathCubic {
                x: 43
                y: 94 + root.bodyMotionY
                control1X: 52
                control1Y: 113 + root.bodyMotionY
                control2X: 38
                control2Y: 106 + root.bodyMotionY
            }
        }

        ShapePath {
            fillColor: Qt.rgba(0, 0, 0, 0.18)
            strokeColor: "transparent"
            startX: 118
            startY: 62 + root.bodyMotionY * 0.4

            PathCubic {
                x: 165
                y: 92 + root.bodyMotionY
                control1X: 142
                control1Y: 55 + root.bodyMotionY * 0.4
                control2X: 164
                control2Y: 66 + root.bodyMotionY
            }
            PathCubic {
                x: 135
                y: 113 + root.bodyMotionY
                control1X: 162
                control1Y: 108 + root.bodyMotionY
                control2X: 151
                control2Y: 115 + root.bodyMotionY
            }
            PathCubic {
                x: 116
                y: 64 + root.bodyMotionY * 0.4
                control1X: 125
                control1Y: 100 + root.bodyMotionY
                control2X: 112
                control2Y: 78 + root.bodyMotionY
            }
        }

    }

    Item {
        id: head

        z: 4
        x: 31 + root.headMotionX
        y: 48 + root.headLift + root.headMotionY + (root.hovering || root.staring || root.chewing ? -2 : 0) + root.petPulse * 1.6 + Math.sin(root.breathePhase + 0.4) * (root.sleeping || root.boxNap ? 1 : 1.7)
        width: 76
        height: 60
        rotation: root.dragTilt * 0.12 + root.walkLean * 0.28 - root.chewNod * 1.6 + (root.petting ? Math.sin(root.tailPhase * 5) * 1.5 : 0)

        Shape {
            anchors.fill: parent
            opacity: root.hidden ? 0 : 1
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(root.accent, root.petting ? 0.55 : 0.28)
                strokeWidth: 2
                capStyle: ShapePath.RoundCap
                startX: 12
                startY: 38

                PathCubic {
                    x: 26
                    y: 50
                    control1X: 13
                    control1Y: 47
                    control2X: 20
                    control2Y: 51
                }
            }
        }
    }

    Shape {
        id: scruff

        z: 9
        x: 63
        y: 45
        width: 36
        height: 30
        visible: root.dragging

        ShapePath {
            strokeColor: Qt.alpha(root.accent, 0.75)
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 4
            startY: 16

            PathCubic {
                x: 32
                y: 14
                control1X: 12
                control1Y: 0
                control2X: 22
                control2Y: 28
            }
        }
    }

    Item {
        id: sleepZ

        z: 12
        x: 16
        y: 14
        visible: root.sleeping || root.boxNap
        opacity: visible ? 0.85 : 0

        Repeater {
            model: 3

            Text {
                required property int index

                text: "z"
                x: index * 15 + Math.sin(root.tailPhase + index) * 2
                y: -index * 9 - Math.abs(Math.sin(root.tailPhase * 0.8 + index)) * 5
                color: Qt.alpha(root.accent, 0.45 + index * 0.15)
                font.pixelSize: 12 + index * 3
                font.bold: true
                rotation: -10 + index * 8
            }
        }
    }

    CatEyes {
        z: 5
        x: head.x + 9
        y: head.y + 15
        width: 58
        height: 34
        accent: root.accent
        sleeping: root.sleeping || root.boxNap
        hovering: root.hovering || root.staring || root.chewing || root.tailPulled
        intense: root.staring || root.chewing || root.tailPulled
        transforming: root.transforming
        phase: root.tailPhase
        pointerX: root.pointerX - x
        pointerY: root.pointerY - y
    }

    Shape {
        id: faceInk

        z: 6
        x: head.x + 1
        y: head.y + 38
        width: 78
        height: 28
        visible: !root.sleeping && !root.boxNap && !root.chewing
        opacity: root.grooming ? 0.9 : 0.86
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.accent, root.petting ? 0.82 : root.chewing ? 0.72 : 0.54)
            strokeWidth: 1.55
            capStyle: ShapePath.RoundCap
            startX: 31
            startY: 4

            PathCubic {
                x: 16
                y: 1
                control1X: 25
                control1Y: 3
                control2X: 20
                control2Y: 0
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.accent, root.petting ? 0.76 : root.chewing ? 0.66 : 0.48)
            strokeWidth: 1.45
            capStyle: ShapePath.RoundCap
            startX: 31
            startY: 13

            PathCubic {
                x: 13
                y: 13
                control1X: 25
                control1Y: 12
                control2X: 19
                control2Y: 14
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.accent, root.petting ? 0.7 : root.chewing ? 0.58 : 0.42)
            strokeWidth: 1.4
            capStyle: ShapePath.RoundCap
            startX: 31
            startY: 22

            PathCubic {
                x: 17
                y: 25
                control1X: 25
                control1Y: 22
                control2X: 21
                control2Y: 26
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.accent, root.petting ? 0.82 : root.chewing ? 0.72 : 0.54)
            strokeWidth: 1.55
            capStyle: ShapePath.RoundCap
            startX: 45
            startY: 4

            PathCubic {
                x: 60
                y: 1
                control1X: 51
                control1Y: 3
                control2X: 56
                control2Y: 0
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.accent, root.petting ? 0.76 : root.chewing ? 0.66 : 0.48)
            strokeWidth: 1.45
            capStyle: ShapePath.RoundCap
            startX: 45
            startY: 13

            PathCubic {
                x: 63
                y: 13
                control1X: 51
                control1Y: 12
                control2X: 57
                control2Y: 14
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.accent, root.petting ? 0.7 : root.chewing ? 0.58 : 0.42)
            strokeWidth: 1.4
            capStyle: ShapePath.RoundCap
            startX: 45
            startY: 22

            PathCubic {
                x: 59
                y: 25
                control1X: 51
                control1Y: 22
                control2X: 55
                control2Y: 26
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.accent, root.petting ? 0.78 : 0.42)
            strokeWidth: 1.8
            capStyle: ShapePath.RoundCap
            startX: 37
            startY: 8

            PathCubic {
                x: 40
                y: 12
                control1X: 38
                control1Y: 6
                control2X: 39
                control2Y: 6
            }
        }
    }

    Rectangle {
        id: chewMouthShadow

        z: 10
        x: head.x + 43 + root.chewNod * 0.8
        y: head.y + 54 + root.chewNod * 1.2
        width: 15
        height: 8
        radius: height / 2
        visible: root.chewing
        color: Qt.rgba(0, 0, 0, 0.66)
        opacity: visible ? 0.92 : 0
        rotation: -5 + root.chewPulse * 1.4
    }

    Item {
        id: petGlow

        z: 11
        x: 25
        y: 33
        visible: root.petting

        Repeater {
            model: 5

            Rectangle {
                required property int index

                width: 4 + index % 2
                height: width
                radius: width / 2
                x: 10 + index * 16 + Math.sin(root.tailPhase * 4 + index) * 7
                y: Math.abs(Math.sin(root.tailPhase * 3 + index)) * 18
                color: root.accent
                opacity: 0.35 + Math.abs(Math.sin(root.tailPhase * 2 + index)) * 0.45
            }
        }
    }

    Shape {
        id: groomPaw

        z: 9
        x: head.x + 14 + root.headMotionX * 0.15
        y: head.y + 41 + root.chewNod * 2
        width: 46
        height: 40
        visible: root.licking
        opacity: visible ? 0.96 : 0
        rotation: -12 + root.chewPulse * (root.licking ? 4 : 1.5)
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.bodyColor
            strokeColor: "transparent"
            startX: 16
            startY: 38

            PathCubic {
                x: 12
                y: 22
                control1X: 13
                control1Y: 33
                control2X: 10
                control2Y: 28
            }
            PathCubic {
                x: 23
                y: 8
                control1X: 11
                control1Y: 13
                control2X: 16
                control2Y: 8
            }
            PathCubic {
                x: 36
                y: 19
                control1X: 33
                control1Y: 8
                control2X: 39
                control2Y: 12
            }
            PathCubic {
                x: 31
                y: 37
                control1X: 38
                control1Y: 28
                control2X: 39
                control2Y: 36
            }
            PathCubic {
                x: 16
                y: 38
                control1X: 27
                control1Y: 42
                control2X: 20
                control2Y: 42
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.accent, root.licking ? 0.82 : 0.5)
            strokeWidth: root.licking ? 2.4 : 1.7
            capStyle: ShapePath.RoundCap
            startX: 15
            startY: 24

            PathCubic {
                x: 35
                y: 20 + root.chewPulse * 3
                control1X: 19
                control1Y: 14
                control2X: 31
                control2Y: 13
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.accent, 0.46)
            strokeWidth: 1.5
            capStyle: ShapePath.RoundCap
            startX: 13
            startY: 28

            PathCubic {
                x: 37
                y: 26
                control1X: 18
                control1Y: 35
                control2X: 31
                control2Y: 34
            }
        }

        Repeater {
            model: 3

            Rectangle {
                required property int index

                width: 3.8
                height: 3.8
                radius: width / 2
                x: 18 + index * 6
                y: 20 + Math.sin(root.tailPhase * 5 + index) * 1.2
                color: root.accent
                opacity: root.licking ? 0.68 : 0.48
            }
        }
    }

    Item {
        id: legs

        z: 7
        x: 58
        y: 92 + root.bodyHang * 0.82
        opacity: root.sleeping || root.boxNap ? 0.18 : root.grooming ? 0.32 : 0.96

        component Leg: Shape {
            id: leg

            property real baseX: 0
            property real phaseOffset: 0
            property bool front: false
            readonly property real step: Math.sin(root.gaitPhase + phaseOffset)
            readonly property real lift: Math.max(0, step)

            width: 20
            height: root.dragging ? 29 : root.walking ? 32 : 24
            transformOrigin: Item.Top
            x: baseX + (root.walking ? step * (front ? 15 : 12) : 0)
            y: root.dragging ? 3 + Math.abs(Math.sin(root.tailPhase + phaseOffset)) * 2 : root.walking ? 4 - lift * 18 : 3
            rotation: root.dragging ? (front ? -3 : 3) + Math.sin(root.tailPhase + phaseOffset) * 3 : root.walking ? step * (front ? 36 : 30) : 0
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.bodyColor
                strokeColor: "transparent"
                startX: 7
                startY: 0

                PathCubic {
                    x: 14
                    y: 2
                    control1X: 9
                    control1Y: 1
                    control2X: 13
                    control2Y: 0
                }
                PathCubic {
                    x: 17
                    y: leg.height - 8
                    control1X: 17
                    control1Y: leg.height * 0.35
                    control2X: 18
                    control2Y: leg.height * 0.68
                }
                PathCubic {
                    x: 5
                    y: leg.height - 5
                    control1X: 15
                    control1Y: leg.height
                    control2X: 8
                    control2Y: leg.height
                }
                PathCubic {
                    x: 7
                    y: 0
                    control1X: 1
                    control1Y: leg.height * 0.62
                    control2X: 4
                    control2Y: leg.height * 0.26
                }
            }

            ShapePath {
                fillColor: root.bodyColor
                strokeColor: "transparent"
                startX: 5
                startY: leg.height - 8

                PathCubic {
                    x: 19
                    y: leg.height - 4
                    control1X: 9
                    control1Y: leg.height - 2
                    control2X: 16
                    control2Y: leg.height - 2
                }
                PathCubic {
                    x: 5
                    y: leg.height - 8
                    control1X: 13
                    control1Y: leg.height + 2
                    control2X: 2
                    control2Y: leg.height
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(root.accent, root.walking ? 0.28 : 0)
                strokeWidth: 1.2
                capStyle: ShapePath.RoundCap
                startX: 4
                startY: leg.height - 5

                PathCubic {
                    x: 18
                    y: leg.height - 4
                    control1X: 8
                    control1Y: leg.height - 1
                    control2X: 14
                    control2Y: leg.height - 1
                }
            }
        }

        Leg { baseX: 4; phaseOffset: 0; front: true; z: 2 }
        Leg { baseX: 30; phaseOffset: Math.PI; front: true; opacity: 0.82; z: 1 }
        Leg { baseX: 72; phaseOffset: Math.PI * 0.65; z: 2 }
        Leg { baseX: 96; phaseOffset: Math.PI * 1.45; opacity: 0.82; z: 1 }
    }

    Shape {
        id: chewFace

        z: 11
        x: head.x + 43 + root.headMotionX * 0.08
        y: head.y + 55 + root.chewNod * 0.9
        width: 24
        height: 20
        visible: root.licking
        opacity: root.licking ? 0.9 : 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.accent, root.chewing ? 0.76 : 0)
            strokeWidth: 1.7
            capStyle: ShapePath.RoundCap
            startX: 5
            startY: 4

            PathLine { x: 7; y: 8 + root.chewNod * 1.7 }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.accent, root.chewing ? 0.68 : 0)
            strokeWidth: 1.55
            capStyle: ShapePath.RoundCap
            startX: 10
            startY: 3

            PathLine { x: 11; y: 8 + root.chewNod * 1.7 }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.accent, root.chewing ? 0.58 : 0)
            strokeWidth: 1.4
            capStyle: ShapePath.RoundCap
            startX: 15
            startY: 4

            PathLine { x: 15; y: 8 + root.chewNod * 1.7 }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.accent, root.licking ? 0.78 : 0)
            strokeWidth: 2.2
            capStyle: ShapePath.RoundCap
            startX: 11
            startY: 10

            PathCubic {
                x: 1
                y: 16 + root.chewPulse * 1.5
                control1X: 8
                control1Y: 16
                control2X: 4
                control2Y: 18
            }
        }
    }

    CatParticles {
        z: 0
        anchors.fill: parent
        accent: root.accent
        mood: root.mood
        active: !root.sleeping && !root.hidden && (root.musicPlaying || root.hovering || root.petting || root.walking || root.grooming)
        transforming: root.transforming
        phase: root.tailPhase
    }

    MouseArea {
        id: bodyMouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.dragging ? Qt.ClosedHandCursor : root.hovering ? Qt.OpenHandCursor : Qt.PointingHandCursor

        onEntered: {
            root.hovering = true;
            root.hoverChanged(true);
        }

        onExited: {
            root.hovering = false;
            root.hoverChanged(false);
        }

        onPositionChanged: mouse => {
            root.pointerX = mouse.x;
            root.pointerY = mouse.y;

            if (root.dragCandidate && !root.dragging) {
                const candidateSceneX = root.sceneXFromLocal(mouse.x);
                const candidateSceneY = root.sceneYFromLocal(mouse.y);
                const distance = Math.abs(candidateSceneX - root.pressSceneX) + Math.abs(candidateSceneY - root.pressSceneY);

                if (distance > 16) {
                    root.dragging = true;
                    root.dragTo(candidateSceneX, candidateSceneY);
                }
            }

            if (root.dragging) {
                const sceneX = root.sceneXFromLocal(mouse.x);
                const sceneY = root.sceneYFromLocal(mouse.y);
                root.dragTo(sceneX, sceneY);
            }
        }

        onPressed: mouse => {
            root.dragCandidate = true;
            root.dragging = false;
            root.pressX = mouse.x;
            root.pressY = mouse.y;
            root.setDragAnchor(mouse.x, mouse.y);
            root.pressSceneX = root.sceneXFromLocal(mouse.x);
            root.pressSceneY = root.sceneYFromLocal(mouse.y);
        }

        onReleased: mouse => {
            const wasDragging = root.dragging;
            root.dragCandidate = false;
            root.dragging = false;
            const releaseSceneX = root.sceneXFromLocal(mouse.x);
            const releaseSceneY = root.sceneYFromLocal(mouse.y);
            const moved = Math.abs(releaseSceneX - root.pressSceneX) + Math.abs(releaseSceneY - root.pressSceneY) > 18;

            if (wasDragging && moved)
                root.startDrop();

            if (wasDragging && moved && root.x < 280 && root.y > root.screenHeight - 240)
                root.releasedNearBed();
        }

        onCanceled: {
            const wasDragging = root.dragging;
            root.dragCandidate = false;
            root.dragging = false;
            if (wasDragging)
                root.startDrop();
        }

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.petRequested();
            else if (mouse.button === Qt.RightButton)
                root.sleepToggleRequested();
        }
    }

    MouseArea {
        z: 30
        x: 132
        y: 18
        width: 86
        height: 106
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: pressed ? Qt.ClosedHandCursor : containsMouse ? Qt.OpenHandCursor : Qt.PointingHandCursor

        onPressed: {
            tailReleaseDelay.stop();
            root.tailPulled = true;
            root.tailPullChanged(true);
        }

        onReleased: {
            root.tailPullChanged(false);
            tailReleaseDelay.restart();
        }

        onCanceled: {
            root.tailPullChanged(false);
            tailReleaseDelay.restart();
        }
    }

    Timer {
        id: tailReleaseDelay

        interval: 850
        repeat: false
        onTriggered: root.tailPulled = false
    }
}
