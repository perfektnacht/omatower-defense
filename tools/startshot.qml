import QtQuick
import Quickshell
import "game"
ShellRoot {
    FloatingWindow {
        implicitWidth: 1720; implicitHeight: 1000; color: Theme.bg
        Item {
            id: scene
            width: 1720; height: 1000
            Rectangle { anchors.fill: parent; color: Theme.bg }
            Game { anchors.fill: parent; showClose: true }
            Timer { running: true; interval: 2000
                    onTriggered: scene.grabToImage(r => r.saveToFile(Quickshell.env("SHOT")),
                                                   Qt.size(scene.width, scene.height)) }
        }
    }
}
