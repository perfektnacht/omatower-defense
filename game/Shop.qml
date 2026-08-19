import QtQuick

// Bottom chrome: the cars you can park, each with a live preview of itself.
Item {
    id: shop

    property Sim sim: null

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bgPanel, 0.92)

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Theme.alpha(Theme.fg, 0.10)
        }
    }

    Item {
        anchors.centerIn: parent
        width: parent.width - 28
        height: parent.height
        // Dimmed while paused so the rule ("no parking while stopped") is
        // visible in the chrome rather than only in a rejection message.
        opacity: shop.sim && shop.sim.paused ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Row {
            id: cardRow
            anchors.centerIn: parent
            spacing: 10
            // Seven cards do not fit a narrow window; shrink rather than clip.
            scale: Math.min(1, (parent.width) / Math.max(1, implicitWidth))

            Repeater {
            model: shop.sim ? shop.sim.availableTowers : []

            Rectangle {
                id: card

                required property string modelData
                required property int index

                readonly property var def: Balance.tower(modelData)
                readonly property var lvl: def.levels[0]
                readonly property color hue: Theme[def.hue] || Theme.accent
                readonly property bool affordable: shop.sim && shop.sim.cash >= def.cost
                readonly property bool picked: shop.sim && shop.sim.placingId === def.id
                readonly property int limit: Balance.limitFor(def.id)
                // slotRevision is the notifier: the tower list itself is plain JS.
                readonly property int owned: shop.sim && shop.sim.towers.slotRevision >= 0
                                             ? shop.sim.towers.countOf(def.id) : 0
                readonly property bool full: limit >= 0 && owned >= limit

                width: 222
                height: 98
                radius: Theme.radius
                color: picked ? Theme.mix(Theme.bgLift, hue, 0.28)
                              : cardArea.containsMouse ? Theme.alpha(Theme.bgLift, 0.9)
                                                       : Theme.alpha(Theme.bgRaised, 0.75)
                border.width: picked ? 2 : 1
                border.color: picked ? hue : Theme.alpha(Theme.fg, 0.10)
                opacity: full ? 0.32 : affordable ? 1 : 0.45

                Behavior on color { ColorAnimation { duration: 130 } }
                Behavior on opacity { NumberAnimation { duration: 130 } }

                // hotkey
                Rectangle {
                    x: 9
                    y: 9
                    width: 17
                    height: 17
                    radius: 5
                    color: Theme.alpha(Theme.fg, 0.12)
                    Text {
                        anchors.centerIn: parent
                        text: card.index + 1
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.bold: true
                        color: Theme.fgDim
                    }
                }

                // per-run limit
                Rectangle {
                    x: 32
                    y: 9
                    visible: card.limit >= 0
                    width: limitLabel.implicitWidth + 12
                    height: 17
                    radius: 5
                    color: Theme.alpha(card.full ? Theme.red : Theme.fg, 0.12)
                    Text {
                        id: limitLabel
                        anchors.centerIn: parent
                        text: card.owned + "/" + card.limit
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.bold: true
                        color: card.full ? Theme.red : Theme.fgDim
                    }
                }

                // cost
                Row {
                    x: parent.width - width - 11
                    y: 10
                    spacing: 3
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⛁"
                        font.family: Theme.mono
                        font.pixelSize: 11
                        color: card.affordable ? Theme.brightYellow : Theme.red
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.def.cost
                        font.family: Theme.mono
                        font.pixelSize: 13
                        font.bold: true
                        color: card.affordable ? Theme.fgBright : Theme.red
                    }
                }

                // live car preview
                Item {
                    x: 6
                    y: 30
                    width: 74
                    height: 56
                    clip: false

                    Quattro {
                        anchors.centerIn: parent
                        def: card.def
                        level: 0
                        heading: -18
                        range: 0
                        scale: 0.62
                        showRank: false
                    }
                }

                Column {
                    x: 84
                    y: 32
                    width: parent.width - 92
                    spacing: 3

                    Text {
                        width: parent.width
                        text: card.def.name
                        font.family: Theme.mono
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.fgBright
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: card.def.weaponName
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1.4
                        color: card.hue
                        elide: Text.ElideRight
                    }

                    Row {
                        spacing: 4

                        Rectangle {
                            visible: card.def.role === "damage"
                            width: typeLabel.implicitWidth + 12
                            height: 16
                            radius: 4
                            color: Theme.alpha(Theme[Balance.damageTypes[card.def.dmgType] ?
                                                     Balance.damageTypes[card.def.dmgType].hue : "accent"], 0.22)
                            Text {
                                id: typeLabel
                                anchors.centerIn: parent
                                text: card.def.role === "damage"
                                      ? Balance.damageTypes[card.def.dmgType].label : ""
                                font.family: Theme.mono
                                font.pixelSize: 9
                                font.bold: true
                                color: Theme[Balance.damageTypes[card.def.dmgType] ?
                                             Balance.damageTypes[card.def.dmgType].hue : "accent"]
                            }
                        }

                        Rectangle {
                            visible: card.def.role !== "damage"
                            width: roleLabel.implicitWidth + 12
                            height: 16
                            radius: 4
                            color: Theme.alpha(card.hue, 0.22)
                            Text {
                                id: roleLabel
                                anchors.centerIn: parent
                                text: card.def.role === "economy" ? "ECONOMY" : "SUPPORT"
                                font.family: Theme.mono
                                font.pixelSize: 9
                                font.bold: true
                                color: card.hue
                            }
                        }

                        Rectangle {
                            visible: card.lvl.detect
                            width: 16
                            height: 16
                            radius: 4
                            color: Theme.alpha(Theme.brightCyan, 0.22)
                            Text {
                                anchors.centerIn: parent
                                text: "◈"
                                font.family: Theme.mono
                                font.pixelSize: 10
                                color: Theme.brightCyan
                            }
                        }
                    }
                }

                MouseArea {
                    id: cardArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !card.full
                    onClicked: shop.sim.beginPlacing(card.def.id)
                }

                ToolTipCard {
                    visible: cardArea.containsMouse
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    heading: card.def.name
                    body: card.full
                          ? card.def.blurb + "  (limit " + card.limit + " per run — reached)"
                          : card.def.blurb
                }
            }
        }
        }
    }
}
