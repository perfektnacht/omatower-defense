import QtQuick
import qs.Ui

// A car in the bar. Click it to drop into the game; click it again to pause
// the run and put it away.
BarWidget {
    id: root
    moduleName: "perfektnacht.omatower-defense"

    readonly property string pluginId: "perfektnacht.omatower-defense"

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰄋"
        tooltipText: "Omatower Defense"
        onPressed: function (b) {
            if (root.bar && root.bar.shell && typeof root.bar.shell.toggle === "function")
                root.bar.shell.toggle(root.pluginId, "{}");
            else if (root.bar)
                root.bar.run("omarchy-shell shell toggle " + root.pluginId);
        }
    }
}
