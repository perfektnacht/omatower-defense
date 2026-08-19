import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "game"

// Overlay entry point for omarchy-shell.
//
// The shell drives this through three members: `opened`, `open(payloadJson)`
// and `close()`. `keepLoaded` in the manifest keeps the instance alive between
// summons, so hiding the game pauses a run rather than throwing it away.
Item {
    id: root

    property bool opened: false

    // Injected by the shell host; unused here but part of the contract.
    property var shell: null
    property var manifest: null
    property string omarchyPath: ""

    function open(payloadJson: string): void {
        root.opened = true;
        // Whatever workspace we open on is the one the game belongs to.
        root.homeWorkspace = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1;
        Qt.callLater(() => game.forceActiveFocus());
    }

    function close(): void {
        root.opened = false;
    }

    // Queried by tools/reload.sh over `omarchy-shell shell call` to prove which
    // build the shell actually has in memory.
    function buildInfo(arg: string): string {
        const version = manifest && manifest.version ? manifest.version : "dev";
        return version + "+" + Build.stamp;
    }

    function toggle(): void {
        if (root.opened)
            root.close();
        else
            root.open("{}");
    }

    // ---- workspace handoff --------------------------------------------------
    // A layer-shell overlay is not owned by a workspace: it floats above every
    // one of them. Left alone, switching to workspace 3 to answer a message
    // would just show you the game again, on top of the message, with nothing
    // clickable underneath — the whole machine held hostage by a tower defense.
    //
    // So the game gives the desktop back. Leaving its workspace hides it, which
    // clears `active` and pauses the run in place; the bar widget brings it back
    // exactly as it was.
    property int homeWorkspace: -1

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged(): void {
            const ws = Hyprland.focusedWorkspace;
            if (!ws)
                return;
            // The singleton reports null until it has talked to Hyprland, so the
            // first real value is adoption, not a switch away.
            if (root.homeWorkspace < 0) {
                root.homeWorkspace = ws.id;
                return;
            }
            if (root.opened && ws.id !== root.homeWorkspace)
                root.close();
        }
    }

    PanelWindow {
        id: window
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        WlrLayershell.namespace: "omatower-defense"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
        }

        Game {
            id: game
            anchors.fill: parent
            // Stops the clock while the overlay is hidden, so a run cannot
            // quietly lose all its lives behind your back.
            active: root.opened
            showClose: true
            showWorkspaceHint: true
            focus: root.opened
            onRequestClose: root.close()
        }
    }
}
