import QtQuick
import QtQuick.Shapes

// Pick a circuit and a run mode. No unlocks, no currency, no gates — every
// stage is available from the first launch.
Item {
    id: start

    property Sim sim: null
    property int picked: 0
    property string mode: "classic"
    property bool showClose: false
    property bool showWorkspaceHint: false

    signal closeRequested()

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    // Escape works too, but a visible control means quitting never depends on
    // where keyboard focus happens to be.
    Rectangle {
        visible: start.showClose
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        width: quitLabel.implicitWidth + 26
        height: 32
        radius: Theme.radius
        color: quitArea.containsMouse ? Theme.mix(Theme.bgLift, Theme.red, 0.45)
                                      : Theme.alpha(Theme.bgLift, 0.5)
        border.width: 1
        border.color: Theme.alpha(Theme.red, quitArea.containsMouse ? 0.8 : 0.15)
        z: 10

        Behavior on color { ColorAnimation { duration: 110 } }

        Text {
            id: quitLabel
            anchors.centerIn: parent
            text: "✕  QUIT"
            font.family: Theme.mono
            font.pixelSize: Theme.fsCaption
            font.bold: true
            font.letterSpacing: 1
            color: Theme.fgDim
        }

        MouseArea {
            id: quitArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: start.closeRequested()
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 26
        width: Math.min(parent.width - 80, 1380)

        // ---- title -----------------------------------------------------------
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "OMATOWER DEFENSE"
                font.family: Theme.display
                font.pixelSize: Theme.fsDisplay
                font.bold: true
                font.letterSpacing: 7
                color: Theme.fgBright
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "park Quattros · shoot down the takes · defend your machine"
                font.family: Theme.mono
                font.pixelSize: Theme.fsBody
                font.letterSpacing: 1
                color: Theme.fgDim
            }
        }

        // ---- circuits --------------------------------------------------------
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Repeater {
                model: Balance.circuits

                Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool on: start.picked === index

                    width: 254
                    // Driven by the content rather than a guessed constant: the
                    // blurb reserves a whole number of real text lines, which is
                    // the same for every card, so the row stays level whatever
                    // font the current theme hands us.
                    height: cardBody.implicitHeight + 30
                    radius: Theme.radiusLarge
                    color: on ? Theme.mix(Theme.bgPanel, Theme.accent, 0.16)
                              : cardArea.containsMouse ? Theme.alpha(Theme.bgRaised, 0.95)
                                                       : Theme.alpha(Theme.bgPanel, 0.8)
                    border.width: on ? 2 : 1
                    border.color: on ? Theme.accent : Theme.alpha(Theme.fg, 0.12)

                    Behavior on color { ColorAnimation { duration: 130 } }

                    Column {
                        id: cardBody
                        x: 16
                        y: 15
                        width: parent.width - 32
                        spacing: 8

                        Text {
                            width: parent.width
                            text: card.modelData.name
                            font.family: Theme.display
                            font.pixelSize: 17
                            font.bold: true
                            font.letterSpacing: 1.5
                            color: Theme.fgBright
                            elide: Text.ElideRight
                        }
                        Text {
                            text: card.modelData.country
                            font.family: Theme.mono
                            font.pixelSize: 10
                            font.letterSpacing: 2
                            color: Theme.alpha(Theme.fgDim, 0.85)
                        }

                        // little circuit map
                        Item {
                            width: parent.width
                            height: 112

                            Shape {
                                anchors.fill: parent
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    id: miniPath
                                    strokeColor: card.on ? Theme.accent : Theme.alpha(Theme.fg, 0.34)
                                    strokeWidth: 6
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin

                                    readonly property var pts:
                                        Balance.previewTrack(card.index, card.width - 32, 112, 8)

                                    startX: pts.length ? pts[0].x : 0
                                    startY: pts.length ? pts[0].y : 0
                                    PathPolyline { path: miniPath.pts.slice(1) }
                                }
                            }
                        }

                        Row {
                            spacing: 6

                            Rectangle {
                                width: diff.implicitWidth + 14
                                height: 18
                                radius: 4
                                readonly property color hue:
                                    card.modelData.difficulty === "ROOKIE" ? Theme.green
                                  : card.modelData.difficulty === "PRO" ? Theme.brightYellow
                                  : Theme.red
                                color: Theme.alpha(hue, 0.2)
                                Text {
                                    id: diff
                                    anchors.centerIn: parent
                                    text: card.modelData.difficulty
                                    font.family: Theme.mono
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1
                                    color: parent.hue
                                }
                            }
                        }

                        // Reserves four rendered lines rather than a pixel
                        // count, because the height of a line depends on the
                        // theme's monospace font. The old fixed 54px only fitted
                        // two of them and quietly ate the end of every blurb.
                        Text {
                            id: lineProbe
                            visible: false
                            text: "X"
                            font.family: Theme.mono
                            font.pixelSize: 10
                            lineHeight: 1.3
                        }

                        Text {
                            width: parent.width
                            height: lineProbe.implicitHeight * 4
                            text: card.modelData.blurb
                            font.family: Theme.mono
                            font.pixelSize: 10
                            lineHeight: 1.3
                            color: Theme.alpha(Theme.fgDim, 0.9)
                            wrapMode: Text.WordWrap
                        }
                    }

                    MouseArea {
                        id: cardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: start.picked = card.index
                    }
                }
            }
        }

        // ---- mode + start ----------------------------------------------------
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Repeater {
                    model: [
                        { id: "classic", label: "CLASSIC", note: "every car available" },
                        { id: "draft", label: "DRAFT", note: "a random five-car hand" }
                    ]

                    Rectangle {
                        required property var modelData
                        readonly property bool on: start.mode === modelData.id

                        width: 258
                        height: 46
                        radius: Theme.radius
                        color: on ? Theme.mix(Theme.bgLift, Theme.accent, 0.3)
                                  : modeArea.containsMouse ? Theme.alpha(Theme.bgLift, 0.9)
                                                           : Theme.alpha(Theme.bgLift, 0.45)
                        border.width: 1
                        border.color: on ? Theme.accent : Theme.alpha(Theme.fg, 0.12)

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 0
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.modelData.label
                                font.family: Theme.mono
                                font.pixelSize: 12
                                font.bold: true
                                font.letterSpacing: 2
                                color: Theme.fgBright
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.modelData.note
                                font.family: Theme.mono
                                font.pixelSize: 10
                                // The selected chip is filled with the accent,
                                // which swallowed the dim subtitle entirely.
                                color: parent.parent.on ? Theme.fgBright : Theme.fgDim
                            }
                        }

                        MouseArea {
                            id: modeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: start.mode = parent.modelData.id
                        }
                    }
                }
            }

            Rectangle {
                id: startButton
                anchors.horizontalCenter: parent.horizontalCenter
                width: 528
                height: 60
                radius: Theme.radius
                color: goArea.containsMouse ? Qt.lighter(Theme.accent, 1.18) : Theme.accent
                scale: goArea.pressed ? 0.985 : 1

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 80 } }

                Text {
                    anchors.centerIn: parent
                    text: "START  ▶"
                    font.family: Theme.mono
                    font.pixelSize: 17
                    font.bold: true
                    font.letterSpacing: 4
                    color: Theme.accentInk
                }

                MouseArea {
                    id: goArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: start.beginRun()
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (start.showWorkspaceHint
                       ? "Enter to start  ·  Esc to quit  ·  switch workspace to hide  ·  build "
                       : "Enter to start  ·  Esc to quit  ·  build ") + Build.stamp
                // Contains file-derived text. Never AutoText.
                textFormat: Text.PlainText
                font.family: Theme.mono
                font.pixelSize: 10
                font.letterSpacing: 1
                color: Theme.alpha(Theme.fgDim, 0.7)
            }
        }
    }

    // Called by the button and by Enter, so there is one code path in.
    function beginRun(): void {
        if (!start.sim)
            return;
        Balance.selectCircuit(start.picked);
        start.sim.newRun(start.mode);
    }
}
