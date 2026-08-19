import QtQuick
import Quickshell
import "game"

ShellRoot {
    FloatingWindow {
        implicitWidth: 1500; implicitHeight: 900; color: Theme.bg
        Game { id: game; anchors.fill: parent }

        Timer {
            running: true; interval: 1200
            onTriggered: {
                const sim = game.sim;
                console.log("before: started=" + sim.started + " phase=" + sim.phase);
                // exactly what the START button's onClicked does
                Balance.selectCircuit(2);
                sim.newRun("classic");
                console.log("after:  started=" + sim.started
                            + " circuit=" + Balance.circuit.name
                            + " cash=" + sim.cash
                            + " shop=" + sim.availableTowers.length
                            + " bays=" + Balance.slots.length);
            }
        }
        Timer {
            running: true; interval: 3000
            onTriggered: {
                const sim = game.sim;
                console.log("later:  started=" + sim.started
                            + " phase=" + sim.phase
                            + " planTimer=" + Math.round(sim.waves.planTimer)
                            + " enemies=" + sim.enemies.aliveCount());
            }
        }
    }
}
