pragma ComponentBehavior: Bound

import QtQuick

// The run's ledger. Every manager that resolves damage or a death writes here,
// and only the end-of-run summary reads it back.
//
// It is a separate object rather than fields on the managers because a car's
// contribution has to outlive the car: retire a Quattro on wave 12 and the
// damage it dealt is still part of the story of the run. Tallying by definition
// id rather than by instance is what makes that work.
QtObject {
    id: stats

    // defId -> total damage actually dealt (after resistances and armour).
    property var damageByTower: ({})
    // enemy id -> number killed.
    property var killsByEnemy: ({})
    // defId -> true for every car parked at any point in the run, so the
    // summary can list a Service Barge that never fired a shot rather than
    // silently dropping it for having dealt no damage.
    property var used: ({})

    // Plain JS objects cannot notify a binding, so the summary reads this
    // instead. It is bumped once per wave-cleared rather than per hit — the
    // panel only ever renders after the run is over.
    property int revision: 0

    function reset(): void {
        damageByTower = ({});
        killsByEnemy = ({});
        used = ({});
        revision += 1;
    }

    function addUse(defId: string): void {
        if (defId)
            used[defId] = true;
    }

    function addDamage(defId: string, amount: real): void {
        if (!defId || !(amount > 0))
            return;
        damageByTower[defId] = (damageByTower[defId] || 0) + amount;
    }

    function addKill(enemyId: string): void {
        if (!enemyId)
            return;
        killsByEnemy[enemyId] = (killsByEnemy[enemyId] || 0) + 1;
    }

    function seal(): void {
        revision += 1;
    }

    // ---- readback ----------------------------------------------------------
    // Sorted, biggest first, with the share each one carries so the summary can
    // draw a bar without doing arithmetic in a binding.
    function damageTable(): var {
        const rows = [];
        let top = 0;
        for (const def of Balance.towers) {
            const amount = Math.round(damageByTower[def.id] || 0);
            if (amount <= 0 && !used[def.id])
                continue;
            rows.push({ id: def.id, def: def, amount: amount });
            top = Math.max(top, amount);
        }
        rows.sort((a, b) => b.amount - a.amount);
        for (const r of rows)
            r.share = top > 0 ? r.amount / top : 0;
        return rows;
    }

    function killTable(): var {
        const rows = [];
        for (const def of Balance.enemies) {
            const n = killsByEnemy[def.id] || 0;
            if (n <= 0)
                continue;
            rows.push({ id: def.id, def: def, count: n });
        }
        // Bosses first — they are the ones worth bragging about — then by count.
        rows.sort((a, b) => {
            const ab = a.def.traits.indexOf("boss") >= 0 ? 1 : 0;
            const bb = b.def.traits.indexOf("boss") >= 0 ? 1 : 0;
            if (ab !== bb)
                return bb - ab;
            return b.count - a.count;
        });
        return rows;
    }

    function totalDamage(): real {
        let total = 0;
        for (const k in damageByTower)
            total += damageByTower[k];
        return total;
    }
}
