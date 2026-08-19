import QtQuick
import Quickshell
import "game"

// Reproduces upgrading one car repeatedly without reselecting it, and checks
// the inspector's bindings keep up with the tower it is pointed at.
ShellRoot {
    Sim { id: sim }
    Inspector { id: insp; sim: sim }

    function row(tag) {
        console.log("  " + tag.padEnd(14)
                    + " level=" + insp.level
                    + "  dmg=" + String(insp.stats ? insp.stats.dmg : "-").padStart(4)
                    + "  range=" + String(insp.stats ? insp.stats.range : "-").padStart(4)
                    + "  upCost=" + String(insp.upCost).padStart(5)
                    + "  maxed=" + String(insp.maxed).padStart(5)
                    + "  refund=" + String(insp.refund).padStart(5)
                    + "  note='" + insp.nextNote + "'");
    }

    function check(name, cond, detail) {
        console.log((cond ? "  PASS  " : "  FAIL  ") + name + (detail ? "   [" + detail + "]" : ""));
        return cond;
    }

    Component.onCompleted: {
        let fails = 0;
        sim.newRun("classic");
        sim.cash = 99999;

        const t = sim.towers.place("e2", Balance.slots[0].x, Balance.slots[0].y);
        sim.selected = t;

        console.log("=== develop the same car three times, never reselecting ===");
        row("selected");
        fails += !check("starts at level 0", insp.level === 0 && insp.stats.dmg === 95);

        sim.tryUpgradeSelected();
        row("after 1st");
        fails += !check("level 1 stats and cost agree",
                        insp.level === 1 && insp.stats.dmg === 165 && insp.upCost === 520 && !insp.maxed,
                        "level=" + insp.level + " upCost=" + insp.upCost);

        sim.tryUpgradeSelected();
        row("after 2nd");
        // Tier IV exists but is sealed until the run survives the prestige wave,
        // so the top of the mid-run ladder is "locked", not "fully developed".
        fails += !check("level 2 reports tier IV locked, not maxed",
                        insp.level === 2 && insp.stats.dmg === 280
                        && insp.locked && !insp.maxed && insp.upCost === -1,
                        "level=" + insp.level + " upCost=" + insp.upCost
                        + " locked=" + insp.locked + " maxed=" + insp.maxed);
        fails += !check("refund tracks what was actually spent",
                        insp.refund === Math.floor((260 + 280 + 520) * 0.7),
                        "refund=" + insp.refund);
        fails += !check("the note explains the lock rather than teasing a tier",
                        insp.nextNote.indexOf("wave " + Balance.prestigeWave) >= 0,
                        "note='" + insp.nextNote + "'");

        const cashBefore = sim.cash;
        sim.tryUpgradeSelected();
        row("after 3rd");
        fails += !check("a further develop is refused and charges nothing",
                        insp.level === 2 && sim.cash === cashBefore, "cash=" + sim.cash);

        console.log("=== past the prestige wave, without reselecting ===");
        sim.waves.wave = Balance.prestigeWave + 1;
        sim.selRev += 1;
        row("unlocked");
        fails += !check("the panel reopens for tier IV",
                        !insp.locked && !insp.maxed && insp.upCost === 1320,
                        "upCost=" + insp.upCost);

        sim.tryUpgradeSelected();
        row("after 4th");
        fails += !check("tier IV is the top of the ladder",
                        insp.level === 3 && insp.stats.dmg === 495
                        && insp.maxed && !insp.locked && insp.nextNote === "",
                        "level=" + insp.level + " dmg=" + insp.stats.dmg
                        + " maxed=" + insp.maxed);

        console.log("=== targeting without reselecting ===");
        sim.cycleTargetMode(1);
        fails += !check("targeting updates", insp.targetMode === "last", insp.targetMode);

        console.log(fails === 0 ? "=== ALL CHECKS PASSED ===" : "=== " + fails + " CHECK(S) FAILED ===");
    }
}
