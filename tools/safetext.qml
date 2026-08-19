import QtQuick
import Quickshell
import "game"

// theme.name and BUILD are read off disk, so whoever can write them chooses
// that string. QML's Text defaults to AutoText, which sniffs for markup and
// upgrades to rich text on its own -- and rich text resolves <img src="...">
// against local paths and remote URLs, from the shell process. This harness
// proves the sniffer really does upgrade, then proves the game no longer
// hands it anything to upgrade.
ShellRoot {
    FloatingWindow {
        implicitWidth: 1600; implicitHeight: 900; color: Theme.bg
        Game { id: game; anchors.fill: parent }

        // The hazard, reproduced: same string, two textFormats.
        Text { id: sniffed; visible: false; font.pixelSize: 14 }
        Text { id: pinned;  visible: false; font.pixelSize: 14; textFormat: Text.PlainText }
    }

    property int fails: 0

    function check(name, cond, detail) {
        console.log((cond ? "  PASS  " : "  FAIL  ") + name + (detail ? "   [" + detail + "]" : ""));
        if (!cond) fails += 1;
        return cond;
    }

    // Every Text in a live tree, found by duck-typing rather than test-only API.
    function texts(item, out) {
        for (const c of item.children) {
            if (c.text !== undefined && c.textFormat !== undefined)
                out.push(c);
            texts(c, out);
        }
        return out;
    }

    Timer {
        running: true; interval: 900
        onTriggered: {
            const hostile = '<img src="https://example.invalid/pixel.png">ethereal';

            // ---- 1. the hazard is real ---------------------------------
            console.log("=== Qt's AutoText sniffer ===");
            sniffed.text = hostile;
            pinned.text = hostile;
            console.log("  autotext width=" + sniffed.contentWidth.toFixed(1)
                        + "  plaintext width=" + pinned.contentWidth.toFixed(1));
            check("AutoText swallows the tag instead of drawing it",
                  sniffed.contentWidth < pinned.contentWidth * 0.7,
                  "this is the bug: the tag was parsed, not printed");
            check("PlainText draws every character literally",
                  pinned.contentWidth > 0);

            // ---- 2. the source flattens hostile input -------------------
            console.log("=== Theme.oneLine() on hostile input ===");
            const cases = [
                hostile,
                '<a href="file:///etc/passwd">x</a>',
                "ether eal\n\nrogue",
                "&lt;&amp;&gt;",
                "x".repeat(400)
            ];
            let dirty = 0;
            for (const c of cases) {
                const out = Theme.oneLine(c);
                const bad = /[<>&]/.test(out) || /[\x00-\x1f\x7f]/.test(out) || out.length > 48;
                if (bad) { dirty++; console.log("    leaked: " + JSON.stringify(out)); }
            }
            check("no markup, control characters or overlong strings survive", dirty === 0,
                  "dirty=" + dirty);
            check("a normal theme name is left alone", Theme.oneLine("  ethereal \n") === "ethereal",
                  JSON.stringify(Theme.oneLine("  ethereal \n")));

            // ---- 3. the live render sites are pinned -------------------
            console.log("=== render sites in a live Game ===");
            const all = texts(game, []);
            const derived = all.filter(t => typeof t.text === "string" && t.text !== ""
                                       && (t.text.indexOf(Theme.themeName) >= 0
                                           || t.text.indexOf(Build.stamp) >= 0));
            console.log("  " + all.length + " Text items, " + derived.length
                        + " carrying file-derived text");
            check("found the file-derived render sites", derived.length > 0);
            const loose = derived.filter(t => t.textFormat !== Text.PlainText);
            check("every one of them is pinned to PlainText", loose.length === 0,
                  "loose=" + loose.length + (loose.length ? " first=" + JSON.stringify(loose[0].text) : ""));

            console.log(fails === 0 ? "=== ALL CHECKS PASSED ===" : "=== " + fails + " CHECK(S) FAILED ===");
            Qt.exit(fails === 0 ? 0 : 1);
        }
    }
}
