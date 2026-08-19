pragma ComponentBehavior: Bound

import QtQuick

// Placement, upgrades, aiming and firing. This is the only class that decides
// whether a square of grass can hold a Quattro.
QtObject {
    id: mgr

    property Item layer: null
    property Component viewComponent: null
    property EnemyManager enemies: null
    property ProjectileManager projectiles: null
    property Fx fx: null
    property Stats ledger: null

    property var list: []
    property int nextUid: 1

    // The current wave, mirrored from the WaveManager. Only used to decide
    // whether the fourth development tier has unlocked yet.
    property int wave: 0

    // How many cars are frozen right now. A notifying property so the HUD can
    // say so out loud: a stun that only shows as a mark on a car somewhere on
    // a 1600-unit circuit is a stun the player finds out about by losing.
    property int stunnedCount: 0

    // slotId -> tower, plus a counter the slot overlay can bind to.
    property var occupied: ({})
    property int slotRevision: 0

    signal placed(var tower)
    signal sold(var tower, int refund)
    signal upgraded(var tower)

    function reset(): void {
        for (const t of list) {
            if (t.view)
                t.view.destroy();
        }
        list = [];
        nextUid = 1;
        occupied = ({});
        stunnedCount = 0;
        slotRevision += 1;
    }

    function stats(t: var): var {
        return t.def.levels[t.level];
    }

    // ---- placement ---------------------------------------------------------
    // Placement snaps to the nearest unoccupied bay, so a car can never end up
    // straddling the racing line.
    function nearestFreeSlot(x: real, y: real): var {
        const slots = Balance.slots;
        let best = null;
        let bestD = Balance.snapRadius;
        for (const s of slots) {
            if (occupied[s.id])
                continue;
            const d = Math.hypot(s.x - x, s.y - y);
            if (d < bestD) {
                bestD = d;
                best = s;
            }
        }
        return best;
    }

    function isOccupied(slotId: int): bool {
        return occupied[slotId] !== undefined;
    }

    // ---- per-car limits ----------------------------------------------------
    function countOf(defId: string): int {
        let n = 0;
        for (const t of list) {
            if (t.defId === defId)
                n += 1;
        }
        return n;
    }

    function atLimit(defId: string): bool {
        const limit = Balance.limitFor(defId);
        return limit >= 0 && countOf(defId) >= limit;
    }

    function canPlace(x: real, y: real): bool {
        return nearestFreeSlot(x, y) !== null;
    }

    function place(defId: string, x: real, y: real): var {
        const def = Balance.tower(defId);
        if (!def || atLimit(defId))
            return null;
        const slot = nearestFreeSlot(x, y);
        if (!slot)
            return null;
        x = slot.x;
        y = slot.y;

        const t = {
            uid: mgr.nextUid++,
            slotId: slot.id,
            defId: defId,
            def: def,
            level: 0,
            x: x,
            y: y,
            heading: 0,
            cooldown: 0,
            pulse: 0,
            targetMode: "first",
            stunTimer: 0,
            stunMax: 0,
            buffRate: 0,
            buffRange: 0,
            buffDetect: false,
            kills: 0,
            damageDealt: 0,
            view: null
        };

        if (layer && viewComponent) {
            t.view = viewComponent.createObject(layer, {
                level: 0,
                x: x - Balance.carW / 2,
                y: y - Balance.carH / 2
            });
            // Same reason as EnemyManager: assign object references after
            // construction so the view shares them rather than copying them.
            if (t.view) {
                t.view.tower = t;
                t.view.def = def;
            }
        }

        if (ledger)
            ledger.addUse(defId);

        list.push(t);
        occupied[slot.id] = t;
        slotRevision += 1;
        recomputeSupport();
        mgr.placed(t);
        return t;
    }

    function sell(t: var): int {
        const refund = Balance.sellValue(t.defId, t.level);
        const i = list.indexOf(t);
        if (i < 0)
            return 0;
        list.splice(i, 1);
        delete occupied[t.slotId];
        slotRevision += 1;
        recountStunned();
        if (t.view) {
            t.view.destroy();
            t.view = null;
        }
        recomputeSupport();
        mgr.sold(t, refund);
        return refund;
    }

    function upgradeCost(t: var): int {
        if (t.level >= Balance.maxLevel())
            return -1;
        if (upgradeLocked(t))
            return -1;
        return t.def.levels[t.level + 1].cost;
    }

    // "No more tiers exist" and "the next tier has not unlocked yet" both stop
    // the DEVELOP button, but they are not the same message to the player.
    function upgradeLocked(t: var): bool {
        return t.level < Balance.maxLevel() && t.level + 1 > Balance.maxLevelAt(wave);
    }

    function upgrade(t: var): bool {
        if (t.level >= Balance.maxLevel() || upgradeLocked(t))
            return false;
        t.level += 1;
        if (t.view)
            t.view.level = t.level;
        recomputeSupport();
        mgr.upgraded(t);
        return true;
    }

    function towerAt(x: real, y: real): var {
        for (const t of list) {
            if (Math.hypot(t.x - x, t.y - y) <= 46)
                return t;
        }
        return null;
    }

    // ---- support layer ----------------------------------------------------
    // Pace Cars lend fire rate, range and packet inspection to their neighbours.
    function recomputeSupport(): void {
        for (const t of list) {
            t.buffRate = 0;
            t.buffRange = 0;
            t.buffDetect = false;
        }
        for (const pace of list) {
            if (pace.def.role !== "support")
                continue;
            const s = stats(pace);
            for (const t of list) {
                if (t === pace || t.def.role !== "damage")
                    continue;
                if (Math.hypot(t.x - pace.x, t.y - pace.y) > s.range)
                    continue;
                t.buffRate = Math.max(t.buffRate, s.buffRate);
                t.buffRange = Math.max(t.buffRange, s.buffRange);
                if (s.grantDetect)
                    t.buffDetect = true;
            }
        }
        for (const t of list) {
            if (t.view)
                t.view.range = effRange(t);
        }
    }

    function effRange(t: var): real {
        return stats(t).range * (1 + t.buffRange);
    }

    function effRate(t: var): real {
        return stats(t).rate * (1 + t.buffRate);
    }

    function canDetect(t: var): bool {
        return stats(t).detect || t.buffDetect;
    }

    // A Pace Car in range keeps its neighbours out of the stun.
    function shieldedFromStun(t: var): bool {
        for (const pace of list) {
            if (pace.def.role !== "support" || !stats(pace).cleanse)
                continue;
            if (Math.hypot(t.x - pace.x, t.y - pace.y) <= stats(pace).range)
                return true;
        }
        return false;
    }

    // Returns how many cars it actually caught, so the announcement can name a
    // number instead of a vague "your cars".
    function stunArea(x: real, y: real, radius: real, seconds: real): int {
        let caught = 0;
        for (const t of list) {
            if (Math.hypot(t.x - x, t.y - y) > radius)
                continue;
            if (shieldedFromStun(t))
                continue;
            t.stunTimer = Math.max(t.stunTimer, seconds);
            // Remembered so the view can drain a ring rather than just sit
            // there marked: "how much longer" is the thing a player wants.
            t.stunMax = Math.max(t.stunMax || 0, t.stunTimer);
            caught += 1;
            if (t.view) {
                t.view.stunned = true;
                t.view.stunFraction = 1;
            }
        }
        recountStunned();
        return caught;
    }

    function recountStunned(): void {
        let n = 0;
        for (const t of list) {
            if (t.stunTimer > 0)
                n += 1;
        }
        stunnedCount = n;
    }

    // Paid out by Service Barges at the end of each wave.
    function waveIncome(): int {
        let total = 0;
        for (const t of list) {
            if (t.def.role === "economy")
                total += stats(t).income || 0;
        }
        return total;
    }

    // ---- per-frame ---------------------------------------------------------
    function update(dt: real): void {
        for (const t of list) {
            if (t.stunTimer > 0) {
                t.stunTimer -= dt;
                if (t.stunTimer <= 0 || shieldedFromStun(t)) {
                    t.stunTimer = 0;
                    t.stunMax = 0;
                    if (t.view) {
                        t.view.stunned = false;
                        t.view.stunFraction = 0;
                    }
                    recountStunned();
                } else if (t.view) {
                    t.view.stunFraction = t.stunMax > 0
                        ? Math.max(0, t.stunTimer / t.stunMax) : 0;
                }
                continue;
            }

            if (t.def.role === "support") {
                t.pulse -= dt;
                if (t.pulse <= 0) {
                    t.pulse = 1.1;
                    if (t.view)
                        t.view.pulse();
                }
                continue;
            }
            if (t.def.role === "economy")
                continue;

            const s = stats(t);
            const range = effRange(t);
            const detect = canDetect(t);

            if (t.cooldown > 0)
                t.cooldown -= dt;

            const target = enemies ? enemies.pickTarget(t.x, t.y, range, detect, t.targetMode) : null;
            if (!target)
                continue;

            // Aim: turn toward the target rather than snapping to it.
            const want = Math.atan2(target.y - t.y, target.x - t.x) * 180 / Math.PI;
            let delta = ((want - t.heading + 540) % 360) - 180;
            const maxTurn = t.def.turnRate * dt;
            if (Math.abs(delta) <= maxTurn)
                t.heading = want;
            else
                t.heading += Math.sign(delta) * maxTurn;
            if (t.view)
                t.view.heading = t.heading;

            const aimed = Math.abs(delta) < 12 || t.def.turnRate >= 999;
            if (t.cooldown <= 0 && aimed) {
                t.cooldown = 1 / effRate(t);
                fire(t, target, range, detect);
            }
        }
    }

    function muzzle(t: var): var {
        const off = t.def.weapon === "laseretch" ? 54 : 38;
        const rad = t.heading * Math.PI / 180;
        return { x: t.x + Math.cos(rad) * off, y: t.y + Math.sin(rad) * off };
    }

    function hueOf(t: var): color {
        return Theme[t.def.hue] || Theme.accent;
    }

    // Beams and singularities resolve their damage here rather than through a
    // projectile, so this is where they get put on the scoreboard.
    function credit(t: var, dealt: real): void {
        if (!(dealt > 0))
            return;
        t.damageDealt += dealt;
        if (ledger)
            ledger.addDamage(t.defId, dealt);
    }

    function fire(t: var, target: var, range: real, detect: bool): void {
        const s = stats(t);
        const color = hueOf(t);
        if (t.view)
            t.view.fire();

        const m = muzzle(t);

        switch (t.def.weapon) {
        case "binarypath":
            projectiles.launch({
                kind: "homing", x: m.x, y: m.y, target: target, tx: target.x, ty: target.y,
                speed: 660, dmg: s.dmg, dmgType: t.def.dmgType, slow: s.slow,
                maxTargets: 1, color: color, weapon: "binarypath", srcId: t.defId
            });
            break;

        case "matrix": {
            const targets = enemies.pickTargets(t.x, t.y, range, detect, t.targetMode, s.maxTargets);
            for (const e of targets) {
                projectiles.launch({
                    kind: "homing", x: m.x, y: m.y, target: e, tx: e.x, ty: e.y,
                    speed: 1050, dmg: s.dmg, dmgType: t.def.dmgType, slow: s.slow,
                    maxTargets: 1, color: color, weapon: "matrix", srcId: t.defId
                });
            }
            break;
        }

        case "laseretch": {
            // Etch a line: everything in a narrow corridor takes the hit.
            const rad = t.heading * Math.PI / 180;
            const dirX = Math.cos(rad);
            const dirY = Math.sin(rad);
            const candidates = enemies.inRange(t.x, t.y, range, detect);
            const along = [];
            for (const e of candidates) {
                const rx = e.x - t.x;
                const ry = e.y - t.y;
                const proj = rx * dirX + ry * dirY;
                if (proj <= 0)
                    continue;
                const perp = Math.abs(rx * dirY - ry * dirX);
                if (perp <= 24 + e.def.radius * 0.5)
                    along.push({ e: e, proj: proj });
            }
            along.sort((a, b) => a.proj - b.proj);

            // The beam attenuates as it punches through: the first take in the
            // queue eats the full etch, everything behind it progressively
            // less. Without this a single car clears the whole convoy, because
            // the convoy is always conveniently in a straight line.
            const hits = along.slice(0, s.maxTargets);
            for (let i = 0; i < hits.length; i++)
                credit(t, enemies.damage(hits[i].e, s.dmg * Balance.beamShare(i), t.def.dmgType));

            // Stop the beam just past the last thing it cut through.
            const endDist = hits.length === 0
                ? range
                : Math.min(range, hits[hits.length - 1].proj + 40);

            fx.beam(m.x, m.y, t.x + dirX * endDist, t.y + dirY * endDist, color, 5);
            break;
        }

        case "fireworks": {
            // Lead the target so the shell and the take arrive together.
            const flightGuess = Math.hypot(target.x - m.x, target.y - m.y) / 560;
            const lead = Balance.pointAt(target.dist + target.baseSpeed * (1 - target.slowFactor) * flightGuess);
            projectiles.launch({
                kind: "shell", x: m.x, y: m.y, target: null, tx: lead.x, ty: lead.y,
                speed: 560, dmg: s.dmg, dmgType: t.def.dmgType, splash: s.splash,
                slow: s.slow, maxTargets: s.maxTargets, color: color, weapon: "fireworks",
                srcId: t.defId
            });
            break;
        }

        case "blackhole": {
            const caught = enemies.inRange(t.x, t.y, s.splash, true);
            for (const e of caught) {
                credit(t, enemies.damage(e, s.dmg, t.def.dmgType));
                enemies.applySlow(e, s.slow, 0.9);
            }
            fx.vortex(t.x, t.y, s.splash, color, 9);
            break;
        }
        }
    }
}
