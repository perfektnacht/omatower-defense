pragma ComponentBehavior: Bound

import QtQuick

// Reads wave configuration as pure data and turns it into spawn events.
// Adding an enemy or reordering a wave never touches this file.
QtObject {
    id: mgr

    property EnemyManager enemies: null

    property int wave: 0
    property string phase: "planning"   // planning | spawning | clearing | over
    property real planTimer: 0

    // The very first planning clock does not run until the player has parked a
    // car. A new player gets to watch the demonstration lap and read the route
    // for as long as they like instead of being rushed by a countdown they have
    // not been taught to read yet.
    property bool armed: false
    property int spawnedThisWave: 0
    property int totalThisWave: 0

    property var queue: []

    signal waveStarted(int n)
    signal waveCleared(int n, int bonus, int earlyBonus)

    readonly property real planFraction: Balance.planningSeconds > 0
        ? Math.max(0, planTimer) / Balance.planningSeconds : 0

    readonly property int earlyBonus: Math.floor(Math.max(0, planTimer) * Balance.earlyCallBonusPerSecond)

    readonly property var nextWavePreview: {
        const groups = Balance.wave(wave + 1);
        return groups.map(g => ({ def: Balance.enemy(g.id), count: g.count }));
    }

    function reset(): void {
        wave = 0;
        phase = "planning";
        planTimer = Balance.planningSeconds;
        armed = false;
        queue = [];
        spawnedThisWave = 0;
        totalThisWave = 0;
    }

    function startWave(): void {
        if (phase !== "planning")
            return;

        wave += 1;
        phase = "spawning";
        armed = true;

        const groups = Balance.wave(wave);
        const q = [];
        let total = 0;
        for (const g of groups) {
            q.push({
                id: g.id,
                remaining: g.count,
                gap: g.gap,
                timer: g.delay || 0
            });
            total += g.count;
        }
        queue = q;
        totalThisWave = total;
        spawnedThisWave = 0;

        if (enemies) {
            enemies.hpScale = Balance.waveScale(wave);
            enemies.bountyScale = Balance.incomeScale(wave);
        }

        mgr.waveStarted(wave);
    }

    function update(dt: real): void {
        switch (phase) {
        case "planning":
            if (!armed)
                break;
            planTimer -= dt;
            if (planTimer <= 0)
                startWave();
            break;

        case "spawning": {
            let pending = 0;
            for (const g of queue) {
                if (g.remaining <= 0)
                    continue;
                pending += g.remaining;
                g.timer -= dt;
                while (g.timer <= 0 && g.remaining > 0) {
                    enemies.spawn(g.id, {});
                    g.remaining -= 1;
                    spawnedThisWave += 1;
                    g.timer += g.gap;
                }
            }
            if (pending === 0)
                phase = "clearing";
            break;
        }

        case "clearing":
            if (!enemies || enemies.aliveCount() === 0)
                finishWave();
            break;
        }
    }

    function finishWave(): void {
        phase = "planning";
        planTimer = Balance.planningSeconds;
        mgr.waveCleared(wave, Balance.waveBonus(wave), 0);
    }

    function gameOver(): void {
        phase = "over";
        queue = [];
    }
}
