import QtQuick
import QtQuick.Shapes

// A parametric little monster. Every bad take gets a body built from the same
// vocabulary — form, eyes, horns, spikes, legs, teeth — so fifteen distinct
// critters cost one component instead of fifteen sprite sheets.
Item {
    id: beast

    property var spec: ({})
    property color hue: Theme.fg
    property real bodySize: 40
    property bool spooky: false      // stealth: drawn as a faint outline

    readonly property string form: spec.form || "blob"
    readonly property int eyeCount: spec.eyes !== undefined ? spec.eyes : 2
    readonly property color ink: Theme.ink
    readonly property color skin: Theme.mix(Theme.bgLift, hue, 0.75)
    readonly property color skinDark: Qt.darker(skin, 1.45)

    width: bodySize
    height: bodySize
    opacity: spooky ? 0.55 : 1

    // idle bob, phase-shifted so a pack does not pulse in lockstep
    transform: Translate {
        id: bob
        y: 0
        SequentialAnimation on y {
            running: true
            loops: Animation.Infinite
            NumberAnimation { to: -beast.bodySize * 0.06; duration: 620 + Math.random() * 360
                              easing.type: Easing.InOutSine }
            NumberAnimation { to: beast.bodySize * 0.06; duration: 620 + Math.random() * 360
                              easing.type: Easing.InOutSine }
        }
    }

    // ---- horns / spikes / antennae, behind the body -----------------------
    Repeater {
        model: beast.spec.horns ? 2 : 0
        Shape {
            id: horn
            required property int index
            // ShapePath is not an Item, so its `parent` is not this Shape;
            // everything it needs has to be reachable by id.
            readonly property real sx: index === 0 ? beast.width * 0.24 : beast.width * 0.76
            readonly property real dir: index === 0 ? -1 : 1

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: beast.skinDark
                strokeColor: beast.ink
                strokeWidth: 1.5
                startX: horn.sx
                startY: beast.height * 0.36
                PathLine { x: horn.sx + horn.dir * beast.width * 0.17; y: beast.height * -0.02 }
                PathLine { x: horn.sx + horn.dir * beast.width * 0.15; y: beast.height * 0.32 }
            }
        }
    }

    Repeater {
        model: beast.spec.spikes ? 3 : 0
        Shape {
            id: spike
            required property int index
            readonly property real cx: beast.width * (0.3 + index * 0.2)

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: beast.skinDark
                strokeColor: beast.ink
                strokeWidth: 1.2
                startX: spike.cx - beast.width * 0.09
                startY: beast.height * 0.3
                PathLine { x: spike.cx; y: beast.height * 0.02 }
                PathLine { x: spike.cx + beast.width * 0.09; y: beast.height * 0.3 }
            }
        }
    }

    Repeater {
        model: beast.spec.antennae ? 2 : 0
        Item {
            required property int index
            readonly property real sx: index === 0 ? beast.width * 0.32 : beast.width * 0.68
            readonly property real dir: index === 0 ? -1 : 1

            Rectangle {
                x: parent.sx
                y: beast.height * 0.02
                width: 2
                height: beast.height * 0.26
                color: beast.ink
                rotation: parent.dir * 22
                transformOrigin: Item.Bottom
            }
            Rectangle {
                x: parent.sx + parent.dir * beast.width * 0.1 - 2.5
                y: beast.height * -0.02
                width: 6
                height: 6
                radius: 3
                color: beast.hue
                border.width: 1
                border.color: beast.ink
            }
        }
    }

    // ---- legs, below the body ---------------------------------------------
    Repeater {
        model: beast.spec.legs || 0
        Rectangle {
            required property int index
            readonly property int n: beast.spec.legs || 1
            x: beast.width * (0.2 + 0.6 * (n === 1 ? 0.5 : index / (n - 1))) - 1.5
            y: beast.height * 0.76
            width: 3
            height: beast.height * 0.24
            radius: 1.5
            color: beast.ink
        }
    }

    // ---- body --------------------------------------------------------------
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: beast.ink
            strokeWidth: beast.spooky ? 1.5 : 2
            fillColor: beast.spooky ? Theme.alpha(beast.skin, 0.35) : beast.skin
            joinStyle: ShapePath.RoundJoin

            readonly property real w: beast.width
            readonly property real h: beast.height

            // Each form is one closed silhouette.
            PathSvg {
                path: {
                    const w = beast.width;
                    const h = beast.height;
                    switch (beast.form) {
                    case "ghost":
                        // domed head, ragged sheet along the bottom
                        return "M " + (w * 0.1) + " " + (h * 0.92)
                             + " L " + (w * 0.1) + " " + (h * 0.48)
                             + " A " + (w * 0.4) + " " + (h * 0.4) + " 0 0 1 " + (w * 0.9) + " " + (h * 0.48)
                             + " L " + (w * 0.9) + " " + (h * 0.92)
                             + " L " + (w * 0.75) + " " + (h * 0.78)
                             + " L " + (w * 0.6) + " " + (h * 0.94)
                             + " L " + (w * 0.45) + " " + (h * 0.78)
                             + " L " + (w * 0.3) + " " + (h * 0.94)
                             + " Z";
                    case "bug":
                        // segmented carapace
                        return "M " + (w * 0.5) + " " + (h * 0.1)
                             + " C " + (w * 0.95) + " " + (h * 0.12) + ", "
                                     + (w * 0.95) + " " + (h * 0.88) + ", "
                                     + (w * 0.5) + " " + (h * 0.92)
                             + " C " + (w * 0.05) + " " + (h * 0.88) + ", "
                                     + (w * 0.05) + " " + (h * 0.12) + ", "
                                     + (w * 0.5) + " " + (h * 0.1)
                             + " Z";
                    case "skull":
                        // cranium plus a squared-off jaw
                        return "M " + (w * 0.12) + " " + (h * 0.44)
                             + " A " + (w * 0.38) + " " + (h * 0.38) + " 0 0 1 " + (w * 0.88) + " " + (h * 0.44)
                             + " L " + (w * 0.88) + " " + (h * 0.62)
                             + " L " + (w * 0.72) + " " + (h * 0.62)
                             + " L " + (w * 0.72) + " " + (h * 0.86)
                             + " L " + (w * 0.28) + " " + (h * 0.86)
                             + " L " + (w * 0.28) + " " + (h * 0.62)
                             + " L " + (w * 0.12) + " " + (h * 0.62)
                             + " Z";
                    case "worm":
                        // low and long, for the quick ones
                        return "M " + (w * 0.04) + " " + (h * 0.62)
                             + " C " + (w * 0.04) + " " + (h * 0.3) + ", "
                                     + (w * 0.42) + " " + (h * 0.24) + ", "
                                     + (w * 0.58) + " " + (h * 0.34)
                             + " C " + (w * 0.82) + " " + (h * 0.2) + ", "
                                     + (w * 0.99) + " " + (h * 0.46) + ", "
                                     + (w * 0.9) + " " + (h * 0.7)
                             + " C " + (w * 0.7) + " " + (h * 0.94) + ", "
                                     + (w * 0.14) + " " + (h * 0.92) + ", "
                                     + (w * 0.04) + " " + (h * 0.62)
                             + " Z";
                    default:
                        // blob: heavy dome with a wobbly base
                        return "M " + (w * 0.08) + " " + (h * 0.66)
                             + " A " + (w * 0.42) + " " + (h * 0.44) + " 0 0 1 " + (w * 0.92) + " " + (h * 0.66)
                             + " C " + (w * 0.92) + " " + (h * 0.94) + ", "
                                     + (w * 0.66) + " " + (h * 0.86) + ", "
                                     + (w * 0.5) + " " + (h * 0.95)
                             + " C " + (w * 0.34) + " " + (h * 0.86) + ", "
                                     + (w * 0.08) + " " + (h * 0.94) + ", "
                                     + (w * 0.08) + " " + (h * 0.66)
                             + " Z";
                    }
                }
            }
        }
    }

    // ---- armour plate ------------------------------------------------------
    Rectangle {
        visible: beast.spec.armored === true
        x: beast.width * 0.28
        y: beast.height * 0.56
        width: beast.width * 0.44
        height: beast.height * 0.2
        radius: 3
        color: Theme.alpha(Theme.fgBright, 0.28)
        border.width: 1.5
        border.color: beast.ink
    }

    // ---- eyes --------------------------------------------------------------
    Row {
        y: beast.height * (beast.form === "worm" ? 0.4 : beast.form === "skull" ? 0.4 : 0.44)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: beast.width * (beast.eyeCount > 2 ? 0.05 : 0.09)

        Repeater {
            model: beast.eyeCount

            Rectangle {
                required property int index
                readonly property real d: beast.width * (beast.eyeCount === 1 ? 0.34
                                                       : beast.eyeCount === 2 ? 0.22 : 0.15)
                width: d
                height: d
                radius: d / 2
                color: beast.form === "skull" ? beast.ink : Theme.fgBright
                border.width: 1.5
                border.color: beast.ink

                // pupil
                Rectangle {
                    visible: beast.form !== "skull"
                    anchors.centerIn: parent
                    width: parent.d * 0.5
                    height: width
                    radius: width / 2
                    color: beast.ink

                    SequentialAnimation on x {
                        running: true
                        loops: Animation.Infinite
                        PauseAnimation { duration: 900 + Math.random() * 2200 }
                        NumberAnimation { to: parent.width * 0.28; duration: 220 }
                        PauseAnimation { duration: 700 }
                        NumberAnimation { to: parent.width * 0.22; duration: 220 }
                    }
                }
            }
        }
    }

    // ---- mouth --------------------------------------------------------------
    Item {
        visible: beast.spec.teeth === true
        x: beast.width * 0.34
        y: beast.height * (beast.form === "skull" ? 0.66 : 0.7)
        width: beast.width * 0.32
        height: beast.height * 0.14

        Rectangle {
            anchors.fill: parent
            radius: 2
            color: beast.ink
        }
        Row {
            anchors.centerIn: parent
            spacing: parent.width * 0.08
            Repeater {
                model: 3
                Rectangle {
                    width: beast.width * 0.05
                    height: beast.height * 0.09
                    color: Theme.fgBright
                }
            }
        }
    }

    // ---- boss crown ---------------------------------------------------------
    Shape {
        visible: beast.spec.crown === true
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.brightYellow
            strokeColor: beast.ink
            strokeWidth: 1.5
            PathSvg {
                path: {
                    const w = beast.width;
                    const h = beast.height;
                    return "M " + (w * 0.28) + " " + (h * 0.24)
                         + " L " + (w * 0.34) + " " + (h * 0.04)
                         + " L " + (w * 0.44) + " " + (h * 0.18)
                         + " L " + (w * 0.5) + " " + (h * -0.02)
                         + " L " + (w * 0.56) + " " + (h * 0.18)
                         + " L " + (w * 0.66) + " " + (h * 0.04)
                         + " L " + (w * 0.72) + " " + (h * 0.24)
                         + " Z";
                }
            }
        }
    }
}
