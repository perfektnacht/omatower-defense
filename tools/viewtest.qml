import QtQuick
import Quickshell
import "game"

// Mounts real views against the EnemyManager and checks the two things the
// headless suite cannot see: that every live entity has exactly one view (no
// orphans), and that a view actually reflects damage.
ShellRoot {
    FloatingWindow {
        implicitWidth: 400; implicitHeight: 200; color: Theme.bg
        Item { id: layerHost; anchors.fill: parent }
    }

    Component { id: chipComp; EnemyChip {} }

    EnemyManager {
        id: em
        layer: layerHost
        viewComponent: chipComp
    }

    property int fails: 0

    function check(name, cond, detail) {
        console.log((cond ? "  PASS  " : "  FAIL  ") + name + (detail ? "   [" + detail + "]" : ""));
        if (!cond) fails += 1;
        return cond;
    }

    function step(seconds) {
        const dt = 1 / 30;
        for (let i = 0; i < Math.ceil(seconds / dt); i++)
            em.update(dt);
    }

    Component.onCompleted: {
        console.log("=== views vs entities ===");
        Balance.selectCircuit(0);
        em.reset();

        // THE-DISCOURSE summons free hype while the update loop is running.
        em.spawn("discourse", {});
        check("boss mounted a view", layerHost.children.length === 1,
              "views=" + layerHost.children.length);

        // Long enough for two summon pulses; nothing dies or leaks in this window.
        step(9);

        const hype = em.list.filter(e => e.def.id === "hype");
        check("summoned minions stay in the entity list", hype.length > 0,
              "hype=" + hype.length);
        check("no orphaned views left on the board",
              layerHost.children.length === em.list.length,
              "views=" + layerHost.children.length + " entities=" + em.list.length);

        console.log("=== health bars ===");
        const victim = hype.length > 0 ? hype[0] : em.list[0];
        const before = victim.view.hpFraction;
        // The view must share the entity object, not a copy of it.
        check("view shares the entity object", victim.view.enemy === victim);
        em.damage(victim, victim.hpMax * 0.5, "beam");
        check("view drops after damage", victim.view.hpFraction < before - 0.3,
              before.toFixed(2) + " -> " + victim.view.hpFraction.toFixed(2));

        em.update(1 / 30);
        check("and stays dropped on the next frame", victim.view.hpFraction < 0.7,
              victim.view.hpFraction.toFixed(2));

        em.reset();
        sweepTimer.start();
    }

    Timer {
        id: sweepTimer
        interval: 250
        onTriggered: {
            // destroy() is deferred, so the sweep is checked a beat later.
            check("reset clears every view", layerHost.children.length === 0,
                  "views=" + layerHost.children.length);
            console.log(fails === 0 ? "=== ALL CHECKS PASSED ==="
                                    : "=== " + fails + " CHECK(S) FAILED ===");
        }
    }
}
