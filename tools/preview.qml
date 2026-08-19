import QtQuick
import Quickshell
import Quickshell.Io
import "game"

// Dev harness: renders the game offscreen-ish, drives a scripted scenario, and
// grabs its own scene to $SHOT so iteration never touches a real workspace.
ShellRoot {
    FloatingWindow {
        title: "omatower-preview"
        implicitWidth: 1720
        implicitHeight: 1000
        color: Theme.bg

        Item {
            id: scene
            width: 1720
            height: 1000

            // THEME points at a colors.toml to render under, so light-mode and
            // collapsed palettes can be eyeballed and not just graded.
            Component.onCompleted: {
                const t = Quickshell.env("THEME") || "";
                if (t !== "")
                    Theme.sourcePath = t;
            }

            Game {
                id: game
                anchors.fill: parent
                // Renders the chrome the plugin host gets: close buttons and
                // the workspace hint, which is what the shots need to check.
                showClose: true
                showWorkspaceHint: true
            }

            // Park a few cars and run a wave so the shot has something in it.
            Timer {
                running: true
                interval: 400
                onTriggered: {
                    const sim = game.sim;
                    const idx = parseInt(Quickshell.env("CIRCUIT") || "0");
                    Balance.selectCircuit(idx);
                    sim.newRun("classic");
                    sim.cash = 9000;

                    // SCENARIO=route leaves the run unarmed so the shot catches
                    // the demonstration lap the player sees before their first car.
                    const scenario = Quickshell.env("SCENARIO") || "";
                    if (scenario === "route")
                        return;

                    // Scatter one of each car somewhere legal.
                    const wanted = ["q80", "s1", "e2", "rs", "bh", "barge", "pace"];
                    // deterministic-ish spread so shots are comparable
                    let placed = 0;
                    for (let attempt = 0; attempt < 4000 && placed < wanted.length; attempt++) {
                        const x = 90 + Math.random() * (Balance.fieldW - 180);
                        const y = 90 + Math.random() * (Balance.fieldH - 180);
                        if (sim.towers.canPlace(x, y)) {
                            const t = sim.towers.place(wanted[placed], x, y);
                            if (t) {
                                // SCENARIO=rank spreads all four tiers and points
                                // the cars every which way, which is the only way
                                // to see whether the rank plate ever clips.
                                t.level = scenario === "rank" ? placed % 4 : Math.min(2, placed % 3);
                                if (t.view) {
                                    t.view.level = t.level;
                                    if (scenario === "rank") {
                                        t.heading = placed * 51;
                                        t.view.heading = t.heading;
                                    }
                                }
                                placed++;
                            }
                        }
                    }
                    sim.towers.recomputeSupport();
                    const placing = Quickshell.env("PLACING") || "";
                    if (placing !== "") {
                        sim.selected = null;
                        sim.beginPlacing(placing);
                        sim.ghostX = Balance.slots[6].x;
                        sim.ghostY = Balance.slots[6].y;
                        sim.ghostValid = true;
                    } else {
                        sim.selected = sim.towers.list[0];
                    }
                    sim.callWave();

                    if (scenario === "pause")
                        pauseLater.start();
                    // The worst case for the debrief layout: every take in the
                    // game met, every car used. Seeded rather than played,
                    // because reaching this state honestly takes minutes.
                    if (scenario === "debrief") {
                        for (let i = 0; i < Balance.enemies.length; i++) {
                            const e = Balance.enemies[i];
                            for (let k = 0; k < 3 + i * 7; k++)
                                sim.ledger.addKill(e.id);
                        }
                        for (let i = 0; i < Balance.towers.length; i++)
                            sim.ledger.addDamage(Balance.towers[i].id, 900 * Math.pow(3, i));
                        sim.endRun();
                        return;
                    }

                    if (scenario === "stun") {
                        sim.towers.stunArea(Balance.fieldW / 2, Balance.fieldH / 2, 4000, 60);
                        return;
                    }

                    if (scenario === "over") {
                        // Fast-forward so the debrief has a real run behind it.
                        sim.setSpeed(3);
                        endLater.start();
                    }
                }
            }

            // SWITCHES=a,b,c cycles real themes mid-run and grabs a frame shortly
            // after each, which is the only way to prove the whole palette
            // lands in one frame rather than in two.
            Timer {
                id: themeCycle
                property var names: (Quickshell.env("SWITCHES") || "").split(",").filter(n => n !== "")
                property int at: 0
                running: names.length > 0
                interval: 2500
                repeat: true
                onTriggered: {
                    if (at >= names.length) { running = false; return; }
                    switcher.command = ["omarchy", "theme", "set", names[at]];
                    switcher.running = true;
                    at += 1;
                    grabSoon.restart();
                }
            }

            Process { id: switcher }

            Timer {
                id: grabSoon
                interval: 400
                onTriggered: scene.grabToImage(
                    r => r.saveToFile(Quickshell.env("SHOT").replace(".png", "-" + themeCycle.at + ".png")),
                    Qt.size(scene.width, scene.height))
            }

            Timer {
                id: pauseLater
                interval: 2500
                onTriggered: game.sim.togglePause()
            }

            // Plays for a while so the debrief has real numbers in it, then
            // ends the run the way losing your last life would.
            Timer {
                id: endLater
                interval: parseInt(Quickshell.env("PLAYFOR") || "14000")
                onTriggered: game.sim.endRun()
            }

            Timer {
                running: true
                interval: parseInt(Quickshell.env("DELAY") || "5200")
                onTriggered: scene.grabToImage(r => r.saveToFile(Quickshell.env("SHOT")),
                                               Qt.size(scene.width, scene.height))
            }
        }
    }
}
