pragma ComponentBehavior: Bound

import qs.services
import QtQuick

Item {
    id: root

    readonly property int cellSize: 16
    readonly property int columnSpacing: 18
    readonly property int dropCount: 12
    readonly property string symbols: "0123456789!@#$%^&*()-_=+[]{}|;:,.<>?abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    readonly property string headColour: Colours.palette.m3onPrimary.toString()
    readonly property var bodyColours: [
        Colours.palette.m3primary.toString(),
        Colours.palette.m3secondary.toString(),
        Colours.palette.m3tertiary.toString(),
        Colours.palette.m3inversePrimary.toString(),
        Colours.palette.m3outline.toString()
    ]
    readonly property var bodyAlpha: [0.82, 0.78, 0.70, 0.68, 0.58]
    property var drops: []
    property int tickCount
    property int glyphPhase

    width: Math.min(parent?.width ? parent.width * 0.1 : 180, 180)
    height: Math.min(parent?.height ? parent.height * 0.46 : 420, 480)
    opacity: 1

    function randomDrop(): var {
        const columns = Math.max(1, Math.floor(width / columnSpacing));
        const longDrop = Math.random() < 0.38;
        return {
            y: -Math.random() * height * 0.92,
            col: Math.floor(Math.random() * columns),
            len: longDrop ? 12 + Math.floor(Math.random() * 19) : 3 + Math.floor(Math.random() * 8),
            speed: 1.2 + Math.random() * 2.8,
            colour: Math.floor(Math.random() * 5),
            dim: Math.random() < 0.22,
            seed: Math.floor(Math.random() * 997)
        };
    }

    function resetDrops(): void {
        const next = [];
        for (let i = 0; i < dropCount; i++)
            next.push(randomDrop());
        drops = next;
    }

    function glyphAt(index: int): string {
        return symbols.charAt(Math.abs(index) % symbols.length);
    }

    function tick(): void {
        if (drops.length !== dropCount)
            resetDrops();

        for (let i = 0; i < drops.length; i++) {
            const drop = drops[i];
            drop.y += drop.speed;
            if (drop.y - drop.len * cellSize > height)
                drops[i] = randomDrop();
        }
        tickCount++;
        if (tickCount % 9 === 0)
            glyphPhase++;
        canvas.requestPaint();
    }

    onWidthChanged: resetDrops()
    onHeightChanged: resetDrops()
    Component.onCompleted: resetDrops()

    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: false

        function dropColour(drop, head) {
            if (head)
                return root.headColour;
            return root.bodyColours[Math.max(0, Math.min(root.bodyColours.length - 1, drop.colour))];
        }

        function dropAlpha(drop, alpha, head) {
            if (head)
                return alpha * 0.92;
            return alpha * root.bodyAlpha[Math.max(0, Math.min(root.bodyAlpha.length - 1, drop.colour))];
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const w = width;
            const h = height;
            if (w <= 0 || h <= 0)
                return;

            ctx.font = "bold 14px monospace";
            ctx.textBaseline = "top";

            for (let i = 0; i < root.drops.length; i++) {
                const drop = root.drops[i];
                const x = drop.col * root.columnSpacing;

                for (let row = 0; row < drop.len; row++) {
                    const y = drop.y - row * root.cellSize;
                    if (y < -root.cellSize || y > h)
                        continue;

                    if (((drop.seed + row * 13) % 17) === 0)
                        continue;

                    const tailFade = Math.pow(1 - row / Math.max(1, drop.len), 0.88);
                    const bottomFade = Math.max(0, Math.min(1, (h - y) / Math.max(1, h * 0.22)));
                    const topFade = Math.max(0, Math.min(1, (y + root.cellSize) / Math.max(1, h * 0.12)));
                    const alpha = (drop.dim ? 0.38 : 0.78) * tailFade * bottomFade * topFade;
                    const morph = ((drop.seed + row * 5 + root.glyphPhase) % 7) === 0 ? root.glyphPhase : 0;
                    const isHead = row === 0;
                    ctx.fillStyle = dropColour(drop, isHead);
                    ctx.globalAlpha = dropAlpha(drop, alpha, isHead);
                    ctx.fillText(root.glyphAt(drop.seed + i * 23 + row * 11 + morph), x, y);
                }
            }
            ctx.globalAlpha = 1;
        }
    }

    Timer {
        interval: 80
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }
}
