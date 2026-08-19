import QtQuick

// One bad take, embodied. Positioned by its centre so the manager just assigns
// x/y. The monster carries the read at a glance; the label underneath carries
// the joke.
Item {
    id: chip

    property var enemy: null
    readonly property var def: enemy ? enemy.def : null
    readonly property bool boss: enemy ? enemy.boss : false

    property real hpFraction: 1
    property real shieldFraction: 0
    property real flash: 0
    property bool slowed: false

    readonly property color hue: def ? (Theme[def.hue] || Theme.fg) : Theme.fg
    readonly property real sprite: def ? def.radius * 2.3 : 40

    width: 0
    height: 0
    z: boss ? 5 : 1

    // Bosses get a floor glow so they never get lost in a crowd.
    Rectangle {
        visible: chip.boss
        anchors.centerIn: parent
        width: chip.sprite * 2.4
        height: width
        radius: width / 2
        color: Theme.alpha(chip.hue, 0.12)
    }

    Column {
        anchors.centerIn: parent
        spacing: 2

        // ---- the monster ----------------------------------------------------
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: chip.sprite
            height: chip.sprite

            // shield shell
            Rectangle {
                visible: chip.shieldFraction > 0
                anchors.centerIn: parent
                width: parent.width * 1.25
                height: width
                radius: width / 2
                color: Theme.alpha(Theme.brightBlue, 0.08)
                border.width: 2
                border.color: Theme.alpha(Theme.brightBlue, 0.3 + 0.55 * chip.shieldFraction)
            }

            Creature {
                anchors.fill: parent
                spec: chip.def ? chip.def.sprite : ({})
                hue: chip.hue
                bodySize: chip.sprite
                spooky: chip.enemy ? chip.enemy.stealth : false
            }

            // impact flash
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.05
                height: width
                radius: width / 2
                color: Theme.fgBright
                opacity: chip.flash
            }

            // slowed marker
            Text {
                visible: chip.slowed
                anchors.left: parent.right
                anchors.leftMargin: 1
                anchors.verticalCenter: parent.verticalCenter
                text: "❄"
                font.family: Theme.mono
                font.pixelSize: 13
                color: Theme.brightCyan
            }

            // stealth marker
            Text {
                visible: chip.enemy ? chip.enemy.stealth : false
                anchors.right: parent.left
                anchors.rightMargin: 1
                anchors.verticalCenter: parent.verticalCenter
                text: "◈"
                font.family: Theme.mono
                font.pixelSize: 12
                color: Theme.alpha(Theme.fgBright, 0.8)
            }
        }

        // ---- health ----------------------------------------------------------
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(chip.sprite * 0.9, label.implicitWidth * 0.85)
            height: chip.boss ? 6 : 4
            radius: height / 2
            color: Theme.alpha(Theme.bg, 0.9)
            border.width: 1
            border.color: Theme.alpha(chip.hue, 0.45)

            Rectangle {
                x: 1
                y: 1
                width: (parent.width - 2) * chip.hpFraction
                height: parent.height - 2
                radius: height / 2
                color: chip.hpFraction > 0.55 ? Theme.green
                     : chip.hpFraction > 0.25 ? Theme.yellow
                     : Theme.red
            }
        }

        // ---- the take ---------------------------------------------------------
        Text {
            id: label
            anchors.horizontalCenter: parent.horizontalCenter
            text: chip.def ? chip.def.label : ""
            font.family: Theme.mono
            font.pixelSize: chip.boss ? 13 : 9
            font.bold: chip.boss
            font.letterSpacing: chip.boss ? 1 : 0
            color: chip.boss ? Theme.fgBright : Theme.alpha(Theme.fgDim, 0.95)
            style: Text.Outline
            styleColor: Theme.alpha(Theme.bg, 0.85)
        }
    }

    function sync(): void {
        if (!enemy)
            return;
        hpFraction = Math.max(0, enemy.hp / enemy.hpMax);
        shieldFraction = enemy.shieldMax > 0 ? enemy.shield / enemy.shieldMax : 0;
        flash = enemy.hitFlash > 0 ? enemy.hitFlash / 0.12 * 0.6 : 0;
        slowed = enemy.slowFactor > 0;
    }
}
