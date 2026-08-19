pragma ComponentBehavior: Bound

import QtQuick

// Owns the lifecycle of every hostile take on the board. Knows nothing about
// how they are drawn: if `layer` is null it runs perfectly well headless, which
// is what makes the balance testable.
QtObject {
    id: mgr

    property Item layer: null
    property Component viewComponent: null
    property Stats ledger: null

    property var list: []
    property int nextUid: 1

    // Damage/health multiplier applied to everything spawned this wave.
    property real hpScale: 1.0
    // Payout multiplier for this wave. Set by the WaveManager from
    // Balance.incomeScale so bounties fall behind the threat curve.
    property real bountyScale: 1.0

    signal leaked(var enemy)
    signal killed(var enemy, int bounty)
    signal stunRequested(real x, real y, real radius, real seconds)

    function reset(): void {
        for (const e of list) {
            if (e.view)
                e.view.destroy();
        }
        // Nothing should outlive the list, but a stray view would otherwise sit
        // on the board forever, so the layer is swept too.
        if (layer) {
            for (const child of layer.children)
                child.destroy();
        }
        list = [];
        nextUid = 1;
        hpScale = 1.0;
        bountyScale = 1.0;
    }

    function spawn(defId: string, opts: var): var {
        const def = Balance.enemy(defId);
        if (!def)
            return null;
        const o = opts || {};
        const scale = o.hpScale !== undefined ? o.hpScale : mgr.hpScale;
        const boss = def.traits.indexOf("boss") >= 0;

        const e = {
            uid: mgr.nextUid++,
            def: def,
            hpMax: def.hp * scale,
            hp: def.hp * scale,
            armor: def.armor * (1 + (scale - 1) * 0.5),
            shieldMax: (def.shield || 0) * scale,
            shield: (def.shield || 0) * scale,
            shieldTimer: 0,
            baseSpeed: def.speed,
            dist: o.dist !== undefined ? o.dist : 0,
            bounty: o.noCash ? 0 : Math.max(1, Math.round(def.bounty * mgr.bountyScale)),
            noCash: !!o.noCash,
            stealth: def.traits.indexOf("stealth") >= 0,
            slowproof: def.traits.indexOf("slowproof") >= 0,
            boss: boss,
            slowFactor: 0,
            slowTimer: 0,
            haste: 0,
            summonTimer: 0,
            stunTimer: def.stunEvery ? def.stunEvery * 0.6 : 0,
            hitFlash: 0,
            x: 0,
            y: 0,
            angle: 0,
            alive: true,
            view: null
        };

        const p = Balance.pointAt(e.dist);
        e.x = p.x;
        e.y = p.y;
        e.angle = p.angle;

        if (layer && viewComponent) {
            e.view = viewComponent.createObject(layer, { x: e.x, y: e.y });
            // `enemy` must be assigned after construction. Passing a plain JS
            // object through createObject's initial-properties map converts it
            // to a QVariantMap, so the view would hold a frozen copy taken at
            // spawn time and its health bar would never move.
            if (e.view)
                e.view.enemy = e;
        }

        list.push(e);
        return e;
    }

    function update(dt: real): void {
        const survivors = [];
        // `list` is the live array, and spawn() appends to it. Summoning bosses
        // therefore add entries *while this loop runs*, so the length is snapshot
        // here and the newcomers are folded back in at the end. Overwriting the
        // list with `survivors` alone would drop them while leaving their views
        // mounted: frozen sprites that never move, take damage, or despawn.
        const len = list.length;

        for (let i = 0; i < len; i++) {
            const e = list[i];
            if (!e.alive)
                continue;

            // --- haste aura from any RAGE-BAIT style buffer on the board ----
            e.haste = 0;
            for (let j = 0; j < len; j++) {
                const b = list[j];
                if (!b.alive || b === e || !b.def.hasteRadius)
                    continue;
                if (Math.hypot(b.x - e.x, b.y - e.y) <= b.def.hasteRadius)
                    e.haste = Math.max(e.haste, b.def.hasteAmount);
            }

            // --- slow decay -------------------------------------------------
            if (e.slowTimer > 0) {
                e.slowTimer -= dt;
                if (e.slowTimer <= 0)
                    e.slowFactor = 0;
            }
            if (e.hitFlash > 0)
                e.hitFlash = Math.max(0, e.hitFlash - dt);

            // --- regeneration ------------------------------------------------
            if (e.def.regen && e.hp < e.hpMax)
                e.hp = Math.min(e.hpMax, e.hp + e.def.regen * dt);

            // --- shield recharge ---------------------------------------------
            if (e.shieldMax > 0 && e.shield < e.shieldMax) {
                e.shieldTimer += dt;
                if (e.shieldTimer >= (e.def.shieldDelay || 3))
                    e.shield = Math.min(e.shieldMax, e.shield + (e.def.shieldRegen || 30) * dt);
            }

            // --- tower stun pulse ---------------------------------------------
            if (e.def.stunEvery) {
                e.stunTimer -= dt;
                if (e.stunTimer <= 0) {
                    e.stunTimer = e.def.stunEvery;
                    mgr.stunRequested(e.x, e.y, e.def.stunRadius, e.def.stunSeconds);
                }
            }

            // --- summoning (free minions, no bounty) --------------------------
            if (e.def.summonEvery) {
                e.summonTimer -= dt;
                if (e.summonTimer <= 0) {
                    e.summonTimer = e.def.summonEvery;
                    for (let k = 0; k < (e.def.summonCount || 1); k++)
                        mgr.spawn(e.def.summonInto, { noCash: true, dist: Math.max(0, e.dist - 30 - k * 22) });
                }
            }

            // --- movement ------------------------------------------------------
            const slow = e.slowproof ? 0 : e.slowFactor;
            const speed = e.baseSpeed * (1 - slow) * (1 + e.haste);
            e.dist += speed * dt;

            if (e.dist >= Balance.trackLength) {
                e.alive = false;
                mgr.leaked(e);
                despawn(e);
                continue;
            }

            const p = Balance.pointAt(e.dist);
            e.x = p.x;
            e.y = p.y;
            e.angle = p.angle;

            if (e.view) {
                e.view.x = e.x;
                e.view.y = e.y;
                e.view.sync();
            }
            survivors.push(e);
        }

        const latecomers = list.length > len ? list.slice(len) : [];
        list = latecomers.length > 0 ? survivors.concat(latecomers) : survivors;
    }

    // Returns damage actually dealt, after resistance, armour and shields.
    function damage(e: var, amount: real, type: string): real {
        if (!e.alive)
            return 0;

        const resist = (e.def.resist && e.def.resist[type] !== undefined) ? e.def.resist[type] : 0;
        if (resist >= 1)
            return 0;

        let dmg = amount * (1 - resist);

        // BEAM cuts straight through armour; everything else is mitigated.
        if (type !== "beam")
            dmg = Math.max(1, dmg - e.armor);

        if (e.shield > 0) {
            const absorbed = Math.min(e.shield, dmg);
            e.shield -= absorbed;
            dmg -= absorbed;
            e.shieldTimer = 0;
        }

        e.hp -= dmg;
        e.hitFlash = 0.12;

        if (e.hp <= 0)
            kill(e);
        else if (e.view)
            e.view.sync();

        return dmg;
    }

    function applySlow(e: var, factor: real, seconds: real): void {
        if (e.slowproof || factor <= 0)
            return;
        if (factor >= e.slowFactor) {
            e.slowFactor = factor;
            e.slowTimer = Math.max(e.slowTimer, seconds);
        }
    }

    function kill(e: var): void {
        if (!e.alive)
            return;
        e.alive = false;

        // Splitters leave halves behind that pay nothing: the "No Cash" trap.
        if (e.def.traits.indexOf("split") >= 0 && e.def.splitInto) {
            for (let i = 0; i < (e.def.splitCount || 2); i++) {
                mgr.spawn(e.def.splitInto, {
                    noCash: true,
                    dist: Math.max(0, e.dist - 18 - i * 26),
                    hpScale: mgr.hpScale
                });
            }
        }

        if (ledger)
            ledger.addKill(e.def.id);

        mgr.killed(e, e.bounty);
        despawn(e);
    }

    function despawn(e: var): void {
        if (e.view) {
            e.view.destroy();
            e.view = null;
        }
    }

    // ---- queries used by the towers ---------------------------------------
    function inRange(x: real, y: real, range: real, canDetect: bool): var {
        const out = [];
        const r2 = range * range;
        for (const e of list) {
            if (!e.alive)
                continue;
            if (e.stealth && !canDetect)
                continue;
            const dx = e.x - x;
            const dy = e.y - y;
            if (dx * dx + dy * dy <= r2)
                out.push(e);
        }
        return out;
    }

    // Targeting priority: this is the hardcore/casual dividing line.
    function pickTarget(x: real, y: real, range: real, canDetect: bool, mode: string): var {
        const candidates = inRange(x, y, range, canDetect);
        if (candidates.length === 0)
            return null;

        let best = candidates[0];
        for (const e of candidates) {
            switch (mode) {
            case "last":
                if (e.dist < best.dist) best = e;
                break;
            case "strong":
                if (e.hp + e.shield > best.hp + best.shield) best = e;
                break;
            case "close":
                if (Math.hypot(e.x - x, e.y - y) < Math.hypot(best.x - x, best.y - y)) best = e;
                break;
            default: // "first"
                if (e.dist > best.dist) best = e;
                break;
            }
        }
        return best;
    }

    // Same priority rules, but returns up to `count` targets for multi-shot cars.
    function pickTargets(x: real, y: real, range: real, canDetect: bool, mode: string, count: int): var {
        const candidates = inRange(x, y, range, canDetect);
        if (candidates.length <= 1)
            return candidates;

        const score = e => {
            switch (mode) {
            case "last":   return -e.dist;
            case "strong": return e.hp + e.shield;
            case "close":  return -Math.hypot(e.x - x, e.y - y);
            default:       return e.dist;
            }
        };
        candidates.sort((a, b) => score(b) - score(a));
        return candidates.slice(0, count);
    }

    function aliveCount(): int {
        return list.length;
    }
}
