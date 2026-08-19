import QtQuick

// Top chrome: identity on the left, wave control in the middle, run state right.
Item {
    id: hud

    property Sim sim: null
    property bool showClose: false
    property bool showWorkspaceHint: false
    property bool menuArmed: false

    signal closeRequested()
    signal menuRequested()

    // Arming lapses, so a stray click never leaves the button primed.
    Timer {
        id: disarm
        interval: 3000
        onTriggered: hud.menuArmed = false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bgPanel, 0.92)

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.alpha(Theme.fg, 0.10)
        }
    }

    // ---- identity ----------------------------------------------------------
    Row {
        id: leftGroup
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            radius: 8
            color: Theme.accent

            // A tiny top-down Quattro as the logo mark, cut out of the accent
            // tile — so it follows the same contrast rule as any filled control.
            Rectangle {
                anchors.centerIn: parent
                width: 18
                height: 11
                radius: 3
                color: Theme.accentInk
            }
            Rectangle {
                anchors.centerIn: parent
                width: 7
                height: 15
                radius: 2
                color: Theme.accentInk
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2

            Text {
                text: "OMATOWER"
                font.family: Theme.display
                font.pixelSize: Theme.fsTitle
                font.bold: true
                font.letterSpacing: 3
                color: Theme.fgBright
            }
            Text {
                text: "DEFENSE"
                font.family: Theme.mono
                font.pixelSize: Theme.fsCaption
                font.letterSpacing: 5.4
                color: Theme.alpha(Theme.fgDim, 0.9)
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 26
            color: Theme.alpha(Theme.fg, 0.12)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -1
            visible: hud.sim && hud.sim.started

            Text {
                text: Balance.circuit.name
                font.family: Theme.display
                font.pixelSize: Theme.fsBody
                font.bold: true
                font.letterSpacing: 2
                color: Theme.fgBright
            }
            Text {
                text: Balance.circuit.country
                font.family: Theme.mono
                font.pixelSize: Theme.fsCaption
                font.letterSpacing: 2
                color: Theme.alpha(Theme.fgDim, 0.8)
            }
        }
    }

    // ---- wave control ------------------------------------------------------
    Row {
        id: centerGroup
        anchors.centerIn: parent
        spacing: 14
        // Never let the wave controls slide under the run state. This group is
        // centred on the whole bar, not on the gap between the other two, so
        // the room it actually has is twice the *smaller* side clearance —
        // subtracting both widths overstates it whenever the two sides are
        // uneven, which they are as soon as the workspace hint appears.
        readonly property real roomEitherSide:
            2 * Math.min(hud.width / 2 - leftGroup.width - 20,
                         hud.width / 2 - rightGroup.width - 20)
        visible: roomEitherSide > width

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "WAVE " + (hud.sim ? hud.sim.wave : 0)
                font.family: Theme.mono
                font.pixelSize: Theme.fsBody
                font.bold: true
                font.letterSpacing: 2
                color: Theme.fgBright
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (!hud.sim)
                        return "";
                    if (hud.sim.phase === "planning" && !hud.sim.waves.armed)
                        return "PARK A CAR";
                    switch (hud.sim.phase) {
                    case "planning": return "PLANNING";
                    case "spawning": return "INCOMING";
                    case "clearing": return "MOPPING UP";
                    case "over":     return "OVER";
                    }
                    return "";
                }
                font.family: Theme.mono
                font.pixelSize: Theme.fsCaption
                font.letterSpacing: 2
                color: Theme.fgDim
            }
        }

        // Call-early button doubles as the planning countdown.
        Rectangle {
            id: callBtn
            anchors.verticalCenter: parent.verticalCenter
            width: 194
            height: 36
            radius: Theme.radius
            visible: hud.sim && hud.sim.phase === "planning"
            color: callArea.containsMouse ? Theme.mix(Theme.bgLift, Theme.green, 0.4)
                                          : Theme.alpha(Theme.bgLift, 0.85)
            border.width: 1
            border.color: Theme.alpha(Theme.green, callArea.containsMouse ? 0.95 : 0.5)

            Behavior on color { ColorAnimation { duration: 120 } }

            // Countdown drains left to right.
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * (hud.sim && hud.sim.waves.armed ? hud.sim.waves.planFraction : 0)
                radius: parent.radius
                color: Theme.alpha(Theme.green, 0.20)
            }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "▶  CALL WAVE " + (hud.sim ? hud.sim.wave + 1 : 1)
                    font.family: Theme.mono
                    font.pixelSize: Theme.fsSmall
                    font.bold: true
                    font.letterSpacing: 1
                    color: Theme.fgBright
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: hud.sim && hud.sim.waves.earlyBonus > 0
                    text: "+" + (hud.sim ? hud.sim.waves.earlyBonus : 0)
                    font.family: Theme.mono
                    font.pixelSize: Theme.fsCaption
                    font.bold: true
                    color: Theme.brightYellow
                }
            }

            MouseArea {
                id: callArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: hud.sim.callWave()
            }
        }

        // Wave progress while it is running.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 194
            height: 36
            radius: Theme.radius
            visible: hud.sim && (hud.sim.phase === "spawning" || hud.sim.phase === "clearing")
            color: Theme.alpha(Theme.bgLift, 0.7)
            border.width: 1
            border.color: Theme.alpha(Theme.fg, 0.12)

            Text {
                anchors.centerIn: parent
                text: hud.sim ? hud.sim.enemies.aliveCount() + " TAKES ON THE ROAD" : ""
                font.family: Theme.mono
                font.pixelSize: Theme.fsSmall
                font.letterSpacing: 1
                color: Theme.fgDim
            }
        }
    }

    // ---- run state ---------------------------------------------------------
    Row {
        id: rightGroup
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 18

        // Stunned cars, only while it is happening. A stun that lands on the far
        // side of a 1600-unit circuit is otherwise something the player finds
        // out about by losing lives, which is not feedback, it is a surprise.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: hud.sim && hud.sim.towers.stunnedCount > 0
            width: stunLabel.implicitWidth + 22
            height: 28
            radius: 7
            color: Theme.alpha(Theme.magenta, 0.28)
            border.width: 1
            border.color: Theme.alpha(Theme.brightMagenta, 0.85)

            SequentialAnimation on opacity {
                running: hud.sim && hud.sim.towers.stunnedCount > 0
                loops: Animation.Infinite
                NumberAnimation { from: 0.55; to: 1; duration: 480 }
                NumberAnimation { from: 1; to: 0.55; duration: 480 }
            }

            Text {
                id: stunLabel
                anchors.centerIn: parent
                text: "✖ " + (hud.sim ? hud.sim.towers.stunnedCount : 0) + " STUNNED"
                font.family: Theme.mono
                font.pixelSize: Theme.fsCaption
                font.bold: true
                font.letterSpacing: 1
                color: Theme.fgBright
            }
        }

        // lives
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "♥"
                font.family: Theme.mono
                font.pixelSize: Theme.fsTitle
                color: hud.sim && hud.sim.lives <= 5 ? Theme.red : Theme.brightRed
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: hud.sim ? hud.sim.lives : 0
                font.family: Theme.mono
                font.pixelSize: Theme.fsTitle
                font.bold: true
                color: Theme.fgBright
            }
        }

        // cash
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "⛁"
                font.family: Theme.mono
                font.pixelSize: Theme.fsTitle
                color: Theme.brightYellow
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: hud.sim ? hud.sim.cash : 0
                font.family: Theme.mono
                font.pixelSize: Theme.fsTitle
                font.bold: true
                color: Theme.fgBright
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 24
            color: Theme.alpha(Theme.fg, 0.12)
        }

        // speed
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            Repeater {
                model: [
                    { label: "❚❚", value: 0 },
                    { label: "1×", value: 1 },
                    { label: "2×", value: 2 },
                    { label: "3×", value: 3 }
                ]
                Rectangle {
                    required property var modelData
                    readonly property bool on: hud.sim && hud.sim.speed === modelData.value

                    width: 38
                    height: 28
                    radius: 7
                    color: on ? Theme.accent
                             : speedArea.containsMouse ? Theme.alpha(Theme.bgLift, 0.95)
                                                       : Theme.alpha(Theme.bgLift, 0.5)
                    border.width: 1
                    border.color: on ? Theme.accent : Theme.alpha(Theme.fg, 0.10)

                    Behavior on color { ColorAnimation { duration: 110 } }

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        font.family: Theme.mono
                        font.pixelSize: Theme.fsCaption
                        font.bold: true
                        color: parent.on ? Theme.accentInk : Theme.fgDim
                    }

                    MouseArea {
                        id: speedArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: hud.sim.setSpeed(parent.modelData.value)
                    }
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 24
            color: Theme.alpha(Theme.fg, 0.12)
            visible: hud.width > 1380
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: hud.sim && hud.sim.started && !hud.sim.over
            width: menuLabel.implicitWidth + 22
            height: 28
            radius: 7
            color: hud.menuArmed ? Theme.mix(Theme.bgLift, Theme.red, 0.5)
                 : menuArea.containsMouse ? Theme.alpha(Theme.bgLift, 0.95)
                                          : Theme.alpha(Theme.bgLift, 0.5)
            border.width: 1
            border.color: Theme.alpha(hud.menuArmed ? Theme.red : Theme.fg,
                                      hud.menuArmed ? 0.85 : 0.10)

            Behavior on color { ColorAnimation { duration: 110 } }

            Text {
                id: menuLabel
                anchors.centerIn: parent
                text: hud.menuArmed ? "END RUN?" : "MENU"
                font.family: Theme.mono
                font.pixelSize: Theme.fsCaption
                font.bold: true
                font.letterSpacing: 1
                color: hud.menuArmed ? Theme.fgBright : Theme.fgDim
            }

            MouseArea {
                id: menuArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (hud.menuArmed) {
                        hud.menuArmed = false;
                        disarm.stop();
                        hud.menuRequested();
                    } else {
                        hud.menuArmed = true;
                        disarm.restart();
                    }
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: hud.showClose
            width: 30
            height: 28
            radius: 7
            color: closeArea.containsMouse ? Theme.mix(Theme.bgLift, Theme.red, 0.45)
                                           : Theme.alpha(Theme.bgLift, 0.5)
            border.width: 1
            border.color: Theme.alpha(Theme.red, closeArea.containsMouse ? 0.8 : 0.15)

            Behavior on color { ColorAnimation { duration: 110 } }

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.family: Theme.mono
                font.pixelSize: 12
                font.bold: true
                color: Theme.fgDim
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: hud.closeRequested()
            }
        }

        // The workspace hint used to live here, but it is long enough to push
        // the wave controls off the bar entirely on a 1720px window — and the
        // CALL WAVE button is worth more than a line of onboarding. The hint is
        // on the circuit picker instead, where a new player actually reads it.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: hud.width > 1380
            text: Theme.themeName
            font.family: Theme.mono
            font.pixelSize: Theme.fsCaption
            font.letterSpacing: 1
            color: Theme.alpha(Theme.fgDim, 0.75)
        }
    }
}
