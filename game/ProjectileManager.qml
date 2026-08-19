pragma ComponentBehavior: Bound

import QtQuick

// Flight and impact of everything the cars throw. Damage resolution is
// delegated back to the EnemyManager so the rules live in exactly one place.
QtObject {
    id: mgr

    property Item layer: null
    property Component viewComponent: null
    property EnemyManager enemies: null
    property Fx fx: null
    property Stats ledger: null

    property var list: []
    property int budget: 220

    function reset(): void {
        for (const p of list) {
            if (p.view)
                p.view.destroy();
        }
        list = [];
    }

    // shot: { kind, x, y, target, tx, ty, speed, dmg, dmgType, splash, slow,
    //         maxTargets, color, weapon, srcId }
    //
    // `srcId` is the definition id of the car that fired, carried along so the
    // end-of-run summary can credit the damage even after that car has been
    // retired and its instance is long gone.
    function launch(shot: var): void {
        if (list.length >= budget)
            return;

        const p = {
            kind: shot.kind,
            x: shot.x,
            y: shot.y,
            target: shot.target || null,
            tx: shot.tx,
            ty: shot.ty,
            speed: shot.speed,
            dmg: shot.dmg,
            dmgType: shot.dmgType,
            splash: shot.splash || 0,
            slow: shot.slow || 0,
            maxTargets: shot.maxTargets || 1,
            color: shot.color,
            weapon: shot.weapon,
            srcId: shot.srcId || "",
            life: 3.0,
            trailTimer: 0,
            angle: 0,
            view: null
        };

        if (layer && viewComponent) {
            p.view = viewComponent.createObject(layer, {
                x: p.x,
                y: p.y,
                shotColor: p.color,
                weapon: p.weapon
            });
        }
        list.push(p);
    }

    function update(dt: real): void {
        const alive = [];

        for (const p of list) {
            p.life -= dt;
            if (p.life <= 0) {
                destroyShot(p);
                continue;
            }

            // Homing rounds re-aim at a live target; shells commit to a point.
            let goalX = p.tx;
            let goalY = p.ty;
            if (p.kind === "homing" && p.target && p.target.alive) {
                goalX = p.target.x;
                goalY = p.target.y;
            }

            const dx = goalX - p.x;
            const dy = goalY - p.y;
            const dist = Math.hypot(dx, dy);
            const step = p.speed * dt;

            if (dist <= step || dist < 6) {
                p.x = goalX;
                p.y = goalY;
                impact(p);
                destroyShot(p);
                continue;
            }

            p.x += dx / dist * step;
            p.y += dy / dist * step;
            p.angle = Math.atan2(dy, dx) * 180 / Math.PI;

            // Binary trailing off the back of the round.
            p.trailTimer -= dt;
            if (p.trailTimer <= 0 && fx) {
                p.trailTimer = 0.022;
                fx.trail(p.x, p.y, p.color, p.weapon, p.kind === "shell" ? 15 : 13);
            }

            if (p.view) {
                p.view.x = p.x;
                p.view.y = p.y;
                p.view.rotation = p.angle;
            }
            alive.push(p);
        }

        list = alive;
    }

    function impact(p: var): void {
        if (!enemies)
            return;

        if (p.splash > 0) {
            // Blast: everything inside the radius, up to the shell's cap.
            const hits = enemies.inRange(p.x, p.y, p.splash, true);
            let n = 0;
            for (const e of hits) {
                if (n++ >= p.maxTargets)
                    break;
                const falloff = 1 - 0.45 * (Math.hypot(e.x - p.x, e.y - p.y) / p.splash);
                const dealt = enemies.damage(e, p.dmg * falloff, p.dmgType);
                if (ledger)
                    ledger.addDamage(p.srcId, dealt);
                if (p.slow > 0)
                    enemies.applySlow(e, p.slow, 1.4);
            }
            if (fx) {
                fx.burst(p.x, p.y, 16, p.color, p.splash * 2.4, p.weapon, 17);
                fx.burst(p.x, p.y, 8, Qt.lighter(p.color, 1.5), p.splash * 1.2, p.weapon, 13);
            }
        } else if (p.target && p.target.alive) {
            const dealt = enemies.damage(p.target, p.dmg, p.dmgType);
            if (ledger)
                ledger.addDamage(p.srcId, dealt);
            if (p.slow > 0)
                enemies.applySlow(p.target, p.slow, 1.2);
            if (fx)
                fx.burst(p.x, p.y, 6, p.color, 130, p.weapon, 13);
        } else if (fx) {
            fx.burst(p.x, p.y, 3, p.color, 90, p.weapon, 12);
        }
    }

    function destroyShot(p: var): void {
        if (p.view) {
            p.view.destroy();
            p.view = null;
        }
    }
}
