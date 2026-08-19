import QtQuick

// Small floating explainer used by the shop and the inspector.
Rectangle {
    id: tip

    property string heading: ""
    property string body: ""

    width: 268
    height: col.implicitHeight + 20
    radius: Theme.radius
    color: Theme.alpha(Theme.bg, 0.97)
    border.width: 1
    border.color: Theme.alpha(Theme.fg, 0.16)
    z: 200

    Column {
        id: col
        x: 12
        y: 10
        width: parent.width - 24
        spacing: 4

        Text {
            width: parent.width
            text: tip.heading
            font.family: Theme.mono
            font.pixelSize: 12
            font.bold: true
            color: Theme.fgBright
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            text: tip.body
            font.family: Theme.mono
            font.pixelSize: 11
            lineHeight: 1.3
            color: Theme.fgDim
            wrapMode: Text.WordWrap
        }
    }
}
