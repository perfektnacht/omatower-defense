import QtQuick

// Detail panel for the selected car: what it does, how to develop it, and the
// targeting priority that separates a working defence from a wasted one.
Item {
    id: inspector

    property Sim sim: null
    readonly property var t: sim ? sim.selected : null
    readonly property int rev: sim ? sim.selRev : 0

    // A selected tower is a plain JS object, so mutating it (upgrading, changing
    // targeting) cannot notify QML. Sim bumps `selRev` on every such change, and
    // EVERY binding that depends on mutable tower state has to route through it.
    // Reading `t.level` directly anywhere below would silently freeze that
    // binding at the value it had when the car was selected.
    readonly property var def: t ? t.def : null
    readonly property int level: t && rev >= 0 ? t.level : 0
    readonly property var stats: t && rev >= 0 ? t.def.levels[t.level] : null
    readonly property string targetMode: t && rev >= 0 ? t.targetMode : "first"
    readonly property int upCost: t && rev >= 0 ? sim.towers.upgradeCost(t) : -1
    readonly property bool locked: t && rev >= 0 ? sim.towers.upgradeLocked(t) : false
    readonly property bool maxed: upCost < 0 && !locked
    readonly property int refund: t && rev >= 0 ? Balance.sellValue(t.defId, t.level) : 0
    readonly property string rankName: ["I", "II", "III", "IV"][Math.max(0, Math.min(3, level))]
    readonly property string nextNote: {
        if (!t || rev < 0 || t.level >= Balance.maxLevel())
            return "";
        if (locked)
            return "Tier IV unlocks after wave " + Balance.prestigeWave + ".";
        return t.def.levels[t.level + 1].note || "";
    }
    readonly property color hue: def ? (Theme[def.hue] || Theme.accent) : Theme.accent

    visible: t !== null
    width: 296
    height: card.height

    Rectangle {
        id: card
        width: parent.width
        height: body.implicitHeight + 26
        radius: Theme.radiusLarge
        color: Theme.alpha(Theme.bgPanel, 0.96)
        border.width: 1
        border.color: Theme.alpha(inspector.hue, 0.4)

        Column {
            id: body
            x: 16
            y: 14
            width: parent.width - 32
            spacing: 11

            // ---- header --------------------------------------------------
            Row {
                width: parent.width
                spacing: 8

                Column {
                    width: parent.width - 68
                    spacing: 1
                    Text {
                        width: parent.width
                        text: inspector.def ? inspector.def.name : ""
                        font.family: Theme.mono
                        font.pixelSize: 14
                        font.bold: true
                        color: Theme.fgBright
                        elide: Text.ElideRight
                    }
                    Text {
                        text: inspector.def ? inspector.def.weaponName : ""
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                        color: inspector.hue
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "TIER " + inspector.rankName
                        font.family: Theme.mono
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1
                        color: inspector.level >= Balance.maxLevel()
                               ? Theme.brightMagenta : Theme.brightYellow
                    }

                    // Same three bars as the plate on the car itself, so the
                    // panel and the board speak one language: filled is a
                    // development bought, outlined is one still on offer.
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3
                        Repeater {
                            model: Balance.maxLevel()
                            Rectangle {
                                required property int index
                                readonly property int step: index + 1
                                readonly property bool filled: inspector.t && inspector.level >= step
                                // The last bar is dashed off entirely until the
                                // tier is reachable, so the panel never promises
                                // something the run cannot buy yet.
                                readonly property bool sealed: step > Balance.maxLevelAt(inspector.sim ? inspector.sim.wave : 0)

                                width: 14
                                height: 7
                                radius: 2
                                color: filled ? (inspector.level >= Balance.maxLevel()
                                                 ? Theme.brightMagenta : Theme.brightYellow)
                                              : "transparent"
                                border.width: filled ? 0 : 1
                                border.color: Theme.alpha(Theme.fg, sealed ? 0.16 : 0.38)
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.fg, 0.10) }

            // ---- stats ---------------------------------------------------
            Column {
                width: parent.width
                spacing: 5

                Repeater {
                    model: {
                        if (!inspector.t || !inspector.stats)
                            return [];
                        const s = inspector.stats;
                        const t = inspector.t;
                        const rows = [];

                        if (inspector.def.role === "damage") {
                            const range = sim.towers.effRange(t);
                            const rate = sim.towers.effRate(t);
                            rows.push({ k: "DAMAGE", v: String(s.dmg) });
                            rows.push({ k: "FIRE RATE", v: rate.toFixed(2) + "/s",
                                        buffed: t.buffRate > 0 });
                            rows.push({ k: "RANGE", v: String(Math.round(range)),
                                        buffed: t.buffRange > 0 });
                            rows.push({ k: "DPS", v: String(Math.round(s.dmg * rate)) });
                            rows.push({ k: "TYPE", v: Balance.damageTypes[inspector.def.dmgType].label });
                            if (s.splash > 0)
                                rows.push({ k: "SPLASH", v: String(s.splash) });
                            if (s.slow > 0)
                                rows.push({ k: "SLOW", v: Math.round(s.slow * 100) + "%" });
                            if (inspector.def.weapon === "laseretch" && s.maxTargets > 1) {
                                // A pierce count on its own overstates the beam,
                                // so the panel shows the attenuation next to it
                                // and what the whole queue actually takes.
                                let line = 0;
                                for (let i = 0; i < s.maxTargets; i++)
                                    line += Balance.beamShare(i);
                                rows.push({ k: "PIERCES", v: s.maxTargets
                                            + "  −" + Math.round(Balance.beamFalloff * 100) + "% each" });
                                rows.push({ k: "LINE DPS", v: String(Math.round(s.dmg * rate * line)) });
                            } else if (s.maxTargets > 1 && s.maxTargets < 90) {
                                rows.push({ k: "TARGETS", v: String(s.maxTargets) });
                            }
                            rows.push({ k: "STEALTH", v: sim.towers.canDetect(t) ? "DETECTED" : "BLIND",
                                        warn: !sim.towers.canDetect(t) });
                        } else if (inspector.def.role === "economy") {
                            // Payouts decay with the wave number, so quoting the
                            // raw table value here would overstate what the next
                            // wave actually pays.
                            const paid = Math.round(s.income * Balance.incomeScale(Math.max(1, sim.wave)));
                            rows.push({ k: "INCOME", v: "+" + paid + " / wave" });
                            rows.push({ k: "BASE", v: "+" + s.income });
                            rows.push({ k: "PAYBACK", v: Math.ceil(Balance.investedIn(t.defId, inspector.level) / Math.max(1, paid)) + " waves" });
                        } else {
                            rows.push({ k: "RANGE", v: String(s.range) });
                            rows.push({ k: "FIRE RATE", v: "+" + Math.round(s.buffRate * 100) + "%" });
                            rows.push({ k: "RANGE BUFF", v: "+" + Math.round(s.buffRange * 100) + "%" });
                            rows.push({ k: "CLEANSE", v: s.cleanse ? "YES" : "NO" });
                            if (s.grantDetect)
                                rows.push({ k: "SHARES", v: "DETECTION" });
                        }
                        return rows;
                    }

                    Item {
                        required property var modelData
                        width: body.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.k
                            font.family: Theme.mono
                            font.pixelSize: 10
                            font.letterSpacing: 1
                            color: Theme.alpha(Theme.fgDim, 0.85)
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.v
                            font.family: Theme.mono
                            font.pixelSize: 11
                            font.bold: true
                            color: modelData.warn ? Theme.red
                                 : modelData.buffed ? Theme.brightCyan
                                 : Theme.fgBright
                        }
                    }
                }
            }

            // ---- targeting -------------------------------------------------
            Column {
                width: parent.width
                spacing: 5
                visible: inspector.def && inspector.def.role === "damage"

                Text {
                    text: "TARGETING"
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                    color: Theme.alpha(Theme.fgDim, 0.85)
                }

                Row {
                    spacing: 4
                    Repeater {
                        model: Balance.targetModes
                        Rectangle {
                            required property var modelData
                            readonly property bool on: inspector.t
                                                       && inspector.targetMode === modelData.id
                            width: 62
                            height: 24
                            radius: 6
                            color: on ? inspector.hue
                                      : modeArea.containsMouse ? Theme.alpha(Theme.bgLift, 0.95)
                                                               : Theme.alpha(Theme.bgLift, 0.5)
                            border.width: 1
                            border.color: on ? inspector.hue : Theme.alpha(Theme.fg, 0.10)

                            Behavior on color { ColorAnimation { duration: 110 } }

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                font.family: Theme.mono
                                font.pixelSize: 9
                                font.bold: true
                                color: parent.on ? Theme.on(inspector.hue) : Theme.fgDim
                            }

                            MouseArea {
                                id: modeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    inspector.t.targetMode = parent.modelData.id;
                                    inspector.sim.selRev += 1;
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.fg, 0.10) }

            // ---- actions ---------------------------------------------------
            Column {
                width: parent.width
                spacing: 6

                Rectangle {
                    readonly property int cost: inspector.upCost
                    readonly property bool locked: inspector.locked
                    readonly property bool maxed: inspector.maxed || locked
                    readonly property bool affordable: !maxed && inspector.sim.cash >= cost

                    width: parent.width
                    height: 34
                    radius: Theme.radius
                    color: maxed ? Theme.alpha(Theme.bgLift, 0.4)
                                 : upArea.containsMouse && affordable ? Theme.mix(Theme.bgLift, Theme.brightYellow, 0.35)
                                                                      : Theme.alpha(Theme.bgLift, 0.8)
                    border.width: 1
                    border.color: maxed ? Theme.alpha(Theme.fg, 0.10)
                                        : Theme.alpha(Theme.brightYellow, affordable ? 0.7 : 0.2)
                    opacity: maxed || affordable ? 1 : 0.5

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.locked ? "TIER IV LOCKED"
                            : parent.maxed ? "FULLY DEVELOPED" : "DEVELOP  ▲"
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1
                        color: parent.maxed ? Theme.fgDim : Theme.fgBright
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !parent.maxed
                        text: "⛁ " + parent.cost
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.bold: true
                        color: parent.affordable ? Theme.brightYellow : Theme.red
                    }

                    MouseArea {
                        id: upArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !parent.maxed
                        cursorShape: Qt.PointingHandCursor
                        onClicked: inspector.sim.tryUpgradeSelected()
                    }
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: inspector.nextNote
                    font.family: Theme.mono
                    font.pixelSize: 10
                    lineHeight: 1.25
                    color: Theme.alpha(Theme.fgDim, 0.9)
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: Theme.radius
                    color: sellArea.containsMouse ? Theme.mix(Theme.bgLift, Theme.red, 0.3)
                                                  : Theme.alpha(Theme.bgLift, 0.55)
                    border.width: 1
                    border.color: Theme.alpha(Theme.red, sellArea.containsMouse ? 0.7 : 0.22)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "RETIRE"
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1
                        color: Theme.fgDim
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+⛁ " + inspector.refund
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.fgDim
                    }

                    MouseArea {
                        id: sellArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: inspector.sim.trySellSelected()
                    }
                }
            }
        }
    }
}
