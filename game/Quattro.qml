import QtQuick
import QtQuick.Shapes

// A Group B Quattro seen from above, drawn nose-first along +x so the whole car
// rotates to aim. What makes the silhouette read as a Quattro is the blistered
// wheel arches and the boxy, square-shouldered body, so those are drawn heavier
// than anything else.
Item {
    id: car

    property var tower: null
    property var def: null
    property int level: 0
    property bool stunned: false
    // 1 when the stun lands, draining to 0 as it wears off.
    property real stunFraction: 0
    property real heading: 0
    property bool selected: false
    property bool hovered: false
    property bool ghost: false
    property bool valid: true
    property real range: 0
    // Shop previews and the placement ghost suppress the rank badge; parked
    // cars always show it.
    property bool showRank: true

    // One colour for "developments bought" and a different one once the car is
    // finished, so a maxed car is distinguishable at a glance from a car one
    // step short of it.
    readonly property color rankColor: level >= Balance.maxLevel()
                                       ? Theme.brightMagenta : Theme.brightYellow

    readonly property real muzzleOffset: def && def.weapon === "laseretch" ? 54 : 38

    readonly property color hue: {
        if (ghost && !valid)
            return Theme.red;
        return def ? (Theme[def.hue] || Theme.accent) : Theme.accent;
    }
    readonly property color shell: Theme.mix(Theme.fgBright, hue, 0.55)
    readonly property color shellDark: Qt.darker(shell, 1.55)
    // Mode-aware: the bodywork is built from the foreground, so on a light
    // theme the body goes dark and a dark outline would disappear into it.
    readonly property color ink: Theme.ink
    readonly property color rubber: Theme.rubber

    // The art is authored in a 104x54 space; this shrinks the whole car on the
    // board without touching a single drawing coordinate. It is a transform
    // rather than the `scale` property so callers that scale the car for their
    // own reasons — the shop cards — still compose on top of it.
    property real bodyScale: Balance.carScale

    width: Balance.carW
    height: Balance.carH
    rotation: heading
    opacity: ghost ? 0.72 : stunned ? 0.55 : 1

    Behavior on opacity { NumberAnimation { duration: 140 } }

    transform: Scale {
        origin.x: car.width / 2
        origin.y: car.height / 2
        xScale: car.bodyScale
        yScale: car.bodyScale
    }

    // ---- range ring -------------------------------------------------------
    Rectangle {
        visible: car.selected || car.hovered || car.ghost
        width: car.range * 2
        height: width
        radius: width / 2
        anchors.centerIn: parent
        color: Theme.alpha(car.hue, 0.055)
        border.width: 2
        border.color: Theme.alpha(car.ghost && !car.valid ? Theme.red : car.hue, 0.55)
        rotation: -car.rotation
    }

    // ---- parking bay ------------------------------------------------------
    Rectangle {
        anchors.centerIn: parent
        width: 96
        height: 60
        radius: 30
        rotation: -car.rotation
        color: Theme.alpha(Theme.bg, 0.45)
        border.width: car.selected ? 2 : 0
        border.color: Theme.alpha(car.hue, 0.9)
    }

    Rectangle {
        x: 10
        y: 14
        width: 84
        height: 26
        radius: 10
        color: Theme.shadow
    }

    // ---- rear wing --------------------------------------------------------
    Rectangle {
        readonly property bool big: car.def && car.def.id === "s1"
        x: big ? 0 : 3
        y: big ? -3 : 1
        width: big ? 12 : 9
        height: car.height - 2 * y
        radius: 2
        color: car.shellDark
        border.width: 1.5
        border.color: car.ink
    }

    // ---- body, with blistered arches --------------------------------------
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 2.5
            strokeColor: car.ink
            joinStyle: ShapePath.MiterJoin
            fillGradient: LinearGradient {
                x1: 0; y1: 6; x2: 0; y2: 48
                GradientStop { position: 0.0; color: Qt.lighter(car.shell, 1.4) }
                GradientStop { position: 0.5; color: car.shell }
                GradientStop { position: 1.0; color: car.shellDark }
            }

            // Straight segments only: the Quattro is a box with blisters
            // bolted on, not a curvy shape.
            startX: 10; startY: 16
            PathLine { x: 16; y: 16 }
            PathLine { x: 19; y: 10 }   // rear arch
            PathLine { x: 37; y: 10 }
            PathLine { x: 40; y: 16 }
            PathLine { x: 60; y: 16 }
            PathLine { x: 63; y: 10 }   // front arch
            PathLine { x: 81; y: 10 }
            PathLine { x: 84; y: 16 }
            PathLine { x: 90; y: 18 }   // nose
            PathLine { x: 94; y: 24 }
            PathLine { x: 94; y: 30 }
            PathLine { x: 90; y: 36 }
            PathLine { x: 84; y: 38 }
            PathLine { x: 81; y: 44 }
            PathLine { x: 63; y: 44 }
            PathLine { x: 60; y: 38 }
            PathLine { x: 40; y: 38 }
            PathLine { x: 37; y: 44 }
            PathLine { x: 19; y: 44 }
            PathLine { x: 16; y: 38 }
            PathLine { x: 10; y: 38 }
            PathLine { x: 8; y: 30 }
            PathLine { x: 8; y: 24 }
            PathLine { x: 10; y: 16 }
        }
    }

    // ---- wheels, drawn over the arches so the tyres actually show ---------
    Repeater {
        model: [
            { wx: 17, wy: 3 }, { wx: 17, wy: 40 },
            { wx: 61, wy: 3 }, { wx: 61, wy: 40 }
        ]
        Rectangle {
            required property var modelData
            x: modelData.wx
            y: modelData.wy
            width: 22
            height: 11
            radius: 3
            color: car.rubber
            border.width: 1.5
            border.color: Theme.alpha(Theme.fgBright, 0.4)

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 9
                height: 2
                color: Theme.alpha(Theme.fgBright, 0.5)
            }
        }
    }

    // ---- flank stripe -----------------------------------------------------
    Rectangle {
        x: 16
        y: 25
        width: 46
        height: 4
        color: Theme.alpha(Theme.fgBright, 0.8)
    }

    // ---- greenhouse -------------------------------------------------------
    Rectangle {
        x: 36
        y: 16
        width: 26
        height: 22
        radius: 4
        color: Theme.mix(Theme.bg, car.hue, 0.35)
        border.width: 2
        border.color: car.ink
    }

    // windscreen
    Rectangle {
        x: 58
        y: 18
        width: 5
        height: 18
        radius: 2
        color: Theme.alpha(car.hue, 0.8)
    }

    // ---- rally roundel ----------------------------------------------------
    Rectangle {
        x: 18
        y: 19
        width: 17
        height: 17
        radius: 8.5
        color: Theme.alpha(Theme.fgBright, 0.9)
        border.width: 1.5
        border.color: car.ink

        Text {
            anchors.centerIn: parent
            rotation: -car.rotation
            text: car.def ? String(1 + Balance.towers.findIndex(t => t.id === car.def.id)) : "0"
            font.family: Theme.mono
            font.pixelSize: 11
            font.bold: true
            color: car.ink
        }
    }

    // ---- weapon rig, one per ttfx effect ----------------------------------
    Loader {
        active: car.def !== null
        sourceComponent: {
            if (!car.def)
                return null;
            switch (car.def.weapon) {
            case "binarypath": return antennaRig;
            case "matrix": return rainRig;
            case "laseretch": return laserRig;
            case "fireworks": return mortarRig;
            case "blackhole": return ringRig;
            case "colorshift": return bargeRig;
            case "highlight": return paceRig;
            }
            return null;
        }
    }

    Component {
        id: antennaRig
        Item {
            Repeater {
                model: [21, 30]
                Rectangle {
                    required property var modelData
                    x: 46
                    y: modelData
                    width: 26
                    height: 2
                    color: car.ink
                    Rectangle {
                        x: parent.width - 3
                        y: -2.5
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.fgBright
                        border.width: 1
                        border.color: car.ink
                    }
                }
            }
        }
    }

    Component {
        id: rainRig
        Item {
            Rectangle {
                x: 40
                y: 12
                width: 18
                height: 30
                radius: 3
                color: Theme.alpha(car.hue, 0.4)
                border.width: 1.5
                border.color: car.ink
            }
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: 43 + index * 6
                    y: 16
                    width: 2.5
                    height: 22
                    color: Theme.brightGreen
                }
            }
        }
    }

    Component {
        id: laserRig
        Item {
            Rectangle {
                x: 40
                y: 23
                width: 56
                height: 9
                radius: 3
                color: car.shellDark
                border.width: 1.5
                border.color: car.ink
            }
            Rectangle {
                x: 94
                y: 24
                width: 7
                height: 7
                radius: 3.5
                color: Theme.fgBright
            }
        }
    }

    Component {
        id: mortarRig
        Item {
            Rectangle {
                x: 36
                y: 14
                width: 26
                height: 26
                radius: 13
                color: car.shellDark
                border.width: 2
                border.color: car.ink
            }
            Rectangle {
                x: 42
                y: 20
                width: 14
                height: 14
                radius: 7
                color: Theme.orange
                border.width: 1.5
                border.color: car.ink
            }
        }
    }

    Component {
        id: ringRig
        Item {
            Rectangle {
                x: 34
                y: 12
                width: 30
                height: 30
                radius: 15
                color: "transparent"
                border.width: 3
                border.color: Theme.cyan

                RotationAnimator on rotation {
                    from: 0; to: 360; duration: 2600
                    loops: Animation.Infinite; running: !car.ghost
                }
                Rectangle {
                    x: 12
                    y: -4
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Theme.brightCyan
                    border.width: 1
                    border.color: car.ink
                }
            }
        }
    }

    Component {
        id: bargeRig
        Item {
            // flat bed with spares strapped down
            Rectangle {
                x: 20
                y: 14
                width: 42
                height: 26
                radius: 3
                color: car.shellDark
                border.width: 1.5
                border.color: car.ink
            }
            Repeater {
                model: [[25, 17], [25, 28], [44, 17], [44, 28]]
                Rectangle {
                    required property var modelData
                    x: modelData[0]
                    y: modelData[1]
                    width: 12
                    height: 10
                    radius: 2
                    color: Theme.alpha(Theme.brightYellow, 0.85)
                    border.width: 1
                    border.color: car.ink
                }
            }
        }
    }

    Component {
        id: paceRig
        Item {
            // roof light bar
            Rectangle {
                x: 40
                y: 13
                width: 10
                height: 28
                radius: 3
                color: car.shellDark
                border.width: 1.5
                border.color: car.ink
            }
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    x: 42
                    y: 16 + index * 12
                    width: 6
                    height: 10
                    radius: 2
                    color: index === 0 ? Theme.brightBlue : Theme.brightYellow

                    SequentialAnimation on opacity {
                        running: !car.ghost
                        loops: Animation.Infinite
                        NumberAnimation { to: index === 0 ? 0.25 : 1; duration: 480 }
                        NumberAnimation { to: index === 0 ? 1 : 0.25; duration: 480 }
                    }
                }
            }
        }
    }

    // ---- rank plate -------------------------------------------------------
    // Three bars for the three developments a car can buy, filled one at a
    // time: an outlined bar is a development still available, a filled one is a
    // development already paid for. A fully developed car lights all three in
    // its own colour, so the top tier reads as a state change rather than as
    // "one more bar".
    //
    // It is bolted to the car in its own coordinate space rather than counter-
    // rotated, so it swings with the bodywork and the car can never turn into
    // it. Mounting it off the tail is what keeps it off the asphalt too: a
    // parked car rotates to aim AT the circuit, so its rear always points away
    // from the road.
    Rectangle {
        id: rankPlate

        readonly property int steps: Balance.maxLevel()

        x: -width - 6
        y: (car.height - height) / 2
        width: 23
        height: steps * 6 + (steps - 1) * 3 + 10
        radius: 4
        visible: !car.ghost && car.showRank
        z: 35
        color: Theme.alpha(Theme.bg, 0.70)

        Column {
            anchors.centerIn: parent
            spacing: 3

            Repeater {
                model: rankPlate.steps
                Rectangle {
                    required property int index
                    // Drawn top-down, so the plate fills from the bottom up.
                    readonly property int step: rankPlate.steps - index
                    readonly property bool filled: car.level >= step

                    width: 13
                    height: 6
                    radius: 2
                    color: filled ? car.rankColor : "transparent"
                    border.width: filled ? 0 : 1
                    border.color: Theme.alpha(Theme.fg, 0.38)
                }
            }
        }
    }

    // ---- support pulse ----------------------------------------------------
    Rectangle {
        id: pulseRing
        anchors.centerIn: parent
        width: 0
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.alpha(car.hue, 0.6)
        opacity: 0
        rotation: -car.rotation

        ParallelAnimation {
            id: pulseAnim
            running: false
            NumberAnimation { target: pulseRing; property: "width"; from: 40; to: Math.max(80, car.range * 2)
                              duration: 900; easing.type: Easing.OutCubic }
            SequentialAnimation {
                NumberAnimation { target: pulseRing; property: "opacity"; from: 0; to: 0.5; duration: 140 }
                NumberAnimation { target: pulseRing; property: "opacity"; to: 0; duration: 760 }
            }
        }
    }

    // ---- stunned ----------------------------------------------------------
    // A stun has to answer three questions at a glance, from across the board:
    // which car, is it going to end, and is it firing right now. So: a hard
    // ring in the boss's own colour to catch the eye, an arc that drains so the
    // wait is visible, and the bodywork drained of colour underneath so a
    // frozen car never reads as a working one.
    Item {
        id: stunMark
        anchors.centerIn: parent
        visible: car.stunned
        rotation: -car.rotation
        z: 40

        Rectangle {
            anchors.centerIn: parent
            width: 92
            height: 92
            radius: 46
            color: Theme.alpha(Theme.magenta, 0.26)
            border.width: 2
            border.color: Theme.alpha(Theme.brightMagenta, 0.9)

            // Pulses so a stunned car is findable by movement, not only colour
            // — which matters on a palette where magenta is not very magenta.
            SequentialAnimation on scale {
                running: car.stunned
                loops: Animation.Infinite
                NumberAnimation { from: 0.86; to: 1.06; duration: 520; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.06; to: 0.86; duration: 520; easing.type: Easing.InOutSine }
            }
        }

        // Remaining time, drawn as a shrinking bar under the car.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 34
            width: 62
            height: 5
            radius: 2.5
            color: Theme.alpha(Theme.bg, 0.75)

            Rectangle {
                width: parent.width * car.stunFraction
                height: parent.height
                radius: parent.radius
                color: Theme.brightMagenta
            }
        }

        Text {
            anchors.centerIn: parent
            text: "✖"
            font.family: Theme.mono
            font.pixelSize: 30
            font.bold: true
            color: Theme.brightMagenta
            style: Text.Outline
            styleColor: Theme.alpha(Theme.bg, 0.85)
        }
    }

    // ---- muzzle flash -----------------------------------------------------
    Rectangle {
        id: flash
        x: 46 + car.muzzleOffset - 8
        y: 23
        width: 16
        height: 9
        radius: 4
        color: Theme.fgBright
        opacity: 0
        NumberAnimation on opacity {
            id: flashAnim
            running: false
            from: 0.95
            to: 0
            duration: 110
        }
    }

    function fire(): void {
        flashAnim.restart();
    }

    function pulse(): void {
        pulseAnim.restart();
    }
}
