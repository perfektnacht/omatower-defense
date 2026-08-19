import QtQuick
import Quickshell
import "game"

// Mono-car balance probe. Each damage car gets the same budget and the same
// dumb autoplayer, alone, and the run is played until it dies.
//
// Solo runs are not how the game is meant to be played, but they are the
// cleanest way to compare cars: no support buffs, no economy, no other car
// covering a weakness. If one car reaches twice the wave of every other, that
// is a tuning problem rather than a strategy.
ShellRoot {
    Sim { id: sim }

    function step(seconds, dt) {
        const n = Math.ceil(seconds / dt);
        for (let i = 0; i < n; i++) {
            sim.waves.update(dt);
            sim.enemies.update(dt);
            sim.towers.update(dt);
            sim.projectiles.update(dt);
        }
    }

    function placeAnywhere(id) {
        for (let a = 0; a < 30000; a++) {
            const x = 80 + Math.random() * (Balance.fieldW - 160);
            const y = 80 + Math.random() * (Balance.fieldH - 160);
            const t = sim.towers.canPlace(x, y) ? sim.towers.place(id, x, y) : null;
            if (t)
                return t;
        }
        return null;
    }

    // Buy and develop only the one car, keeping nothing in reserve. Upgrades
    // come first because a developed car is almost always worth more than a
    // second stock one.
    function reinvest(id) {
        const def = Balance.tower(id);
        let spent = true;
        while (spent) {
            spent = false;

            let best = null;
            for (const t of sim.towers.list) {
                const c = sim.towers.upgradeCost(t);
                if (c > 0 && c <= sim.cash && (!best || c < sim.towers.upgradeCost(best)))
                    best = t;
            }
            if (best) {
                sim.cash -= sim.towers.upgradeCost(best);
                sim.towers.upgrade(best);
                spent = true;
                continue;
            }

            if (def.cost <= sim.cash && placeAnywhere(id)) {
                sim.cash -= def.cost;
                spent = true;
            }
        }
    }

    Component.onCompleted: {
        const dt = 1 / 30;
        const cap = 40;
        Balance.selectCircuit(0);

        console.log("=== solo runs on " + Balance.circuit.name
                    + ", capped at wave " + cap + " ===");
        console.log("  car                 wave  cars  damage    spent   dmg/cash  detects");

        const results = [];

        for (const def of Balance.towers) {
            if (def.role !== "damage")
                continue;

            sim.newRun("classic");
            let spent = 0;
            const cashBefore = () => sim.cash;

            for (let w = 1; w <= cap && !sim.over; w++) {
                const before = sim.cash;
                reinvest(def.id);
                spent += before - sim.cash;
                sim.callWave();
                let guard = 0;
                while (sim.waves.phase !== "planning" && guard < 9000 && !sim.over) {
                    step(dt, dt);
                    guard++;
                }
            }

            const damage = Math.round(sim.ledger.totalDamage());
            const detects = def.levels.some(l => l.detect);
            results.push({ id: def.id, name: def.name, wave: sim.wave, damage: damage });

            console.log("  " + def.name.padEnd(20)
                        + String(sim.wave).padStart(4)
                        + String(sim.towers.list.length).padStart(6)
                        + String(damage).padStart(9)
                        + String(spent).padStart(8)
                        + (spent > 0 ? (damage / spent).toFixed(1) : "-").padStart(11)
                        + (detects ? "   yes" : "   no"));
        }

        results.sort((a, b) => b.wave - a.wave);
        const best = results[0];
        const rest = results.slice(1);
        const median = rest[Math.floor(rest.length / 2)];

        console.log("");
        console.log("  best solo car: " + best.name + " to wave " + best.wave);
        console.log("  median of the rest: " + median.name + " to wave " + median.wave);
        console.log("  lead: " + (median.wave > 0 ? (best.wave / median.wave).toFixed(2) : "inf") + "x");
    }
}
