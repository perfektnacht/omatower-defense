import QtQuick

// Manual pause. A pause you can still play through is not a pause, so this
// covers the board, swallows every click meant for it, and says so plainly.
// The top HUD strip stays uncovered on purpose: the speed control that got you
// here has to be the thing that gets you out.
Item {
    id: veil

    property Sim sim: null

    readonly property bool showing: sim && sim.started && !sim.over && sim.paused

    visible: opacity > 0
    opacity: showing ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 140 } }

    // Nothing underneath is interactive while this is up: no placing, no
    // selecting, no accidental retiring of a car you were about to develop.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {}
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, 0.78)
    }

    Column {
        anchors.centerIn: parent
        spacing: 18

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "PAUSED"
            font.family: Theme.display
            font.pixelSize: 76
            font.bold: true
            font.letterSpacing: 16
            color: Theme.fgBright
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 260
            height: 2
            color: Theme.alpha(Theme.accent, 0.6)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "The board is frozen. Cars cannot be parked while paused."
            font.family: Theme.mono
            font.pixelSize: 12
            font.letterSpacing: 1
            color: Theme.fgDim
        }

        Rectangle {
            id: resumeBtn
            anchors.horizontalCenter: parent.horizontalCenter
            width: 220
            height: 46
            radius: Theme.radius
            color: resumeArea.containsMouse ? Theme.mix(Theme.bgLift, Theme.green, 0.45)
                                            : Theme.alpha(Theme.bgLift, 0.9)
            border.width: 2
            border.color: Theme.alpha(Theme.green, resumeArea.containsMouse ? 0.95 : 0.55)

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "▶  RESUME AT 1×"
                font.family: Theme.mono
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 2
                color: Theme.fgBright
            }

            MouseArea {
                id: resumeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: veil.sim.resume()
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Space  or  P  ·  resume"
            font.family: Theme.mono
            font.pixelSize: 10
            font.letterSpacing: 2
            color: Theme.alpha(Theme.fgDim, 0.75)
        }
    }
}
