pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property color accent: "#cba6f7"
    readonly property string mood: classify(accent)
    property bool transforming

    signal changed()

    visible: false

    function classify(c: color): string {
        const saturation = c.hslSaturation;
        const lightness = c.hslLightness;

        if (saturation < 0.18 || lightness < 0.14)
            return "ink";

        const hue = c.hslHue * 360;
        if (hue < 65 || hue >= 330)
            return "ember";
        if (hue < 170)
            return "spirit";
        if (hue < 245)
            return "frost";
        if (hue < 330)
            return "void";
        return "ink";
    }

    onAccentChanged: {
        transforming = true;
        changed();
        reformTimer.restart();
    }

    Timer {
        id: reformTimer

        interval: 900
        repeat: false
        onTriggered: root.transforming = false
    }
}
