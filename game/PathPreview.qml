import QtQuick

// The demonstration lap. Before the first car is parked, a harmless ghost take
// drives the route at speed while arrows march along the asphalt, so the very
// first thing a new player learns is which way the traffic comes and where it
// is heading. It disappears the moment they commit to a bay.
Item {
    id: preview

    property Sim sim: null

    readonly property bool showing: sim && sim.started && !sim.over
                                    && sim.waves && !sim.waves.armed

    anchors.fill: parent
    visible: opacity > 0
    opacity: showing ? 1 : 0
    z: 4

    Behavior on opacity { NumberAnimation { duration: 260 } }

    // Sampled once per circuit rather than per frame; the route does not move.
    readonly property var arrows: {
        const out = [];
        const total = Balance.trackLength;
        const step = 132;
        for (let d = 0; d < total; d += step) {
            const p = Balance.pointAt(d);
            out.push({ x: p.x, y: p.y, angle: p.angle, t: d / total });
        }
        return out;
    }

    // ---- direction arrows --------------------------------------------------
    Repeater {
        model: preview.showing ? preview.arrows : []

        Text {
            required property var modelData

            x: modelData.x - width / 2
            y: modelData.y - height / 2
            rotation: modelData.angle
            text: "➤"
            font.family: Theme.mono
            font.pixelSize: 22
            color: Theme.accent

            // A travelling wave of brightness, so the arrows read as motion in
            // one direction instead of as static decoration.
            opacity: 0.25 + 0.65 * Math.max(0, 1 - Math.abs(((pulse.phase - modelData.t + 1.5) % 1) - 0.5) * 5)
        }
    }

    QtObject {
        id: pulse
        property real phase: 0
        // Declared here rather than on the Repeater so one animation drives
        // every arrow instead of one animation per arrow.
        readonly property NumberAnimation anim: NumberAnimation {
            target: pulse
            property: "phase"
            running: preview.showing
            from: 0
            to: 1
            duration: 2200
            loops: Animation.Infinite
        }
    }

    // ---- the ghost take ----------------------------------------------------
    property real runnerDist: 0

    readonly property var runnerPoint: Balance.pointAt(runnerDist)

    NumberAnimation on runnerDist {
        running: preview.showing
        from: 0
        to: Balance.trackLength
        // A fixed lap time regardless of circuit length, so Spa does not take
        // three times as long to demonstrate as Monaco.
        duration: 7000
        loops: Animation.Infinite
    }

    Item {
        x: preview.runnerPoint.x
        y: preview.runnerPoint.y

        Creature {
            anchors.centerIn: parent
            width: 44
            height: 44
            bodySize: 44
            spec: ({ form: "ghost", eyes: 2 })
            hue: Theme.accent
            spooky: true
            opacity: 0.75
        }

    }

    // ---- the instruction ---------------------------------------------------
    // Circuits fill the field differently, so the banner is not anchored to a
    // fixed edge: it is dropped into whichever candidate spot sits furthest from
    // the asphalt. Text over the racing line makes the route harder to read,
    // which is the one thing this panel exists to make easier.
    readonly property real bannerW: 700
    readonly property var bannerSpot: {
        // Named explicitly so the binding re-runs when the circuit changes;
        // the clearance below only reaches the route through a function call.
        const lap = Balance.trackLength;
        const w = bannerW / 2 - 20;
        const candidates = [
            { x: Balance.fieldW / 2, y: 58 },
            { x: Balance.fieldW / 2, y: Balance.fieldH - 58 },
            { x: Balance.fieldW / 2, y: Balance.fieldH / 2 },
            { x: Balance.fieldW * 0.32, y: Balance.fieldH - 58 },
            { x: Balance.fieldW * 0.68, y: Balance.fieldH - 58 },
            { x: Balance.fieldW * 0.32, y: 58 },
            { x: Balance.fieldW * 0.68, y: 58 }
        ];

        let best = candidates[0];
        let bestClearance = -1;
        for (const c of candidates) {
            // The banner is wide, so clearance is the worst point along it, not
            // the distance from its centre.
            let clearance = Infinity;
            for (let i = -2; i <= 2; i++)
                clearance = Math.min(clearance, Balance.distanceToTrack(c.x + i * w / 2, c.y));
            if (clearance > bestClearance) {
                bestClearance = clearance;
                best = c;
            }
        }
        return best;
    }

    Rectangle {
        x: preview.bannerSpot.x - width / 2
        y: preview.bannerSpot.y - height / 2
        width: banner.implicitWidth + 44
        height: 58
        radius: Theme.radiusLarge
        color: Theme.alpha(Theme.bgPanel, 0.94)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.45)

        Column {
            id: banner
            anchors.centerIn: parent
            spacing: 3

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "PARK YOUR FIRST CAR TO START THE CLOCK"
                font.family: Theme.mono
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 2
                color: Theme.fgBright
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Takes run the arrows and cross the start/finish line. Nothing moves until you are ready."
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.fgDim
            }
        }
    }
}
