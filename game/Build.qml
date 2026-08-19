pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// A stamp of the sources actually on disk, written by tools/reload.sh. The
// shell loads plugin QML from disk, so if the running instance reports the same
// stamp the reload landed — and if it does not, you are looking at stale code.
Singleton {
    id: root

    readonly property string stamp: {
        const t = buildFile.text().trim();
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
