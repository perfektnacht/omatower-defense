import QtQuick
import Quickshell
import Quickshell.Io
import "game"

// Grades every theme on this machine against the palette the game actually
// resolves — not the raw colors.toml. Prints, per theme:
//
//   * the mode it resolved to, and whether the palette collapsed
//   * WCAG contrast for every text-on-surface pair the game really draws
//   * the seven gameplay hues, and the smallest separation between any two
//
// The last one is the number that matters: if two roles are within a few
// degrees and a few points of lightness, the player cannot tell a DATA car from
// a BEAM car, however pretty the theme is.
ShellRoot {
    id: harness

    property var themes: []
    property int index: -1
    property int failures: 0

    function hex(c) {
        const to = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        const col = Qt.color(c);
        return "#" + to(col.r) + to(col.g) + to(col.b);
    }

    function pad(s, n) { return String(s).padEnd(n); }
    function num(v, n) { return v.toFixed(2).padStart(n); }

    // Deliberately the theme's own metric and threshold: a harness that grades
    // against a different bar than the code enforces is worse than no harness.
    function separation(a, b) { return Theme.separation(a, b); }

    function report() {
        const t = Theme;
        console.log("");
        console.log("──── " + (harness.index < 0 ? "CURRENT" : harness.themes[harness.index].name));
        console.log("   mode          " + (t.isLight ? "light" : "dark")
                    + "   bg " + hex(t.bg) + "   accent " + hex(t.accent));
        console.log("   palette       " + (t.collapsed
                        ? (t.achromatic ? "achromatic -> lightness ramp"
                                        : "collapsed -> analogous fan")
                        : "distinct -> theme hues kept")
                    + "   (concentration " + num(t.hueConcentration, 4)
                    + ", chroma " + num(t.meanChroma, 4) + ")");

        // ---- contrast -----------------------------------------------------
        const pairs = [
            ["fg on panel",       t.fg,       t.bgPanel,  4.5],
            ["fgDim on panel",    t.fgDim,    t.bgPanel,  4.5],
            ["fgBright on panel", t.fgBright, t.bgPanel,  4.5],
            ["fg on bg",          t.fg,       t.bg,       4.5],
            ["fg on raised",      t.fg,       t.bgRaised, 4.5],
            ["fgDim on raised",   t.fgDim,    t.bgRaised, 4.5],
            ["fgDim on lift",     t.fgDim,    t.bgLift,   3.0],
            ["accentInk on accent", t.accentInk, t.accent,  4.5]
        ];
        let worst = 99;
        let line = "";
        for (const p of pairs) {
            const r = t.contrast(p[1], p[2]);
            const ok = r >= p[3];
            if (!ok)
                harness.failures += 1;
            worst = Math.min(worst, r / p[3]);
            line += "\n     " + pad(p[0], 20) + num(r, 6) + ":1  "
                  + pad(t.grade(p[1], p[2]), 9) + (ok ? "ok" : "UNDER " + p[3] + ":1");
        }
        console.log("   contrast" + line);

        // ---- gameplay hues -------------------------------------------------
        const roles = t.hueRoles.map(n => ({ name: n, c: t.roleColor(n) }));
        let swatch = "";
        for (const r of roles)
            swatch += " " + r.name.slice(0, 3) + " " + hex(r.c);
        console.log("   hues         " + swatch);

        let minSep = 99;
        let worstPair = "";
        for (let i = 0; i < roles.length; i++) {
            for (let j = i + 1; j < roles.length; j++) {
                const d = separation(roles[i].c, roles[j].c);
                if (d < minSep) {
                    minSep = d;
                    worstPair = roles[i].name + "/" + roles[j].name;
                }
            }
        }
        const sepOk = minSep >= Theme.minRoleSeparation;
        if (!sepOk)
            harness.failures += 1;
        console.log("   separation    closest pair " + pad(worstPair, 16)
                    + num(minSep, 6) + "   " + (sepOk ? "ok" : "TOO CLOSE"));
    }

    function next() {
        harness.index += 1;
        if (harness.index >= harness.themes.length) {
            console.log("");
            console.log(harness.failures === 0
                        ? "=== ALL THEMES PASS ==="
                        : "=== " + harness.failures + " PROBLEM(S) ACROSS " +
                          (harness.themes.length + 1) + " THEMES ===");
            return;
        }
        Theme.sourcePath = harness.themes[harness.index].path;
        // The palette is read through a watched FileView, so give it a turn of
        // the event loop to land before reading anything back.
        settle.restart();
    }

    Timer {
        id: settle
        interval: 120
        onTriggered: { harness.report(); harness.next(); }
    }

    Process {
        id: findThemes
        running: true
        // EXTRA points at a directory of additional theme folders, which is how
        // the light-mode and greyscale cases get graded without installing
        // them: no Omarchy theme in the wild is light yet, and those are
        // precisely the palettes most likely to break the art.
        // Both theme roots. Grading only ~/.config/omarchy/themes was grading
        // four themes while twenty-two shipped ones went unchecked, which is
        // how a light theme with unreadable shop cards got through.
        command: ["bash", "-lc",
                  "for d in ${OMARCHY_PATH:-/usr/share/omarchy}/themes/*/ " +
                  "         ~/.config/omarchy/themes/*/ ${EXTRA:+$EXTRA/*/}; do " +
                  "  [ -f \"$d/colors.toml\" ] || continue; " +
                  // Parameter expansion rather than $(basename $d): the name is
                  // never re-split, so a theme directory with a space in it
                  // still resolves to one theme.
                  "  n=${d%/}; n=${n##*/}; " +
                  "  printf '%s|%s\\n' \"$n\" \"$d/colors.toml\"; " +
                  "done | sort -u -t'|' -k1,1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of this.text.split("\n")) {
                    const parts = line.trim().split("|");
                    if (parts.length === 2 && parts[0] !== "")
                        found.push({ name: parts[0], path: parts[1] });
                }
                harness.themes = found;
                console.log("=== resolved palette for " + (found.length + 1) + " themes ===");
                harness.report();     // the live one, before any override
                harness.next();
            }
        }
    }
}
