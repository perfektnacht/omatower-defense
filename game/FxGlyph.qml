import QtQuick

// One pooled screensaver glyph. The manager owns its motion.
Text {
    property real vx: 0
    property real vy: 0
    property real drag: 1.4
    property real life: 0
    property real maxLife: 1
    property real spin: 0

    font.family: Theme.mono
    font.pixelSize: 15
    font.bold: true
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    transformOrigin: Item.Center
    antialiasing: true
}
