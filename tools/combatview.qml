import QtQuick
import Quickshell
import "game"

// End-to-end against the real Game: real views, real projectiles, the real
// inspector panel. Checks what is actually on screen, not what the model says.
ShellRoot {
    FloatingWindow {
        implicitWidth: 1600; implicitHeight: 900; color: Theme.bg
        Game { id: game; anchors.fill: parent }
    }

    property int fails: 0
    property var insp: null

    function check(name, cond, detail) {
        console.log((cond ? "  PASS  " : "  FAIL  ") + name + (detail ? "   [" + detail + "]" : ""));
        if (!cond) fails += 1;
        return cond;
    }

    // Locate the live Inspector without adding test-only API to Game.
    function findByProp(item, prop) {
        for (const c of item.children) {
            if (c[prop] !== undefined && c[prop] !== null)
                return c;
            const r = findByProp(c, prop);
            if (r)
                return r;
        }
        return null;
    }

    Timer {
        running: true; interval: 600
        onTriggered: {
            const sim = game.sim;
            Balance.selectCircuit(0);
            sim.newRun("classic");
            sim.cash = 99999;

            // A couple of guns, then feed them something tanky that survives.
            let placed = 0;
            for (const s of Balance.slots) {
                if (placed >= 3) break;
                if (sim.towers.place("q80", s.x, s.y)) placed++;
            }
            for (let i = 0; i < 6; i++)
                sim.enemies.spawn("bloated", { dist: 200 + i * 120 });
            console.log("parked " + placed + " cars, spawned 6 bloated");
        }
    }

    Timer {
        running: true; interval: 6500
        onTriggered: {
            const sim = game.sim;
            let damaged = 0, mismatched = 0, sample = "";

            for (const e of sim.enemies.list) {
                if (!e.view)
                    continue;
                const truth = Math.max(0, e.hp / e.hpMax);
                if (truth < 0.999) {
                    damaged++;
                    if (Math.abs(truth - e.view.hpFraction) > 0.02) {
                        mismatched++;
                        if (sample === "")
                            sample = e.def.label + " truth=" + truth.toFixed(2)
                                   + " view=" + e.view.hpFraction.toFixed(2);
                    }
                }
            }
            console.log("=== health bars in real combat ===");
            console.log("  alive=" + sim.enemies.list.length + " damaged=" + damaged
                        + " mismatched=" + mismatched + (sample ? "  " + sample : ""));
            check("something actually took damage", damaged > 0);
            check("every view matches its entity", mismatched === 0, "bad=" + mismatched);

            // ---- inspector, through the real panel ------------------------
            console.log("=== inspector after repeated upgrades ===");
            insp = findByProp(game, "upCost");
            if (!insp) {
                check("found the inspector panel", false);
                return;
            }
            const t = sim.towers.list[0];
            sim.selected = t;

            const c0 = insp.upCost, l0 = insp.level, d0 = insp.stats.dmg;
            sim.tryUpgradeSelected();
            const c1 = insp.upCost, l1 = insp.level, d1 = insp.stats.dmg;
            sim.tryUpgradeSelected();
            const c2 = insp.upCost, l2 = insp.level, d2 = insp.stats.dmg;

            console.log("  level " + l0 + "->" + l1 + "->" + l2
                        + "   dmg " + d0 + "->" + d1 + "->" + d2
                        + "   cost " + c0 + "->" + c1 + "->" + c2);
            check("level advances on each click", l0 === 0 && l1 === 1 && l2 === 2);
            check("damage shown changes each time", d0 !== d1 && d1 !== d2);
            check("upgrade cost changes each time", c0 !== c1 && c1 !== c2);
            // Tier IV exists but is sealed until the run survives the prestige
            // wave, so the top of the ladder mid-run is "locked", not "maxed".
            check("panel reports tier IV locked mid-run", insp.locked && !insp.maxed && c2 === -1);

            sim.waves.wave = Balance.prestigeWave + 1;
            sim.selRev += 1;
            check("unlocking reopens the develop button", !insp.locked && insp.upCost > 0,
                  "cost " + insp.upCost);
            sim.tryUpgradeSelected();
            check("the fourth tier lands", insp.level === 3 && insp.maxed && insp.upCost === -1,
                  "level " + insp.level + " dmg " + insp.stats.dmg);

            console.log(fails === 0 ? "=== ALL CHECKS PASSED ===" : "=== " + fails + " CHECK(S) FAILED ===");
        }
    }
}
