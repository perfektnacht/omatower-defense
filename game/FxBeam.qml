import QtQuick

// A laseretch stroke: a bright core with a soft halo behind it.
Item {
    id: beam

    property real life: 0
    property real maxLife: 1

    transformOrigin: Item.Left

    Rectangle {
        id: halo
        y: -parent.height * 1.6
        width: parent.width
        height: parent.height * 4.2
        radius: height / 2
        opacity: 0.28
    }

    Rectangle {
        id: core
        width: parent.width
        height: parent.height
        radius: height / 2
    }

    function place(x1: real, y1: real, x2: real, y2: real, c: color, w: real): void {
        beam.x = x1;
        beam.y = y1 - w / 2;
        beam.width = Math.hypot(x2 - x1, y2 - y1);
        beam.height = w;
        beam.rotation = Math.atan2(y2 - y1, x2 - x1) * 180 / Math.PI;
        core.color = Qt.lighter(c, 1.6);
        halo.color = c;
    }
}
