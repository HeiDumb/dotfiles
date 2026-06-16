import qs.components
import qs.services
import qs.config
import qs.utils
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real playerProgress: 0
    property real visualiserPeak: 0
    property var visualiserNode: null

    function syncPlayerProgress(): void {
        const active = Players.active;
        if (!active?.length) {
            root.playerProgress = 0;
            return;
        }

        root.playerProgress = Math.max(0, Math.min(1, (active.position ?? 0) / active.length));
    }

    function normaliseToken(value: var): string {
        return String(value ?? "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
    }

    function activePlayerTokens(): var {
        const active = Players.active;
        const seeds = [
            active ? Players.getIdentity(active) : "",
            active?.identity ?? "",
            active?.desktopEntry ?? ""
        ];
        const tokens = [];

        for (let i = 0; i < seeds.length; ++i) {
            const normalised = root.normaliseToken(seeds[i]);
            if (!normalised)
                continue;

            if (!tokens.includes(normalised))
                tokens.push(normalised);

            const split = normalised.split(/\s+/);
            for (let j = 0; j < split.length; ++j) {
                const token = split[j];
                if (token && !tokens.includes(token))
                    tokens.push(token);
            }
        }

        if (tokens.includes("spotify")) {
            for (const extra of ["audio", "src"]) {
                if (!tokens.includes(extra))
                    tokens.push(extra);
            }
        }

        if (tokens.includes("mozilla") || tokens.includes("zen") || tokens.includes("firefox")) {
            for (const extra of ["mozilla", "zen", "firefox"]) {
                if (!tokens.includes(extra))
                    tokens.push(extra);
            }
        }

        return tokens;
    }

    function streamText(stream: var): string {
        const props = stream?.properties ?? {};
        return root.normaliseToken([
            stream?.name ?? "",
            stream?.description ?? "",
            stream?.nickname ?? "",
            props["application.name"] ?? "",
            props["application.process.binary"] ?? "",
            props["application.id"] ?? "",
            props["media.name"] ?? "",
            props["node.name"] ?? ""
        ].join(" "));
    }

    function streamScore(stream: var): real {
        const text = root.streamText(stream);
        if (!text)
            return -1;

        const props = stream?.properties ?? {};
        let score = 0;
        const tokens = root.activePlayerTokens();
        for (let i = 0; i < tokens.length; ++i) {
            const token = tokens[i];
            if (!token || token.length < 2)
                continue;
            if (text.includes(token))
                score += token.length >= 5 ? 4 : 2;
        }

        const mediaRole = root.normaliseToken(props["media.role"] ?? "");
        const mediaName = root.normaliseToken(props["media.name"] ?? "");
        if (mediaRole === "music")
            score += 1;
        if (mediaName.includes("audio src") && tokens.includes("spotify"))
            score += 6;

        return score;
    }

    function choosePlaybackNode(): var {
        const streams = Audio.streams ?? [];
        let best = null;
        let bestScore = -Infinity;

        for (let i = 0; i < streams.length; ++i) {
            const stream = streams[i];
            if (!stream?.ready || !stream.audio)
                continue;

            const score = root.streamScore(stream);
            if (score > bestScore) {
                best = stream;
                bestScore = score;
            }
        }

        return best ?? streams[0] ?? Audio.sink ?? null;
    }

    function refreshVisualiserNode(): void {
        root.visualiserNode = root.choosePlaybackNode();
    }

    function refreshVisualiserPeak(): void {
        const currentPeak = Math.max(0, peakMonitor.peak ?? 0);
        const attack = currentPeak > root.visualiserPeak ? 0.55 : 0.14;
        root.visualiserPeak = root.visualiserPeak + (currentPeak - root.visualiserPeak) * attack;
    }

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    implicitWidth: Config.dashboard.sizes.mediaWidth

    Behavior on playerProgress {
        Anim {
            duration: Appearance.anim.durations.large
        }
    }

    Timer {
        running: !!Players.active
        interval: Math.max(40, Math.floor(Config.dashboard.mediaUpdateInterval / 4))
        triggeredOnStart: true
        repeat: true
        onTriggered: root.syncPlayerProgress()
    }

    Timer {
        interval: 33
        running: root.visible
        repeat: true
        onTriggered: root.refreshVisualiserPeak()
    }

    Timer {
        interval: 1000
        running: root.visible
        triggeredOnStart: true
        repeat: true
        onTriggered: root.refreshVisualiserNode()
    }

    Connections {
        target: Players

        function onActiveChanged() {
            root.syncPlayerProgress()
            root.refreshVisualiserNode()
        }
    }

    Connections {
        target: Players.active

        function onPositionChanged() {
            root.syncPlayerProgress()
        }

        function onLengthChanged() {
            root.syncPlayerProgress()
        }

        function onIsPlayingChanged() {
            root.syncPlayerProgress()
        }

        function onPostTrackChanged() {
            root.refreshVisualiserNode()
        }

        function onIdentityChanged() {
            root.refreshVisualiserNode()
        }
    }

    Component.onCompleted: {
        root.syncPlayerProgress()
        root.refreshVisualiserNode()
        root.refreshVisualiserPeak()
    }

    PwNodePeakMonitor {
        id: peakMonitor
        node: root.visualiserNode
        enabled: root.visible && !!root.visualiserNode
    }

    Connections {
        target: peakMonitor

        function onPeakChanged() {
            root.refreshVisualiserPeak()
        }
    }

    Shape {
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
            strokeWidth: Config.dashboard.sizes.mediaProgressThickness
            capStyle: Appearance.rounding.scale === 0 ? ShapePath.SquareCap : ShapePath.RoundCap

            PathAngleArc {
                centerX: cover.x + cover.width / 2
                centerY: cover.y + cover.height / 2
                radiusX: (cover.width + Config.dashboard.sizes.mediaProgressThickness) / 2 + Appearance.spacing.small
                radiusY: (cover.height + Config.dashboard.sizes.mediaProgressThickness) / 2 + Appearance.spacing.small
                startAngle: -90 - Config.dashboard.sizes.mediaProgressSweep / 2
                sweepAngle: Config.dashboard.sizes.mediaProgressSweep
            }

            Behavior on strokeColor {
                CAnim {}
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Colours.palette.m3primary
            strokeWidth: Config.dashboard.sizes.mediaProgressThickness
            capStyle: Appearance.rounding.scale === 0 ? ShapePath.SquareCap : ShapePath.RoundCap

            PathAngleArc {
                centerX: cover.x + cover.width / 2
                centerY: cover.y + cover.height / 2
                radiusX: (cover.width + Config.dashboard.sizes.mediaProgressThickness) / 2 + Appearance.spacing.small
                radiusY: (cover.height + Config.dashboard.sizes.mediaProgressThickness) / 2 + Appearance.spacing.small
                startAngle: -90 - Config.dashboard.sizes.mediaProgressSweep / 2
                sweepAngle: Config.dashboard.sizes.mediaProgressSweep * root.playerProgress
            }

            Behavior on strokeColor {
                CAnim {}
            }
        }
    }

    StyledClippingRect {
        id: cover

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Appearance.padding.large + Config.dashboard.sizes.mediaProgressThickness + Appearance.spacing.small

        implicitHeight: width
        color: Colours.tPalette.m3surfaceContainerHigh
        radius: Infinity

        MaterialIcon {
            anchors.centerIn: parent

            grade: 200
            text: "art_track"
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: (parent.width * 0.4) || 1
        }

        Image {
            id: image

            anchors.fill: parent

            source: Players.active?.trackArtUrl ?? "" // qmllint disable incompatible-type
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: width
            sourceSize.height: height
        }
    }

    StyledText {
        id: title

        anchors.top: cover.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Appearance.spacing.normal

        animate: true
        horizontalAlignment: Text.AlignHCenter
        text: (Players.active?.trackTitle ?? qsTr("No media")) || qsTr("Unknown title")
        color: Colours.palette.m3primary
        font.pointSize: Appearance.font.size.normal

        width: parent.implicitWidth - Appearance.padding.large * 2
        elide: Text.ElideRight
    }

    StyledText {
        id: album

        anchors.top: title.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Appearance.spacing.small

        animate: true
        horizontalAlignment: Text.AlignHCenter
        text: (Players.active?.trackAlbum ?? qsTr("No media")) || qsTr("Unknown album")
        color: Colours.palette.m3outline
        font.pointSize: Appearance.font.size.small

        width: parent.implicitWidth - Appearance.padding.large * 2
        elide: Text.ElideRight
    }

    StyledText {
        id: artist

        anchors.top: album.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Appearance.spacing.small

        animate: true
        horizontalAlignment: Text.AlignHCenter
        text: (Players.active?.trackArtist ?? qsTr("No media")) || qsTr("Unknown artist")
        color: Colours.palette.m3secondary

        width: parent.implicitWidth - Appearance.padding.large * 2
        elide: Text.ElideRight
    }

    Row {
        id: controls

        anchors.top: artist.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Appearance.spacing.smaller

        spacing: Appearance.spacing.small

        Control {
            icon: "skip_previous"
            canUse: Players.active?.canGoPrevious ?? false

            function onClicked(): void {
                Players.active?.previous();
            }
        }

        Control {
            icon: Players.active?.isPlaying ? "pause" : "play_arrow"
            canUse: Players.active?.canTogglePlaying ?? false

            function onClicked(): void {
                Players.active?.togglePlaying();
            }
        }

        Control {
            icon: "skip_next"
            canUse: Players.active?.canGoNext ?? false

            function onClicked(): void {
                Players.active?.next();
            }
        }
    }

    AnimatedImage {
        id: bongocat

        anchors.top: controls.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Appearance.spacing.small
        anchors.bottomMargin: Appearance.padding.large
        anchors.margins: Appearance.padding.large * 2

        playing: Players.active?.isPlaying ?? false
        speed: 0.7 + root.visualiserPeak * 1.25
        source: Paths.absolutePath(Config.paths.mediaGif)
        asynchronous: true
        fillMode: AnimatedImage.PreserveAspectFit
    }

    component Control: StyledRect {
        id: control

        required property string icon
        required property bool canUse
        function onClicked(): void {
        }

        implicitWidth: Math.max(icon.implicitHeight, icon.implicitHeight) + Appearance.padding.small
        implicitHeight: implicitWidth

        StateLayer {
            disabled: !control.canUse
            radius: Appearance.rounding.full

            function onClicked(): void {
                control.onClicked();
            }
        }

        MaterialIcon {
            id: icon

            anchors.centerIn: parent
            anchors.verticalCenterOffset: font.pointSize * 0.05

            animate: true
            text: control.icon
            color: control.canUse ? Colours.palette.m3onSurface : Colours.palette.m3outline
            font.pointSize: Appearance.font.size.large
        }
    }
}
