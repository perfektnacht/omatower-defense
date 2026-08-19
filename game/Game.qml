pragma ComponentBehavior: Bound

import QtQuick

// The whole game surface: arena plus chrome. Hosted by shell.qml when running
// standalone, and by Panel.qml when running inside omarchy-shell.
FocusScope {
    id: game

    property bool active: true
    property bool showClose: false
    // Set by the plugin host, where leaving the workspace hides the overlay.
    // The standalone window has no such behaviour, so it does not claim it.
    property bool showWorkspaceHint: false

    signal requestClose()
    property int hudTop: 62
    property int hudBottom: 128
    readonly property int sideColumn: width > 1460 ? 322 : 0

    readonly property alias sim: sim

    Sim {
        id: sim
        active: game.active
        onAnnounce: (text, kind) => ticker.show(text, kind)
        onShake: amount => shaker.kick(amount)
    }

    // ---- entity view factories -------------------------------------------
    Component { id: enemyComp;  EnemyChip {} }
    Component { id: towerComp;  Quattro {} }
    Component { id: shotComp;   Projectile {} }
    Component { id: glyphComp;  FxGlyph {} }
    Component { id: beamComp;   FxBeam {} }

    // ---- arena -------------------------------------------------------------
    Item {
        id: arena
        anchors.fill: parent
        anchors.topMargin: game.hudTop
        anchors.bottomMargin: game.hudBottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14 + game.sideColumn

        Item {
            id: shaker
            anchors.fill: parent

            property real kickAmount: 0

            function kick(amount: real): void {
                kickAmount = amount;
                shakeAnim.restart();
            }

            NumberAnimation on kickAmount {
                id: shakeAnim
                running: false
                to: 0
                duration: 340
                easing.type: Easing.OutQuad
            }

            transform: Translate {
                x: shaker.kickAmount === 0 ? 0 : (Math.random() - 0.5) * shaker.kickAmount
                y: shaker.kickAmount === 0 ? 0 : (Math.random() - 0.5) * shaker.kickAmount
            }

            Battlefield {
                id: field
                sim: sim
                transformOrigin: Item.TopLeft
                scale: Math.min(shaker.width / width, shaker.height / height)
                x: (shaker.width - width * scale) / 2
                y: (shaker.height - height * scale) / 2

                onFieldHovered: (x, y) => {
                    const slot = sim.towers.nearestFreeSlot(x, y);
                    sim.ghostValid = slot !== null;
                    sim.ghostX = slot ? slot.x : x;
                    sim.ghostY = slot ? slot.y : y;
                }

                onFieldClicked: (x, y, button) => {
                    game.forceActiveFocus();
                    if (button === Qt.RightButton) {
                        sim.cancelPlacing();
                        sim.selected = null;
                        return;
                    }
                    if (sim.placingId !== "") {
                        sim.tryPlace(x, y);
                        return;
                    }
                    sim.selected = sim.towers.towerAt(x, y);
                }
            }
        }
    }

    // ---- pause ---------------------------------------------------------------
    PauseVeil {
        sim: sim
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: game.hudTop
    }

    // ---- chrome ------------------------------------------------------------
    Hud {
        id: hud
        sim: sim
        showClose: game.showClose
        showWorkspaceHint: game.showWorkspaceHint
        onCloseRequested: game.requestClose()
        onMenuRequested: sim.abandonRun()
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: game.hudTop
    }

    Shop {
        id: shop
        sim: sim
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: game.hudBottom
    }

    // The side column carries both panels at once, stacked: what you selected
    // on top, what is coming underneath. Picking a car used to hide the wave
    // preview, which is the one moment you most want to read it.
    Item {
        id: sidePanels
        visible: game.sideColumn > 0 && !sim.over
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: game.hudTop + 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: game.hudBottom + 14
        width: 296

        Column {
            id: sideStack
            width: parent.width
            spacing: 12

            // Last resort for a short window: the briefing already drops its
            // notes to make room, and only if that still overflows does the
            // column shrink rather than run off the bottom of the screen.
            transformOrigin: Item.TopLeft
            scale: Math.min(1, sidePanels.height / Math.max(1, implicitHeight))

            Inspector {
                id: inspectorPanel
                sim: sim
            }

            Briefing {
                sim: sim
                compact: inspectorPanel.visible
            }
        }
    }

    Ticker {
        id: ticker
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: game.hudTop + 18
    }

    GameOver {
        sim: sim
        anchors.fill: parent
        visible: sim.over
        showClose: game.showClose
        onCloseRequested: game.requestClose()
    }

    StartScreen {
        id: startScreen
        sim: sim
        anchors.fill: parent
        visible: !sim.started
        showClose: game.showClose
        showWorkspaceHint: game.showWorkspaceHint
        onCloseRequested: game.requestClose()
    }

    // ---- keyboard ----------------------------------------------------------
    focus: true

    Keys.onPressed: event => {
        // The picker owns the keyboard until a run is going.
        if (!sim.started) {
            switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                startScreen.beginRun();
                event.accepted = true;
                return;
            case Qt.Key_Left:
                startScreen.picked = Math.max(0, startScreen.picked - 1);
                event.accepted = true;
                return;
            case Qt.Key_Right:
                startScreen.picked = Math.min(Balance.circuits.length - 1, startScreen.picked + 1);
                event.accepted = true;
                return;
            case Qt.Key_Escape:
                game.requestClose();
                event.accepted = true;
                return;
            }
            return;
        }

        const shopIds = sim.availableTowers;
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            const i = event.key - Qt.Key_1;
            if (i < shopIds.length)
                sim.beginPlacing(shopIds[i]);
            event.accepted = true;
            return;
        }

        switch (event.key) {
        case Qt.Key_Space:
            // Space is "get on with it" while planning and "stop" once the
            // takes are on the road — but a manual pause always resumes on
            // Space, whatever phase it happened in.
            if (sim.paused)
                sim.resume();
            else if (sim.waves.phase === "planning")
                sim.callWave();
            else
                sim.togglePause();
            event.accepted = true;
            break;
        case Qt.Key_P:
            sim.togglePause();
            event.accepted = true;
            break;
        case Qt.Key_Escape:
            // Escape unwinds what you are doing first, and only closes the
            // game once there is nothing left to cancel.
            if (sim.placingId !== "")
                sim.cancelPlacing();
            else if (sim.selected)
                sim.selected = null;
            else
                game.requestClose();
            event.accepted = true;
            break;
        case Qt.Key_U:
            sim.tryUpgradeSelected();
            event.accepted = true;
            break;
        case Qt.Key_S:
            sim.trySellSelected();
            event.accepted = true;
            break;
        case Qt.Key_T:
            sim.cycleTargetMode(1);
            event.accepted = true;
            break;
        case Qt.Key_R:
            if (sim.over)
                sim.newRun(sim.mode);
            event.accepted = true;
            break;
        }
    }

    // ---- start -------------------------------------------------------------
    function mount(): void {
        sim.enemies.layer = field.enemyLayer;
        sim.enemies.viewComponent = enemyComp;
        sim.towers.layer = field.towerLayer;
        sim.towers.viewComponent = towerComp;
        sim.projectiles.layer = field.shotLayer;
        sim.projectiles.viewComponent = shotComp;
        sim.fx.layer = field.fxLayer;
        sim.fx.glyphComponent = glyphComp;
        sim.fx.beamComponent = beamComp;
    }

    Component.onCompleted: mount()
}
