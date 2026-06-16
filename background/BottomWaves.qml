pragma ComponentBehavior: Bound

import qs.components
import qs.config
import qs.services
import Caelestia.Services
import QtQuick

Item {
    id: root

    readonly property var cfg: Config.background.bottomWaves
    readonly property bool hasPlayback: Audio.playbackStreams.length > 0
    readonly property bool waveEnabled: cfg?.enabled !== false && !GameMode.enabled && hasPlayback
    readonly property int waveHeight: cfg?.height ?? 92
    readonly property real waveOpacity: cfg?.opacity ?? 0.72
    readonly property real waveAmplitude: cfg?.amplitude ?? 0.72
    readonly property int waveFps: Math.min(cfg?.fps ?? 18, 18)
    readonly property bool showBars: cfg?.showBars ?? true
    readonly property bool showWaves: cfg?.showWaves ?? true
    readonly property real sideInset: 0
    readonly property int targetSamples: Config.services.visualiserBars
    readonly property real systemOpacity: Colours.transparency.enabled ? Math.max(0.45, Colours.transparency.base) : 0.82
    readonly property real liveOpacity: waveOpacity * systemOpacity
    property var smoothValues: []
    property real level: 0
    property real backPhase: 0

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: Math.min(parent?.height ? parent.height * 0.33 : waveHeight, 320)
    visible: waveEnabled
    opacity: waveEnabled ? 1 : 0

    ServiceRef {
        service: Audio.cava
    }

    Item {
        id: barLayer

        anchors.fill: parent
        anchors.leftMargin: root.sideInset
        anchors.rightMargin: root.sideInset
        visible: root.showBars
        opacity: Math.max(0.86, Math.min(1, root.liveOpacity + 0.30))
        z: 2

        Repeater {
            model: root.targetSamples

            Item {
                id: visualBar

                required property int modelData

                readonly property real slotWidth: barLayer.width / Math.max(1, root.targetSamples)
                readonly property real barWidth: Math.max(18, Math.min(36, slotWidth * 0.58))
                readonly property real barGap: Math.max(0, (barLayer.width - barWidth * root.targetSamples) / (root.targetSamples + 1))

                readonly property real centerPos: root.targetSamples <= 1 ? 0.5 : modelData / (root.targetSamples - 1)
                readonly property real distFromCenter: Math.abs(centerPos - 0.5) * 2
                readonly property real sideSign: centerPos < 0.5 ? -1 : 1

                // Keep the coloured reflection tucked close to the main pill.
                readonly property real shadowOffset: sideSign * Math.min(slotWidth * 0.055, 1.5 + distFromCenter * 1.6)
                readonly property real shadowBoost: 1 + distFromCenter * 0.30

                // Independent motion.
                readonly property int backIndex: Math.max(0, Math.min(root.targetSamples - 1, modelData + Math.round(sideSign * (1 + distFromCenter))))
                readonly property real frontRaw: root.smoothValues[modelData] ?? 0
                readonly property real shiftedRaw: root.smoothValues[backIndex] ?? frontRaw

                readonly property real frontValue: Math.min(1, Math.max(0.006, frontRaw * 1.02))
                readonly property real backValue: Math.min(1, Math.max(0.008, shiftedRaw * 1.02 + frontRaw * 0.12))

                // Keep both bars attached to the floor while giving them more presence.
                readonly property real minBackHeight: root.height * 0.20
                readonly property real minFrontHeight: minBackHeight * 0.66
                readonly property real maxBackHeight: root.height * 0.78
                readonly property real maxFrontHeight: maxBackHeight * 0.58

                readonly property real backHeight: Math.min(
                    maxBackHeight,
                    minBackHeight + Math.pow(backValue, 0.66) * (maxBackHeight - minBackHeight) * Math.min(shadowBoost, 1.16)
                )

                readonly property real frontHeight: Math.min(
                    maxFrontHeight,
                    minFrontHeight + Math.pow(frontValue, 0.82) * (maxFrontHeight - minFrontHeight) * Math.min(shadowBoost, 1.08)
                )
                readonly property real shadowHeight: Math.max(root.height * 0.18, Math.min(root.height * 0.44, root.height * 0.16 + Math.pow(frontValue, 0.72) * root.height * 0.32))

                x: barGap + modelData * (barWidth + barGap)
                anchors.bottom: parent.bottom
                width: barWidth
                height: root.height
                clip: false
                opacity: 1

                Rectangle {
                    id: backPill

                    z: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom

                    width: parent.width * 0.82
                    height: visualBar.backHeight
                    topLeftRadius: Math.min(width / 2, 11)
                    topRightRadius: topLeftRadius
                    bottomLeftRadius: 0
                    bottomRightRadius: 0
                    opacity: 0.80

                    gradient: Gradient {
                        orientation: Gradient.Vertical

                        GradientStop {
                            position: 0
                            color: Qt.alpha(Colours.palette.m3primary, 0.54)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.alpha(Colours.palette.m3primaryContainer, 0.40)
                        }
                    }

                    Behavior on height {
                        Anim {
                            duration: Appearance.anim.durations.small
                        }
                    }

                }

                Rectangle {
                    id: frontPill

                    z: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: visualBar.shadowOffset
                    anchors.bottom: parent.bottom

                    width: parent.width * 1.24
                    height: visualBar.shadowHeight
                    topLeftRadius: Math.min(width / 2, 9)
                    topRightRadius: topLeftRadius
                    bottomLeftRadius: 0
                    bottomRightRadius: 0
                    opacity: 0.48

                    gradient: Gradient {
                        orientation: Gradient.Vertical

                        GradientStop {
                            position: 0
                            color: Qt.alpha("white", 0.34)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.alpha(Colours.palette.m3secondary, 0.36)
                        }
                    }

                    Behavior on height {
                        Anim {
                            duration: Appearance.anim.durations.small
                        }
                    }

                }

                Behavior on opacity {
                    Anim {}
                }
            }
        }
    }

    function valueAt(source, pos) {
        if (!source || source.length === 0)
            return 0;

        const scaled = pos * (source.length - 1);
        const left = Math.floor(scaled);
        const right = Math.min(source.length - 1, left + 1);
        const blend = scaled - left;
        return Math.max(0, Math.min(1, (source[left] ?? 0) * (1 - blend) + (source[right] ?? 0) * blend));
    }

    function updateFrame(): void {
        if (!waveEnabled || targetSamples <= 0)
            return;

        const source = Audio.cava.values ?? [];
        const next = [];
        let sum = 0;

        for (let i = 0; i < targetSamples; i++) {
            const rawTarget = valueAt(source, targetSamples <= 1 ? 0 : i / (targetSamples - 1));
            const target = Math.min(1, Math.pow(rawTarget, 0.82) * 0.98);
            const previous = smoothValues[i] ?? 0;
            const attack = target > previous ? 0.38 : 0.14;
            const value = previous + (target - previous) * attack;
            next.push(value);
            sum += value;
        }

        smoothValues = next;
        level = next.length > 0 ? sum / next.length : 0;
            if (level > 0.015)
                backPhase += 0.08 + Math.min(0.12, level * 0.24);
            waves.requestPaint();
    }

    Canvas {
        id: waves

        property real phase: 0

        anchors.fill: parent
        anchors.leftMargin: root.sideInset
        anchors.rightMargin: root.sideInset
        antialiasing: true
        visible: root.showWaves
        opacity: Math.max(0.68, Math.min(0.95, root.liveOpacity + 0.18))
        z: 4

        function css(colour, alpha) {
            const c = Qt.color(colour.toString());
            const a = Math.max(0, Math.min(1, alpha));
            return `rgba(${Math.round(c.r * 255)}, ${Math.round(c.g * 255)}, ${Math.round(c.b * 255)}, ${a})`;
        }

        function sampleAt(values, pos) {
            if (!values || values.length === 0)
                return 0;

            const scaled = pos * (values.length - 1);
            const left = Math.floor(scaled);
            const right = Math.min(values.length - 1, left + 1);
            const blend = scaled - left;
            return Math.max(0, Math.min(1, (values[left] ?? 0) * (1 - blend) + (values[right] ?? 0) * blend));
        }

        function drawWave(ctx, values, w, h, layer) {
            const lowerLine = layer === 0;
            const baseY = lowerLine ? h - 18 : h - Math.max(22, root.height * 0.20);
            const amplitude = h * (lowerLine ? 0.065 : 0.040) * root.waveAmplitude;
            const step = Math.max(lowerLine ? 7 : 5, w / (lowerLine ? 220 : 270));
            const phaseShift = lowerLine ? phase : -phase + 1.1;
            const sampleOffset = lowerLine ? Math.sin(phase) * 0.018 : Math.cos(phase) * 0.014;

            ctx.beginPath();
            for (let x = 0; x <= w + step; x += step) {
                const pos = Math.max(0, Math.min(1, x / Math.max(1, w) + sampleOffset));
                const sample = sampleAt(values, pos);
                const drift = lowerLine
                    ? Math.sin(x * 0.014 + phaseShift) * 3.8 + Math.sin(x * 0.004 - phase * 2) * 1.2
                    : Math.sin(x * 0.012 + phaseShift) * 2.0 + Math.cos(x * 0.005 - phase) * 0.8;
                const y = baseY - Math.pow(sample, lowerLine ? 0.68 : 0.78) * amplitude + drift;

                if (x === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }

            ctx.strokeStyle = css(lowerLine ? Colours.palette.m3primary : Colours.palette.m3secondary, lowerLine ? 0.86 : 0.46);
            ctx.lineWidth = lowerLine ? 2.8 : 1.2;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.stroke();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const w = width;
            const h = height;
            if (w <= 0 || h <= 0)
                return;

            const values = root.smoothValues ?? [];
            drawWave(ctx, values, w, h, 1);
            drawWave(ctx, values, w, h, 0);
        }

        onPhaseChanged: requestPaint()

        NumberAnimation on phase {
            from: 0
            to: Math.PI * 2
            duration: 2200
            loops: Animation.Infinite
            running: root.visible && root.waveEnabled && root.showWaves
        }

        Component.onCompleted: requestPaint()

        Connections {
            function onPaletteChanged() {
                waves.requestPaint();
            }

            target: Colours
        }
    }

    Timer {
        interval: Math.max(16, Math.floor(1000 / Math.max(1, root.waveFps)))
        running: root.visible && root.waveEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateFrame()
    }

    Behavior on opacity {
        Anim {}
    }
}
