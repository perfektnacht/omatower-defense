import QtQuick

// End of run. No score attached to a wallet, no continues for sale — just the
// number you reached, a debrief of what your cars actually did, and a button to
// go again.
//
// The debrief is the payoff for the artwork: every car and every take in the
// run gets drawn one more time at a size you can actually look at, next to the
// numbers that say what it was worth.
Item {
    id: over

    property Sim sim: null
    // Only offered where there is somewhere to exit to: the plugin overlay can
    // be dismissed, a standalone window has its own titlebar for that.
    property bool showClose: false

    signal closeRequested()

    // Plain JS maps cannot notify, so everything below hangs off the revision
    // Sim bumps when the run ends.
    readonly property int rev: sim && sim.ledger ? sim.ledger.revision : 0
    readonly property var damageRows: sim && sim.ledger && rev >= 0 ? sim.ledger.damageTable() : []
    readonly property var killRows: sim && sim.ledger && rev >= 0 ? sim.ledger.killTable() : []

    // Six figures of damage is normal by wave 20; the raw number stops being
    // readable long before that.
    function compact(n: real): string {
        if (n >= 1000000)
            return (n / 1000000).toFixed(n >= 10000000 ? 0 : 1) + "M";
        if (n >= 10000)
            return Math.round(n / 1000) + "k";
        if (n >= 1000)
            return (n / 1000).toFixed(1) + "k";
        return String(Math.round(n));
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, 0.93)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    Item {
        anchors.centerIn: parent
        width: sheet.width
        height: sheet.height
        // A long run fills the debrief with rows; shrink rather than spill off
        // the bottom of a short window.
        scale: Math.min(1, (over.height - 24) / Math.max(1, sheet.height),
                           (over.width - 24) / Math.max(1, sheet.width))

        Column {
            id: sheet
            spacing: 18
            width: 1000

            // ---- headline ------------------------------------------------
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "THE DISCOURSE WON"
                    font.family: Theme.display
                    font.pixelSize: Theme.fsDisplay
                    font.bold: true
                    font.letterSpacing: 3
                    color: Theme.red
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "your machine has been reformatted"
                    font.family: Theme.mono
                    font.pixelSize: Theme.fsBody
                    color: Theme.fgDim
                }
            }

            // ---- run totals ----------------------------------------------
            Rectangle {
                width: parent.width
                height: 56
                radius: Theme.radiusLarge
                color: Theme.alpha(Theme.bgPanel, 0.95)
                border.width: 1
                border.color: Theme.alpha(Theme.fg, 0.12)

                Row {
                    anchors.centerIn: parent
                    spacing: 0

                    Repeater {
                        model: over.sim ? [
                            { k: "WAVES SURVIVED", v: String(over.sim.wave) },
                            { k: "TAKES REFUTED", v: String(over.sim.kills) },
                            { k: "TAKES THAT LANDED", v: String(over.sim.leaks) },
                            { k: "TOTAL DAMAGE", v: over.compact(over.sim.ledger.totalDamage()) },
                            { k: "SCORE", v: String(over.sim.score) }
                        ] : []

                        Item {
                            required property var modelData
                            width: 200
                            height: 40

                            Column {
                                anchors.centerIn: parent
                                spacing: 0

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: parent.parent.modelData.v
                                    font.family: Theme.mono
                                    font.pixelSize: 19
                                    font.bold: true
                                    color: Theme.fgBright
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: parent.parent.modelData.k
                                    font.family: Theme.mono
                                    font.pixelSize: 9
                                    font.letterSpacing: 1.2
                                    color: Theme.fgDim
                                }
                            }
                        }
                    }
                }
            }

            // ---- debrief ---------------------------------------------------
            Row {
                spacing: 16

                readonly property real panelHeight:
                    Math.max(damageCol.implicitHeight, killBody.implicitHeight) + 60

                // ---- what your cars did ------------------------------------
                Rectangle {
                    width: 396
                    height: parent.panelHeight
                    radius: Theme.radiusLarge
                    color: Theme.alpha(Theme.bgPanel, 0.95)
                    border.width: 1
                    border.color: Theme.alpha(Theme.fg, 0.12)

                    Text {
                        x: 18
                        y: 16
                        text: "DAMAGE BY CAR"
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 2
                        color: Theme.alpha(Theme.fgDim, 0.9)
                    }

                    Column {
                        id: damageCol
                        x: 14
                        y: 42
                        width: parent.width - 28
                        spacing: 2

                        Repeater {
                            model: over.damageRows

                            Item {
                                required property var modelData
                                readonly property color hue: Theme[modelData.def.hue] || Theme.accent

                                width: damageCol.width
                                height: 46

                                // Share bar, drawn behind everything as a fill
                                // rather than a separate widget so a dominant
                                // car reads at a glance.
                                Rectangle {
                                    width: parent.width * Math.max(0.05, modelData.share)
                                    height: parent.height
                                    radius: 7
                                    color: Theme.alpha(parent.hue, 0.14)
                                }

                                Item {
                                    x: 4
                                    width: 74
                                    height: parent.height

                                    Quattro {
                                        anchors.centerIn: parent
                                        def: modelData.def
                                        level: 0
                                        heading: 0
                                        range: 0
                                        showRank: false
                                        scale: 0.62
                                    }
                                }

                                Column {
                                    x: 82
                                    width: parent.width - 82 - 78
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: modelData.def.name
                                        font.family: Theme.mono
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: Theme.fgBright
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: modelData.def.weaponName
                                        font.family: Theme.mono
                                        font.pixelSize: 9
                                        font.letterSpacing: 1.3
                                        color: parent.parent.hue
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.amount > 0 ? over.compact(modelData.amount) : "—"
                                    font.family: Theme.mono
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: modelData.amount > 0 ? Theme.fgBright
                                                                : Theme.alpha(Theme.fgDim, 0.7)
                                }
                            }
                        }

                        Text {
                            visible: over.damageRows.length === 0
                            width: damageCol.width
                            text: "No car ever fired. Bold strategy."
                            font.family: Theme.mono
                            font.pixelSize: 11
                            color: Theme.fgDim
                        }
                    }
                }

                // ---- what you shot down ------------------------------------
                Rectangle {
                    width: 588
                    height: parent.panelHeight
                    radius: Theme.radiusLarge
                    color: Theme.alpha(Theme.bgPanel, 0.95)
                    border.width: 1
                    border.color: Theme.alpha(Theme.fg, 0.12)

                    Text {
                        x: 18
                        y: 16
                        text: "TAKES REFUTED"
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 2
                        color: Theme.alpha(Theme.fgDim, 0.9)
                    }

                    Column {
                        id: killBody
                        x: 14
                        y: 42
                        width: parent.width - 28
                        spacing: 10

                        Grid {
                            id: killGrid
                            width: parent.width
                            // Two columns, not three: the labels are the joke, and
                            // three columns cut "shell-script-slop" in half.
                            columns: 2
                            spacing: 4

                            Repeater {
                                model: over.killRows

                                Item {
                                    required property var modelData
                                    readonly property color hue: Theme[modelData.def.hue] || Theme.fg
                                    readonly property bool boss: modelData.def.traits.indexOf("boss") >= 0

                                    width: (killGrid.width - 4) / 2
                                    height: 46

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 7
                                        color: Theme.alpha(parent.hue, parent.boss ? 0.16 : 0.07)
                                        border.width: parent.boss ? 1 : 0
                                        border.color: Theme.alpha(parent.hue, 0.5)
                                    }

                                    Item {
                                        x: 2
                                        width: 42
                                        height: parent.height

                                        Creature {
                                            anchors.centerIn: parent
                                            bodySize: 30
                                            spec: modelData.def.sprite
                                            hue: parent.parent.hue
                                        }
                                    }

                                    Column {
                                        x: 46
                                        width: parent.width - 46 - 46
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            width: parent.width
                                            text: modelData.def.label
                                            font.family: Theme.mono
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: Theme.fgBright
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width
                                            text: modelData.def.tagline
                                            font.family: Theme.mono
                                            font.pixelSize: 9
                                            color: Theme.alpha(Theme.fgDim, 0.85)
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "×" + modelData.count
                                        font.family: Theme.mono
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: parent.hue
                                    }
                                }
                            }
                        }

                        Text {
                            visible: over.killRows.length === 0
                            width: parent.width
                            text: "Not one take refuted. They walked it in."
                            font.family: Theme.mono
                            font.pixelSize: 11
                            color: Theme.fgDim
                        }

                        // A quiet completionist hook: there are seventeen takes in
                        // the game and a short run only ever meets a handful.
                        Text {
                            text: over.killRows.length + " of " + Balance.enemies.length
                                  + " takes met on this run"
                            font.family: Theme.mono
                            font.pixelSize: 9
                            font.letterSpacing: 1
                            color: Theme.alpha(Theme.fgDim, 0.6)
                        }
                    }
                }
            }

            // ---- again -----------------------------------------------------
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Repeater {
                    model: {
                        const rows = [
                            { label: "RUN IT BACK", mode: "same", accent: true },
                            { label: "CHANGE CIRCUIT", mode: "menu", accent: false }
                        ];
                        if (over.showClose)
                            rows.push({ label: "EXIT", mode: "exit", accent: false });
                        return rows;
                    }

                    Rectangle {
                        required property var modelData
                        width: modelData.mode === "exit" ? 130 : 205
                        height: 42
                        radius: Theme.radius
                        color: modelData.accent
                               ? (btnArea.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent)
                               : (btnArea.containsMouse ? Theme.alpha(Theme.bgLift, 0.95) : Theme.alpha(Theme.bgLift, 0.6))
                        border.width: 1
                        border.color: modelData.accent ? Theme.accent : Theme.alpha(Theme.fg, 0.16)

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            font.family: Theme.mono
                            font.pixelSize: 12
                            font.bold: true
                            font.letterSpacing: 1.5
                            color: parent.modelData.accent ? Theme.accentInk : Theme.fgBright
                        }

                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                switch (parent.modelData.mode) {
                                case "menu":
                                    over.sim.over = false;
                                    over.sim.started = false;
                                    break;
                                case "exit":
                                    // The run is already finished, so there is
                                    // nothing to preserve: drop it and close, so
                                    // reopening lands on the circuit picker.
                                    over.sim.abandonRun();
                                    over.closeRequested();
                                    break;
                                default:
                                    over.sim.newRun(over.sim.mode);
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Balance.circuit.name + "  ·  " + (over.sim && over.sim.mode === "draft" ? "DRAFT" : "CLASSIC")
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.alpha(Theme.fgDim, 0.75)
            }
        }
    }
}
