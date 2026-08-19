pragma ComponentBehavior: Bound

import QtQuick

// The coordinator. Owns the managers, the clock and the player's wallet, and
// wires the systems together without any of them knowing about each other.
QtObject {
    id: sim

    // ---- run state --------------------------------------------------------
    property int cash: Balance.startCash
    property int lives: Balance.startLives
    property int score: 0
    property int kills: 0
    property int leaks: 0
    property int bestWave: 0

    property real speed: 1.0        // 0 while paused
    property real lastSpeed: 1.0
    property bool started: false
    property bool over: false
    // Cleared while the overlay is hidden so a run pauses instead of playing on.
    property bool active: true

    // "classic" offers every car; "draft" randomises the shop each run.
    property string mode: "classic"
    property var availableTowers: []

    // ---- interaction state ------------------------------------------------
    property string placingId: ""
    property var selected: null     // a tower object
    property int selRev: 0          // bumped so the inspector re-reads a mutated tower
    property real ghostX: 0
    property real ghostY: 0
    property bool ghostValid: false

    signal announce(string text, string kind)
    signal shake(real amount)

    readonly property bool paused: speed === 0
    readonly property int wave: waves.wave
    readonly property string phase: over ? "over" : waves.phase

    // ---- managers ---------------------------------------------------------
    readonly property Fx fx: Fx {}

    // The run's ledger, written by every manager that resolves damage or a
    // death and read only by the end-of-run summary.
    readonly property Stats ledger: Stats {}

    readonly property EnemyManager enemies: EnemyManager {
        ledger: sim.ledger
    }

    readonly property ProjectileManager projectiles: ProjectileManager {
        enemies: sim.enemies
        fx: sim.fx
        ledger: sim.ledger
    }

    readonly property TowerManager towers: TowerManager {
        enemies: sim.enemies
        projectiles: sim.projectiles
        fx: sim.fx
        ledger: sim.ledger
        // Only read to decide whether the fourth development tier has unlocked.
        wave: sim.waves.wave
    }

    readonly property WaveManager waves: WaveManager {
        enemies: sim.enemies
    }

    // ---- signal wiring ----------------------------------------------------
    readonly property Connections enemyConn: Connections {
        target: sim.enemies

        function onLeaked(enemy: var): void {
            sim.leaks += 1;
            sim.lives -= enemy.def.leak;
            sim.shake(Math.min(16, 4 + enemy.def.leak * 2));
            sim.announce(enemy.def.label + " got through  −" + enemy.def.leak, "bad");
            if (sim.lives <= 0)
                sim.endRun();
        }

        function onKilled(enemy: var, bounty: int): void {
            sim.kills += 1;
            sim.cash += bounty;
            sim.score += Math.round(enemy.hpMax / 4) + bounty;
            const hue = Theme[enemy.def.hue] || Theme.fg;
            sim.fx.burst(enemy.x, enemy.y, enemy.boss ? 40 : 12,
                         hue, enemy.boss ? 460 : 190, "decrypt", enemy.boss ? 22 : 15);
            if (enemy.boss) {
                sim.shake(14);
                sim.announce(enemy.def.label + " retracted", "good");
            }
        }

        function onStunRequested(x: real, y: real, radius: real, seconds: real): void {
            const caught = sim.towers.stunArea(x, y, radius, seconds);
            sim.fx.burst(x, y, 26, Theme.magenta, radius, "decrypt", 18);
            if (caught <= 0) {
                // Worth saying out loud: the Pace Car just earned its place.
                sim.announce("Stun pulse absorbed — nothing was caught", "good");
                return;
            }
            sim.shake(6);
            sim.announce("ENGAGEMENT-FARM stunned " + caught
                         + (caught === 1 ? " car" : " cars")
                         + " for " + seconds.toFixed(1) + "s", "bad");
        }
    }

    // Support buffs on the selected car change when any other car is parked,
    // retired or developed, so those all invalidate the inspector too.
    readonly property Connections towerConn: Connections {
        target: sim.towers

        function onPlaced(tower: var): void {
            sim.selRev += 1;
            // Parking the first car is what starts the clock. Until then the
            // player is looking at a demonstration lap with no time pressure.
            sim.waves.armed = true;
        }
        function onSold(tower: var, refund: int): void { sim.selRev += 1; }
        function onUpgraded(tower: var): void { sim.selRev += 1; }
    }

    readonly property Connections waveConn: Connections {
        target: sim.waves

        function onWaveStarted(n: int): void {
            const early = sim.waves.earlyBonus;
            if (early > 0) {
                sim.cash += early;
                sim.announce("WAVE " + n + "  ·  called early  +" + early, "good");
            } else {
                sim.announce("WAVE " + n, Balance.isBossWave(n) ? "boss" : "info");
            }
            sim.bestWave = Math.max(sim.bestWave, n);
        }

        function onWaveCleared(n: int, bonus: int, unused: int): void {
            // Barge payouts ride the same decay as bounties and wave bonuses,
            // so an economy built on wave 8 is not still printing on wave 40.
            const income = Math.round(sim.towers.waveIncome() * Balance.incomeScale(n));
            sim.cash += bonus + income;
            sim.score += bonus;
            sim.announce(income > 0
                         ? "WAVE " + n + " CLEARED  +" + bonus + "  ·  barges +" + income
                         : "WAVE " + n + " CLEARED  +" + bonus, "good");
        }
    }

    // ---- clock ------------------------------------------------------------
    readonly property FrameAnimation clock: FrameAnimation {
        running: sim.started && !sim.over && sim.active
        onTriggered: {
            if (sim.speed === 0)
                return;
            // Clamp so a stalled frame cannot teleport the convoy through the map.
            const dt = Math.min(frameTime, 0.05) * sim.speed;
            sim.waves.update(dt);
            sim.enemies.update(dt);
            sim.towers.update(dt);
            sim.projectiles.update(dt);
            sim.fx.update(dt);
        }
    }

    // ---- lifecycle --------------------------------------------------------
    function newRun(runMode: string): void {
        mode = runMode || "classic";
        cash = Balance.startCash;
        lives = Balance.startLives;
        score = 0;
        kills = 0;
        leaks = 0;
        speed = 1.0;
        lastSpeed = 1.0;
        over = false;
        placingId = "";
        selected = null;

        enemies.reset();
        towers.reset();
        projectiles.reset();
        fx.reset();
        waves.reset();
        ledger.reset();

        availableTowers = rollShop();
        started = true;
        announce(mode === "draft" ? "DRAFT RUN — work with what you were dealt" : "DEFEND THE CONVOY", "info");
    }

    // Draft mode deliberately breaks the solved meta: you get a random hand,
    // but always at least one detector and one economy car so runs stay winnable.
    function rollShop(): var {
        if (mode !== "draft")
            return Balance.towers.map(t => t.id);

        const all = Balance.towers.slice();
        const detectors = all.filter(t => t.levels.some(l => l.detect));
        const economy = all.filter(t => t.role === "economy");
        const pick = [];

        pick.push(detectors[Math.floor(Math.random() * detectors.length)].id);
        pick.push(economy[Math.floor(Math.random() * economy.length)].id);

        const rest = all.filter(t => pick.indexOf(t.id) < 0);
        for (let i = rest.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            const tmp = rest[i];
            rest[i] = rest[j];
            rest[j] = tmp;
        }
        for (const t of rest.slice(0, 3))
            pick.push(t.id);

        return Balance.towers.filter(t => pick.indexOf(t.id) >= 0).map(t => t.id);
    }

    // Drop the current run and go back to the circuit picker.
    function abandonRun(): void {
        started = false;
        over = false;
        speed = 1.0;
        lastSpeed = 1.0;
        placingId = "";
        selected = null;
        enemies.reset();
        towers.reset();
        projectiles.reset();
        fx.reset();
        waves.reset();
        ledger.reset();
    }

    function endRun(): void {
        lives = 0;
        over = true;
        placingId = "";
        selected = null;
        waves.gameOver();
        // The tallies are plain JS maps and cannot notify on their own; this is
        // the one moment the summary needs them to, so it is bumped here.
        ledger.seal();
        announce("THE DISCOURSE WON", "bad");
    }

    // ---- player actions ---------------------------------------------------
    function canAfford(amount: int): bool {
        return cash >= amount;
    }

    onSelectedChanged: selRev += 1

    function beginPlacing(defId: string): void {
        const def = Balance.tower(defId);
        if (!def || over)
            return;
        if (paused) {
            announce("Paused — resume before parking a car", "info");
            return;
        }
        if (availableTowers.indexOf(defId) < 0)
            return;
        if (towers.atLimit(defId)) {
            announce(def.name + " limit reached (" + Balance.limitFor(defId) + ")", "bad");
            return;
        }
        selected = null;
        placingId = placingId === defId ? "" : defId;
    }

    function cancelPlacing(): void {
        placingId = "";
    }

    function tryPlace(x: real, y: real): bool {
        if (placingId === "" || paused)
            return false;
        const def = Balance.tower(placingId);
        if (!canAfford(def.cost)) {
            announce("Not enough cash for " + def.name, "bad");
            return false;
        }
        if (towers.atLimit(placingId)) {
            announce(def.name + " limit reached (" + Balance.limitFor(placingId) + ")", "bad");
            placingId = "";
            return false;
        }
        const t = towers.place(placingId, x, y);
        if (!t) {
            announce("Cannot park there", "bad");
            return false;
        }
        cash -= def.cost;
        fx.burst(x, y, 10, Theme[def.hue] || Theme.accent, 170, def.weapon, 14);
        return true;
    }

    function trySellSelected(): void {
        if (!selected)
            return;
        cash += towers.sell(selected);
        selected = null;
    }

    function tryUpgradeSelected(): void {
        if (!selected)
            return;
        if (towers.upgradeLocked(selected)) {
            announce("Tier IV unlocks after wave " + Balance.prestigeWave, "info");
            return;
        }
        const cost = towers.upgradeCost(selected);
        if (cost < 0) {
            announce("Already fully developed", "info");
            return;
        }
        if (!canAfford(cost)) {
            announce("Need " + cost + " to develop", "bad");
            return;
        }
        cash -= cost;
        towers.upgrade(selected);
        selRev += 1;
        fx.burst(selected.x, selected.y, 14, Theme.brightYellow, 200, "highlight", 15);
    }

    function cycleTargetMode(dir: int): void {
        if (!selected || selected.def.role !== "damage")
            return;
        const modes = Balance.targetModes;
        let i = modes.findIndex(m => m.id === selected.targetMode);
        i = (i + (dir || 1) + modes.length) % modes.length;
        selected.targetMode = modes[i].id;
        selRev += 1;
        announce(selected.def.name + " targeting " + modes[i].label, "info");
    }

    // A manual pause is a full stop, not a slow-motion mode: the board is
    // frozen, the veil goes up and placement is locked. Resuming always returns
    // to 1x so nobody unpauses straight back into 3x by accident.
    function togglePause(): void {
        if (speed === 0)
            resume();
        else
            pause();
    }

    function pause(): void {
        if (speed === 0)
            return;
        lastSpeed = speed;
        speed = 0;
        placingId = "";
    }

    function resume(): void {
        speed = 1.0;
        lastSpeed = 1.0;
    }

    function setSpeed(s: real): void {
        if (s === 0) {
            pause();
            return;
        }
        speed = s;
        lastSpeed = s;
    }

    function callWave(): void {
        if (waves.phase === "planning")
            waves.startWave();
    }
}
