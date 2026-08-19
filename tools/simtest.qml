import QtQuick
import Quickshell
import "game"

// Headless balance harness. No layers, no views: the managers are driven
// directly, which is the whole point of keeping them free of rendering.
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

    function scatter(ids) {
        let placed = 0;
        for (let a = 0; a < 30000 && placed < ids.length; a++) {
            const x = 80 + Math.random() * (Balance.fieldW - 160);
            const y = 80 + Math.random() * (Balance.fieldH - 160);
            if (sim.towers.canPlace(x, y) && sim.towers.place(ids[placed], x, y))
                placed++;
        }
        sim.towers.recomputeSupport();
        return placed;
    }

    // Placement is legal only off the racing line, so tests have to look for a
    // spot rather than assume one.
    function placeAnywhere(id) {
        for (let a = 0; a < 30000; a++) {
            const x = 80 + Math.random() * (Balance.fieldW - 160);
            const y = 80 + Math.random() * (Balance.fieldH - 160);
            const t = sim.towers.canPlace(x, y) ? sim.towers.place(id, x, y) : null;
            if (t) return t;
        }
        return null;
    }

    function placeNear(id, ox, oy, maxDist) {
        for (let a = 0; a < 30000; a++) {
            const ang = Math.random() * Math.PI * 2;
            const r = 80 + Math.random() * (maxDist - 80);
            const x = ox + Math.cos(ang) * r;
            const y = oy + Math.sin(ang) * r;
            const t = sim.towers.canPlace(x, y) ? sim.towers.place(id, x, y) : null;
            if (t) return t;
        }
        return null;
    }

    function check(name, cond, detail) {
        console.log((cond ? "  PASS  " : "  FAIL  ") + name + (detail ? "   [" + detail + "]" : ""));
        return cond;
    }

    Component.onCompleted: {
        const dt = 1 / 30;
        let fails = 0;

        console.log("=== unit checks ===");

        // --- damage model -------------------------------------------------
        sim.newRun("classic");
        let e = sim.enemies.spawn("notforbeginners", {});   // armor 10
        let before = e.hp;
        sim.enemies.damage(e, 50, "data");
        const dataDealt = before - e.hp;
        fails += !check("armour blunts DATA", Math.abs(dataDealt - 40) < 0.01, "dealt " + dataDealt);

        e = sim.enemies.spawn("notforbeginners", {});
        before = e.hp;
        sim.enemies.damage(e, 50, "beam");
        const beamDealt = before - e.hp;
        fails += !check("BEAM ignores armour", Math.abs(beamDealt - 50) < 0.01, "dealt " + beamDealt);

        e = sim.enemies.spawn("archbtw", {});               // field immune
        before = e.hp;
        sim.enemies.damage(e, 100, "field");
        fails += !check("i-use-arch-btw is FIELD immune", e.hp === before);

        sim.enemies.applySlow(e, 0.5, 2);
        fails += !check("i-use-arch-btw cannot be slowed", e.slowFactor === 0);

        e = sim.enemies.spawn("bloated", {});               // blast vulnerable
        before = e.hp;
        sim.enemies.damage(e, 100, "blast");
        const blastDealt = before - e.hp;
        fails += !check("bloated takes extra BLAST", blastDealt > 100, "dealt " + blastDealt.toFixed(1));

        // --- shields ---------------------------------------------------------
        e = sim.enemies.spawn("vcfunded", {});
        const hp0 = e.hp;
        sim.enemies.damage(e, 100, "beam");
        fails += !check("shield absorbs before health", e.hp === hp0 && e.shield < e.shieldMax,
                        "shield " + e.shield.toFixed(0) + "/" + e.shieldMax);

        // --- stealth ---------------------------------------------------------
        sim.enemies.reset();
        const spy = sim.enemies.spawn("telemetry", { dist: 400 });
        const blind = sim.enemies.pickTarget(spy.x, spy.y, 300, false, "first");
        const seeing = sim.enemies.pickTarget(spy.x, spy.y, 300, true, "first");
        fails += !check("stealth invisible without detection", blind === null);
        fails += !check("stealth visible with detection", seeing !== null);

        // --- no-cash splits ---------------------------------------------------
        sim.enemies.reset();
        const splitter = sim.enemies.spawn("breaks", { dist: 500 });
        sim.enemies.kill(splitter);
        const halves = sim.enemies.list.filter(x => x.def.id === "notadistro");
        fails += !check("splitter leaves two halves", halves.length === 2, "got " + halves.length);
        fails += !check("halves pay no bounty", halves.every(h => h.bounty === 0));

        // --- entities spawned mid-update ---------------------------------
        // A summoning boss appends to the list while update() is iterating it.
        sim.enemies.reset();
        sim.enemies.spawn("discourse", {});
        step(9, dt);
        const summoned = sim.enemies.list.filter(x => x.def.id === "hype");
        fails += !check("boss summons survive the update pass", summoned.length > 0,
                        "summoned " + summoned.length);
        fails += !check("summons are free kills", summoned.every(x => x.bounty === 0));

        // --- targeting priority -------------------------------------------------
        sim.enemies.reset();
        const near = sim.enemies.spawn("notadistro", { dist: 300 });
        const far = sim.enemies.spawn("bloated", { dist: 340 });
        const first = sim.enemies.pickTarget(near.x, near.y, 900, true, "first");
        const strong = sim.enemies.pickTarget(near.x, near.y, 900, true, "strong");
        fails += !check("FIRST picks the leader", first === far, first ? first.def.id : "null");
        fails += !check("STRONG picks the tank", strong === far, strong ? strong.def.id : "null");
        const last = sim.enemies.pickTarget(near.x, near.y, 900, true, "last");
        fails += !check("LAST picks the trailer", last === near, last ? last.def.id : "null");

        // --- support + economy ----------------------------------------------
        sim.newRun("classic");
        const q = placeAnywhere("q80");
        const baseRange = sim.towers.effRange(q);
        const pace = placeNear("pace", q.x, q.y, 200);
        fails += !check("pace car buffs a neighbour", pace !== null && sim.towers.effRange(q) > baseRange,
                        baseRange + " -> " + sim.towers.effRange(q).toFixed(0));

        placeAnywhere("barge");
        fails += !check("barge generates wave income", sim.towers.waveIncome() > 0,
                        "+" + sim.towers.waveIncome());

        // --- tower stun + cleanse ----------------------------------------------
        sim.newRun("classic");
        const lone = placeAnywhere("q80");
        sim.towers.stunArea(lone.x, lone.y, 300, 3);
        fails += !check("rage-bait stuns an unprotected car", lone.stunTimer > 0);

        sim.newRun("classic");
        const guarded = placeAnywhere("q80");
        const minder = placeNear("pace", guarded.x, guarded.y, 200);
        const caughtGuarded = sim.towers.stunArea(guarded.x, guarded.y, 300, 3);
        fails += !check("pace car cleanses the stun", minder !== null && guarded.stunTimer === 0);
        fails += !check("a fully absorbed pulse reports catching nothing",
                        caughtGuarded === 0, "caught " + caughtGuarded);

        // --- the player can see who is stunned ----------------------------------
        sim.newRun("classic");
        const victims = [placeAnywhere("q80"), placeAnywhere("s1"), placeAnywhere("rs")];
        const hit = sim.towers.stunArea(Balance.fieldW / 2, Balance.fieldH / 2, 4000, 2.5);
        fails += !check("the stun reports how many cars it caught",
                        hit === 3 && sim.towers.stunnedCount === 3,
                        "caught " + hit + ", count " + sim.towers.stunnedCount);

        step(1.0, dt);
        const draining = victims.every(v => v.stunTimer > 0 && v.stunTimer < v.stunMax);
        fails += !check("stun remaining drains toward zero", draining,
                        victims.map(v => v.stunTimer.toFixed(2)).join(" "));

        step(2.0, dt);
        fails += !check("the count clears when the stun wears off",
                        sim.towers.stunnedCount === 0
                        && victims.every(v => v.stunTimer === 0));

        // Retiring a frozen car must not leave it on the tally.
        sim.towers.stunArea(Balance.fieldW / 2, Balance.fieldH / 2, 4000, 3);
        sim.towers.sell(victims[0]);
        fails += !check("retiring a stunned car takes it off the tally",
                        sim.towers.stunnedCount === 2,
                        "count " + sim.towers.stunnedCount);

        // --- per-car limits -----------------------------------------------
        sim.newRun("classic");
        let barges = 0;
        for (let i = 0; i < 5; i++) {
            if (placeAnywhere("barge"))
                barges++;
        }
        fails += !check("service barges are capped per run",
                        barges === Balance.limitFor("barge") && sim.towers.atLimit("barge"),
                        "placed " + barges + " of 5 attempts");

        sim.newRun("classic");
        sim.cash = 99999;
        for (let i = 0; i < 4; i++) {
            sim.beginPlacing("barge");
            const slot = sim.towers.nearestFreeSlot(Balance.fieldW / 2, Balance.fieldH / 2)
                       || Balance.slots[i];
            if (sim.placingId !== "")
                sim.tryPlace(slot.x, slot.y);
        }
        fails += !check("the shop path respects the same cap",
                        sim.towers.countOf("barge") <= Balance.limitFor("barge"),
                        "owns " + sim.towers.countOf("barge"));

        // --- development tiers ------------------------------------------------
        sim.newRun("classic");
        sim.cash = 999999;
        const climber = placeAnywhere("q80");
        for (let i = 0; i < 5; i++) {
            sim.selected = climber;
            sim.tryUpgradeSelected();
        }
        fails += !check("tier IV is locked before the prestige wave",
                        climber.level === 2 && sim.towers.upgradeLocked(climber)
                        && sim.towers.upgradeCost(climber) === -1,
                        "level " + climber.level + " on wave " + sim.wave);

        sim.waves.wave = Balance.prestigeWave + 1;
        fails += !check("tier IV unlocks after the prestige wave",
                        !sim.towers.upgradeLocked(climber)
                        && sim.towers.upgradeCost(climber) > 0,
                        "cost " + sim.towers.upgradeCost(climber));

        sim.selected = climber;
        sim.tryUpgradeSelected();
        const l3 = climber.def.levels[3];
        fails += !check("tier IV actually applies its stats",
                        climber.level === 3 && sim.towers.stats(climber) === l3
                        && sim.towers.upgradeCost(climber) === -1,
                        "dmg " + sim.towers.stats(climber).dmg);

        fails += !check("every car has four tiers",
                        Balance.towers.every(t => t.levels.length === 4));

        // --- income decay -----------------------------------------------------
        fails += !check("income falls behind the threat curve",
                        Balance.incomeScale(1) === 1
                        && Balance.incomeScale(30) < 0.5
                        && Balance.waveBonus(30) < Balance.waveBonus(10) * 1.6
                        && Balance.waveScale(40) > Balance.waveScale(30),
                        "w5 " + Balance.incomeScale(5).toFixed(2)
                        + "  w30 " + Balance.incomeScale(30).toFixed(2)
                        + "  bonus w10 " + Balance.waveBonus(10)
                        + " -> w30 " + Balance.waveBonus(30));

        // --- the clock waits for the first car --------------------------------
        sim.newRun("classic");
        const t0 = sim.waves.planTimer;
        step(12, dt);
        fails += !check("the planning clock does not run before the first car",
                        !sim.waves.armed && sim.waves.planTimer === t0 && sim.wave === 0,
                        "timer " + sim.waves.planTimer.toFixed(1));

        placeAnywhere("q80");
        step(3, dt);
        fails += !check("parking the first car starts the clock",
                        sim.waves.armed && sim.waves.planTimer < t0,
                        "timer " + sim.waves.planTimer.toFixed(1));

        // --- pause is a full stop ---------------------------------------------
        sim.newRun("classic");
        sim.setSpeed(3);
        sim.beginPlacing("q80");
        sim.togglePause();
        fails += !check("pausing drops the placement in progress",
                        sim.paused && sim.placingId === "");
        sim.beginPlacing("q80");
        fails += !check("a paused board refuses new placements",
                        sim.placingId === "" && !sim.tryPlace(Balance.slots[0].x, Balance.slots[0].y));
        sim.togglePause();
        fails += !check("resuming always returns to 1x", sim.speed === 1);

        // --- beam attenuation ---------------------------------------------------
        // Five targets in a line must not mean five times the damage. Every
        // take walks the same racing line, so a beam is always lined up with
        // the queue and full-strength pierce is effectively free multi-target.
        sim.newRun("classic");
        const beam = placeAnywhere("e2");
        beam.level = 3;
        const lane = [];
        // Park the queue on the beam's axis, marching away from it.
        for (let i = 0; i < 5; i++) {
            const m = sim.enemies.spawn("notadistro", { hpScale: 400 });
            m.x = beam.x + 120 + i * 60;
            m.y = beam.y;
            lane.push(m);
        }
        beam.heading = 0;
        beam.cooldown = 0;
        sim.towers.fire(beam, lane[0], sim.towers.effRange(beam), true);

        const took = lane.map(m => Math.round(m.hpMax - m.hp));
        let descending = true;
        for (let i = 1; i < took.length; i++) {
            if (took[i] >= took[i - 1])
                descending = false;
        }
        fails += !check("the beam weakens through the queue",
                        took[0] > 0 && descending && took[4] < took[0] * 0.25,
                        took.join(" -> "));

        fails += !check("a full line is worth well under N times one target",
                        (function () {
                            let line = 0;
                            for (let i = 0; i < 5; i++)
                                line += Balance.beamShare(i);
                            return line > 2 && line < 3;
                        })(),
                        "line multiplier " + (function () {
                            let l = 0;
                            for (let i = 0; i < 5; i++) l += Balance.beamShare(i);
                            return l.toFixed(2);
                        })());

        // --- the run ledger ---------------------------------------------------
        sim.newRun("classic");
        const gunner = placeAnywhere("e2");
        const marks = [];
        for (let i = 0; i < 4; i++)
            marks.push(sim.enemies.spawn("notadistro", { dist: 40 + i * 8 }));
        // Park the beam where it can actually see them.
        gunner.heading = Math.atan2(marks[0].y - gunner.y, marks[0].x - gunner.x) * 180 / Math.PI;
        gunner.x = marks[0].x - 200;
        gunner.y = marks[0].y;
        gunner.heading = 0;
        step(4, dt);

        const beamDamage = sim.ledger.damageByTower["e2"] || 0;
        fails += !check("damage is credited to the car that dealt it",
                        beamDamage > 0 && sim.ledger.totalDamage() === beamDamage,
                        "e2 dealt " + Math.round(beamDamage));

        const refuted = sim.ledger.killsByEnemy["notadistro"] || 0;
        fails += !check("kills are tallied by take",
                        refuted > 0 && refuted === sim.kills,
                        "not-a-distro x" + refuted);

        // Retiring a car must not erase what it did. The ledger is keyed by
        // definition, not by instance, precisely so a mid-run sell-off does not
        // rewrite the history of the run.
        sim.towers.sell(gunner);
        fails += !check("retiring a car keeps its damage on the books",
                        (sim.ledger.damageByTower["e2"] || 0) === beamDamage,
                        "still " + Math.round(sim.ledger.damageByTower["e2"] || 0));

        fails += !check("the summary lists a car that never fired",
                        (function () {
                            sim.newRun("classic");
                            placeAnywhere("barge");
                            const rows = sim.ledger.damageTable();
                            return rows.length === 1 && rows[0].id === "barge" && rows[0].amount === 0;
                        })());

        sim.newRun("classic");
        fails += !check("a new run starts from an empty ledger",
                        sim.ledger.totalDamage() === 0
                        && sim.ledger.damageTable().length === 0
                        && sim.ledger.killTable().length === 0);

        // --- parking bay survey ------------------------------------------
        console.log("=== parking bays per circuit ===");
        for (let ci = 0; ci < Balance.circuits.length; ci++) {
            Balance.selectCircuit(ci);
            sim.newRun("classic");
            console.log("  " + Balance.circuit.name.padEnd(20)
                        + " lap " + String(Math.round(Balance.trackLength)).padStart(5)
                        + "   bays " + String(Balance.slots.length).padStart(3));
        }

        // --- integration ---------------------------------------------------
        // A modest autoplayer: between waves it develops what it has and buys
        // another car when it can, keeping a small reserve. If a run played
        // this plainly falls apart, the balance is wrong, not the player.
        function reinvest(reserve) {
            let spent = true;
            while (spent) {
                spent = false;

                // Develop the cheapest upgrade we can afford.
                let best = null;
                for (const t of sim.towers.list) {
                    const c = sim.towers.upgradeCost(t);
                    if (c > 0 && c <= sim.cash - reserve && (!best || c < sim.towers.upgradeCost(best)))
                        best = t;
                }
                if (best) {
                    sim.cash -= sim.towers.upgradeCost(best);
                    sim.towers.upgrade(best);
                    spent = true;
                    continue;
                }

                // Otherwise add another car if there is room in the budget.
                const affordable = sim.availableTowers
                    .map(id => Balance.tower(id))
                    .filter(d => d.cost <= sim.cash - reserve)
                    .sort((a, b) => b.cost - a.cost);
                if (affordable.length > 0) {
                    const t = placeAnywhere(affordable[0].id);
                    if (t) {
                        sim.cash -= affordable[0].cost;
                        spent = true;
                    }
                }
            }
        }

        for (const circuitIdx of [0]) {
            Balance.selectCircuit(circuitIdx);
            console.log("=== 30-wave run on " + Balance.circuit.name + " ===");
            sim.newRun("classic");
            const placed = scatter(["q80", "e2", "s1", "barge"]);
            console.log("  parked " + placed + " cars, lap length " + Math.round(Balance.trackLength));

            for (let w = 1; w <= 30 && !sim.over; w++) {
                reinvest(120);
                sim.callWave();
                let guard = 0;
                while (sim.waves.phase !== "planning" && guard < 9000 && !sim.over) {
                    step(dt, dt);
                    guard++;
                }
                console.log("  wave " + String(w).padStart(2)
                            + "  lives " + String(sim.lives).padStart(3)
                            + "  cash " + String(sim.cash).padStart(5)
                            + "  cars " + String(sim.towers.list.length).padStart(3)
                            + "  kills " + String(sim.kills).padStart(4)
                            + "  leaks " + String(sim.leaks).padStart(3)
                            + (sim.over ? "   RUN OVER" : ""));
            }

            // Dying to the wave-30 trio is the intended shape of a run; sailing
            // past it, or folding before wave 20, both mean the balance is off.
            fails += !check(Balance.circuit.name + ": a plain run lasts 20-30 waves",
                            sim.wave >= 20, "reached wave " + sim.wave + ", lives " + sim.lives);
        }

        // --- the endless treadmill --------------------------------------------
        // A run that survives the trio has to keep getting harder. This one is
        // handed a real defence and a bankroll so it actually gets past wave 30,
        // which is the only way to exercise tier IV and the compounding ramp.
        Balance.selectCircuit(0);
        console.log("=== prestige run on " + Balance.circuit.name + " (waves 28-40) ===");
        sim.newRun("classic");
        const fleet = [];
        for (let i = 0; i < 7; i++)
            fleet.push("e2", "q80", "rs", "bh");
        fleet.push("s1", "pace", "pace", "barge", "barge");
        scatter(fleet);
        sim.waves.wave = 27;
        sim.cash = 30000;

        let sawTier4 = false;
        for (let w = 28; w <= 40 && !sim.over; w++) {
            reinvest(200);
            sim.cash += 2500;             // stands in for a better player's economy
            sim.callWave();
            let guard = 0;
            while (sim.waves.phase !== "planning" && guard < 9000 && !sim.over) {
                step(dt, dt);
                guard++;
            }
            const top = sim.towers.list.reduce((m, t) => Math.max(m, t.level), 0);
            if (top >= 3)
                sawTier4 = true;
            console.log("  wave " + String(sim.wave).padStart(2)
                        + "  lives " + String(sim.lives).padStart(3)
                        + "  cash " + String(sim.cash).padStart(5)
                        + "  cars " + String(sim.towers.list.length).padStart(3)
                        + "  top tier " + (top + 1)
                        + "  hp x" + Balance.waveScale(sim.wave).toFixed(1)
                        + (sim.over ? "   RUN OVER" : ""));
        }

        fails += !check("a surviving run reaches tier IV", sawTier4);

        // A board this maxed does hold past wave 40 — the point is only that the
        // ramp never flattens, so the run always ends eventually rather than
        // settling into a solved, unlosable loop.
        let monotone = true;
        for (let w = Balance.prestigeWave; w < 80; w++) {
            if (Balance.waveScale(w + 1) <= Balance.waveScale(w))
                monotone = false;
        }
        fails += !check("health compounds every round past the prestige wave",
                        monotone && Balance.waveScale(60) > Balance.waveScale(40) * 2,
                        "w30 x" + Balance.waveScale(30).toFixed(1)
                        + "  w40 x" + Balance.waveScale(40).toFixed(1)
                        + "  w60 x" + Balance.waveScale(60).toFixed(1));

        sim.waves.wave = 39;
        sim.waves.startWave();
        const late = sim.enemies.spawn("notadistro", {});
        fails += !check("spawned takes actually carry the ramped health",
                        late.hpMax > Balance.enemy("notadistro").hp * 20,
                        "hp " + Math.round(late.hpMax));

        console.log(fails === 0 ? "=== ALL CHECKS PASSED ===" : "=== " + fails + " CHECK(S) FAILED ===");
    }
}
