import QtQuick

// Transient run commentary: waves called, bosses retracted, takes that landed.
Item {
    id: ticker

    property string message: ""
    property string kind: "info"

    readonly property color hue: kind === "bad" ? Theme.red
                               : kind === "good" ? Theme.green
                               : kind === "boss" ? Theme.brightMagenta
                               : Theme.accent

    width: pill.width
    height: pill.height
    opacity: 0
    z: 150

    Rectangle {
        id: pill
        width: label.implicitWidth + 34
        height: 34
        radius: height / 2
        color: Theme.alpha(Theme.bgPanel, 0.96)
        border.width: 1
        border.color: Theme.alpha(ticker.hue, 0.65)

        Rectangle {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: ticker.hue
        }

        Text {
            id: label
            x: 26
            anchors.verticalCenter: parent.verticalCenter
            text: ticker.message
            font.family: Theme.mono
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 0.6
            color: Theme.fgBright
        }
    }

    SequentialAnimation {
        id: anim
        running: false
        NumberAnimation { target: ticker; property: "opacity"; to: 1; duration: 120 }
        NumberAnimation { target: ticker; property: "y"; from: ticker.y - 6; to: ticker.y; duration: 160
                          easing.type: Easing.OutCubic }
        PauseAnimation { duration: 1700 }
        NumberAnimation { target: ticker; property: "opacity"; to: 0; duration: 380 }
    }

    function show(text: string, k: string): void {
        message = text;
        kind = k || "info";
        anim.restart();
    }
}
