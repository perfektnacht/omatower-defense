import QtQuick
import Quickshell
import "game"

ShellRoot {
    FloatingWindow {
        implicitWidth: 1800; implicitHeight: 1100; color: Theme.bg
        Item {
            id: scene
            width: 1800; height: 1100
            Rectangle { anchors.fill: parent; color: Theme.bgPanel }

            Column {
                anchors.centerIn: parent
                spacing: 26

                Text {
                    text: "QUATTROS"
                    font.family: Theme.mono; font.pixelSize: 13; font.letterSpacing: 3
                    color: Theme.fgDim
                }
                Row {
                    spacing: 18
                    Repeater {
                        model: Balance.towers
                        Column {
                            spacing: 6
                            Item {
                                width: 150; height: 100
                                Quattro {
                                    anchors.centerIn: parent
                                    def: modelData
                                    level: index % 3
                                    heading: 0
                                    range: 0
                                    scale: 1.25
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.name
                                font.family: Theme.mono; font.pixelSize: 10
                                color: Theme[modelData.hue] || Theme.fg
                            }
                        }
                    }
                }

                Text {
                    text: "THE TAKES"
                    font.family: Theme.mono; font.pixelSize: 13; font.letterSpacing: 3
                    color: Theme.fgDim
                }
                Grid {
                    columns: 9
                    spacing: 16
                    Repeater {
                        model: Balance.enemies
                        Column {
                            spacing: 4
                            Item {
                                width: 150; height: 108
                                Creature {
                                    anchors.centerIn: parent
                                    spec: modelData.sprite
                                    hue: Theme[modelData.hue] || Theme.fg
                                    bodySize: modelData.traits.indexOf("boss") >= 0 ? 92 : 68
                                    spooky: modelData.traits.indexOf("stealth") >= 0
                                }
                            }
                            Text {
                                width: 150
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.label
                                font.family: Theme.mono; font.pixelSize: 10
                                color: Theme[modelData.hue] || Theme.fg
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Timer { running: true; interval: 1800
                    onTriggered: scene.grabToImage(r => r.saveToFile(Quickshell.env("SHOT")),
                                                   Qt.size(scene.width, scene.height)) }
        }
    }
}
