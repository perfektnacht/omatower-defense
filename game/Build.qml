pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// A stamp of the sources actually on disk, written by tools/reload.sh. The
// shell loads plugin QML from disk, so if the running instance reports the same
// stamp the reload landed — and if it does not, you are looking at stale code.
Singleton {
    id: root

    // Also file-derived, so it gets the same flattening as the theme name: no
    // control characters, no markup for Qt's AutoText sniffer to latch onto,
    // and a length clamp. See the note in Theme.qml.
    readonly property string stamp: {
        const t = (buildFile.text() || "").replace(/[\x00-\x1f\x7f]/g, " ")
                                          .replace(/[<>&]/g, "")
                                          .slice(0, 48)
                                          .trim();
        return t === "" ? "dev" : t;
    }

    FileView {
        id: buildFile
        path: Qt.resolvedUrl("BUILD").toString().replace("file://", "")
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: this.reload()
    }
}
