import QtQuick
import QtQuick.Shapes

// The rally stage. Fixed logical size, scaled to fit whatever window it lands
// in, so every balance number stays resolution independent.
Item {
    id: field

    property Sim sim: null
    property bool showGrid: true

    // Layers, handed to the managers so they can mount their own views.
    readonly property alias groundLayer: groundLayer
    readonly property alias towerLayer: towerLayer
    readonly property alias enemyLayer: enemyLayer
    readonly property alias shotLayer: shotLayer
    readonly property alias fxLayer: fxLayer

    signal fieldClicked(real x, real y, int button)
    signal fieldHovered(real x, real y)

    width: Balance.fieldW
    height: Balance.fieldH

    // ---- ground -----------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.mix(Theme.bgPanel, Theme.accent, 0.05) }
            GradientStop { position: 1.0; color: Theme.bg }
        }
    }

    // Faint surveyor's grid, like a stage map.
    Item {
        anchors.fill: parent
        visible: field.showGrid
        opacity: 0.5

        Repeater {
            model: Math.floor(Balance.fieldW / 80)
            Rectangle {
                x: (index + 1) * 80
                width: 1
                height: parent.height
                color: Theme.alpha(Theme.fg, 0.035)
            }
        }
        Repeater {
            model: Math.floor(Balance.fieldH / 80)
            Rectangle {
                y: (index + 1) * 80
                width: parent.width
                height: 1
                color: Theme.alpha(Theme.fg, 0.035)
            }
        }
    }

    // ---- the route ---------------------------------------------------------
    Shape {
        id: routeShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.samples: 4

        // Shoulder
        ShapePath {
            strokeColor: Theme.alpha(Theme.trackEdge, 0.65)
            strokeWidth: Balance.trackWidth + 18
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: Balance.track[0].x
            startY: Balance.track[0].y
            PathPolyline { path: Balance.track.slice(1) }
        }

        // Kerbing: a dashed outline reads as rally kerbs on every corner.
        ShapePath {
            strokeColor: Theme.alpha(Theme.red, 0.55)
            strokeWidth: Balance.trackWidth + 18
            strokeStyle: ShapePath.DashLine
            dashPattern: [1.1, 1.1]
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            startX: Balance.track[0].x
            startY: Balance.track[0].y
            PathPolyline { path: Balance.track.slice(1) }
        }

        // Asphalt
        ShapePath {
            strokeColor: Theme.track
            strokeWidth: Balance.trackWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: Balance.track[0].x
            startY: Balance.track[0].y
            PathPolyline { path: Balance.track.slice(1) }
        }

        // Centre line
        ShapePath {
            strokeColor: Theme.alpha(Theme.fg, 0.18)
            strokeWidth: 3
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 5]
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            startX: Balance.track[0].x
            startY: Balance.track[0].y
            PathPolyline { path: Balance.track.slice(1) }
        }
    }

    // ---- start / finish line -----------------------------------------------
    Item {
        readonly property var p0: Balance.pointAt(0)

        x: p0.x
        y: p0.y
        rotation: p0.angle
        z: 2

        // Checkered band laid across the road.
        Column {
            anchors.centerIn: parent
            spacing: 0

            Repeater {
                model: Math.round(Balance.trackWidth / 11)

                Row {
                    required property int index
                    readonly property int band: index
                    spacing: 0

                    Repeater {
                        model: 2
                        Rectangle {
                            required property int index
                            width: 11
                            height: 11
                            color: (index + parent.band) % 2 === 0
                                   ? Theme.alpha(Theme.fgBright, 0.92)
                                   : Theme.alpha(Theme.bg, 0.92)
                        }
                    }
                }
            }
        }

    }

    // ---- entity layers -----------------------------------------------------
    Item { id: groundLayer; anchors.fill: parent }
    Item { id: towerLayer;  anchors.fill: parent }
    Item { id: enemyLayer;  anchors.fill: parent }
    Item { id: shotLayer;   anchors.fill: parent }
    Item { id: fxLayer;     anchors.fill: parent }

    // ---- route demonstration ---------------------------------------------------
    PathPreview {
        sim: field.sim
    }

    // ---- parking bays ---------------------------------------------------------
    // Only shown while a car is selected for placement, so the map stays clean.
    Repeater {
        model: field.sim && field.sim.placingId !== "" ? Balance.slots : []

        Rectangle {
            required property var modelData

            readonly property bool taken: field.sim
                && field.sim.towers.slotRevision >= 0
                && field.sim.towers.isOccupied(modelData.id)
            readonly property bool targeted: field.sim
                && Math.abs(field.sim.ghostX - modelData.x) < 1
                && Math.abs(field.sim.ghostY - modelData.y) < 1

            x: modelData.x - 46
            y: modelData.y - 30
            width: 92
            height: 60
            radius: 10
            z: 3

            color: targeted ? Theme.alpha(Theme.accent, 0.22)
                 : taken ? "transparent"
                 : Theme.alpha(Theme.accent, 0.07)
            border.width: targeted ? 2 : 1
            border.color: taken ? Theme.alpha(Theme.fg, 0.10)
                        : targeted ? Theme.accent
                        : Theme.alpha(Theme.accent, 0.34)

            Behavior on color { ColorAnimation { duration: 90 } }
        }
    }

    // ---- placement ghost ---------------------------------------------------
    Quattro {
        id: ghost
        visible: field.sim && field.sim.placingId !== ""
        def: field.sim && field.sim.placingId !== "" ? Balance.tower(field.sim.placingId) : null
        ghost: true
        showRank: false
        valid: field.sim ? field.sim.ghostValid : false
        range: def ? def.levels[0].range : 0
        heading: -20
        x: (field.sim ? field.sim.ghostX : 0) - Balance.carW / 2
        y: (field.sim ? field.sim.ghostY : 0) - Balance.carH / 2
        z: 50
    }

    // ---- input -------------------------------------------------------------
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPositionChanged: mouse => field.fieldHovered(mouse.x, mouse.y)
        onClicked: mouse => field.fieldClicked(mouse.x, mouse.y, mouse.button)
    }
}
