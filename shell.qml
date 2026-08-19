//@ pragma UseQApplication

import QtQuick
import Quickshell
import "game"

// Standalone entry point: `qs -p .` from the repo root.
// Inside Omarchy the same game is hosted by Panel.qml as a shell plugin.
ShellRoot {
    FloatingWindow {
        title: "Omatower Defense"
        implicitWidth: 1720
        implicitHeight: 1000
        minimumSize: Qt.size(1180, 760)
        color: Theme.bg

        Game {
            anchors.fill: parent
            focus: true
        }
    }
}
