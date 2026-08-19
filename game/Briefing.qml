import QtQuick

// Fills the side column between waves: what is coming, and what it shrugs off.
// This is the "time to plan" the whole genre runs on.
Item {
    id: brief

    property Sim sim: null

    // Set when the inspector is sharing the column. The wave list keeps every
    // row — knowing what is coming is the point — but drops the per-take notes,
    // which is what makes it fit next to a car panel without shrinking type.
    property bool compact: false

    width: 296
    height: card.height

    Rectangle {
        id: card
        width: parent.width
        height: col.implicitHeight + 26
        radius: Theme.radiusLarge
        color: Theme.alpha(Theme.bgPanel, 0.94)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.12)

        Column {
            id: col
            x: 16
            y: 14
            width: parent.width - 32
            spacing: brief.compact ? 7 : 10

            Row {
                width: parent.width
                Column {
                    width: parent.width - 60
                    spacing: 1
                    Text {
                        text: "NEXT WAVE"
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.letterSpacing: 2
                        color: Theme.alpha(Theme.fgDim, 0.85)
                    }
                    Text {
                        text: "WAVE " + (brief.sim ? brief.sim.wave + 1 : 1)
                        font.family: Theme.mono
                        font.pixelSize: 16
                        font.bold: true
                        color: Theme.fgBright
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: brief.sim && Balance.isBossWave(brief.sim.wave + 1)
                    width: 54
                    height: 20
                    radius: 5
                    color: Theme.alpha(Theme.brightMagenta, 0.22)
                    Text {
                        anchors.centerIn: parent
                        text: "BOSS"
                        font.family: Theme.mono
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1
                        color: Theme.brightMagenta
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.fg, 0.10) }

            Column {
                width: parent.width
                spacing: brief.compact ? 3 : 8

                Repeater {
                    model: brief.sim ? brief.sim.waves.nextWavePreview : []

                    Column {
                        required property var modelData
                        readonly property var d: modelData.def
                        readonly property color hue: d ? (Theme[d.hue] || Theme.fg) : Theme.fg

                        width: col.width
                        spacing: 2
                        visible: d !== null

                        Row {
                            width: parent.width
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: parent.parent.hue
                            }
                            Text {
                                width: parent.width - 58
                                text: parent.parent.d ? parent.parent.d.label : ""
                                font.family: Theme.mono
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.fgBright
                                elide: Text.ElideRight
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "×" + modelData.count
                                font.family: Theme.mono
                                font.pixelSize: 11
                                color: Theme.fgDim
                            }
                        }

                        Text {
                            x: 13
                            width: parent.width - 13
                            visible: !brief.compact
                            text: parent.d ? (parent.d.note || parent.d.tagline) : ""
                            font.family: Theme.mono
                            font.pixelSize: 10
                            lineHeight: 1.25
                            color: Theme.alpha(Theme.fgDim, 0.85)
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // Onboarding, not reference: it goes away once the player has
            // actually parked something and stops needing to be told how.
            Rectangle {
                width: parent.width
                height: 1
                visible: help.visible
                color: Theme.alpha(Theme.fg, 0.10)
            }

            Text {
                id: help
                width: parent.width
                visible: !brief.compact && brief.sim && !brief.sim.waves.armed
                text: "Pick a car below, then click a parking bay beside the circuit. Right-click cancels. Space calls the next wave early for a cash bonus."
                font.family: Theme.mono
                font.pixelSize: 10
                lineHeight: 1.3
                color: Theme.alpha(Theme.fgDim, 0.7)
                wrapMode: Text.WordWrap
            }
        }
    }
}
