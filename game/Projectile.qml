import QtQuick

// The round itself: a bright glyph head. Its tail is drawn by the Fx pool.
Item {
    id: shot

    property color shotColor: Theme.accent
    property string weapon: "binarypath"

    width: 0
    height: 0

    Rectangle {
        anchors.centerIn: parent
        width: shot.weapon === "fireworks" ? 15 : 9
        height: width
        radius: width / 2
        color: Qt.lighter(shot.shotColor, 1.7)
    }

    Rectangle {
        anchors.centerIn: parent
        width: shot.weapon === "fireworks" ? 30 : 20
        height: width
        radius: width / 2
        color: Theme.alpha(shot.shotColor, 0.25)
    }

    Text {
        anchors.centerIn: parent
        rotation: -shot.rotation
        text: shot.weapon === "binarypath" ? "1" : ""
        visible: text !== ""
        font.family: Theme.mono
        font.pixelSize: 12
        font.bold: true
        color: Qt.darker(shot.shotColor, 2.2)
    }
}
