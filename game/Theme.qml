pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Reads the live Omarchy palette so the game recolors itself whenever the user
// runs `omarchy theme set`. Handles the named schema (background, accent, red,
// ...), the older color0..color15 schema generated from alacritty.toml, and the
// `mode = "light" | "dark"` anchor that Aether writes.
//
// Two things a tower defense needs that a terminal palette does not promise:
//
//   1. Seven *separable* accent colours. Aether's Monochromatic, Muted and
//      Pastel extraction modes legitimately collapse every ANSI hue onto one —
//      a real theme in the wild has `red`, `orange` and `magenta` as literally
//      the same blue. Damage types, affordability and seventeen different takes
//      all stop reading. When that happens the palette is rebuilt as an
//      analogous fan around the theme's own hue: still unmistakably the theme,
//      but separable.
//
//   2. Text that survives its background. Aether ships a WCAG AAA/AA grader, so
//      themes are authored expecting that discipline; the game holds its own
//      text to AA and only touches a colour that actually fails.
Singleton {
    id: root

    // Harness override. Empty means "whatever the user is running".
    property string sourcePath: ""

    readonly property string defaultColorsPath:
        Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    readonly property string colorsPath: sourcePath !== "" ? sourcePath : defaultColorsPath
    readonly property string namePath:
        Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"

    // `omarchy-theme-set` does not edit colors.toml, it does
    //
    //     rm -rf  ~/.local/state/omarchy/current/theme
    //     mv      <staged dir>  ~/.local/state/omarchy/current/theme
    //
    // so every switch hands us a brand new inode. A file watch is attached to
    // an inode, not a path: the first switch kills the watch along with the old
    // file, and every switch after that goes unnoticed. Worse, a read that
    // lands in the window between the rm and the mv returns nothing, and the
    // palette collapses to the built-in fallback and stays there.
    //
    // So: keep the watch for instant response, re-arm it when it fires, poll as
    // the safety net, and never let an empty read overwrite a good palette.
    property var raw: ({})
    property string rawText: ""

    // theme.name is read straight off disk, so it is hostile input: anyone who
    // can write that file picks this string. QML's Text defaults to AutoText,
    // which sniffs for markup and silently upgrades to rich text -- and rich
    // text resolves <img src="...">, pulling local files or remote URLs from
    // the shell process. Render sites pin textFormat to PlainText; stripping it
    // here as well means a future render site cannot reintroduce the hole.
    readonly property string themeName: {
        const t = root.oneLine(nameFile.text());
        return t === "" ? "unknown" : t;
    }

    // Flattens untrusted file text to something inert: no control characters,
    // nothing Qt's rich-text sniffer keys on, and short enough that a large
    // file cannot push the rest of the bar off screen.
    function oneLine(s: string): string {
        return (s || "").replace(/[\x00-\x1f\x7f]/g, " ")
                        .replace(/[<>&]/g, "")
                        .slice(0, 48)
                        .trim();
    }

    function refresh(): void {
        const text = colorsFile.text();
        if (text === rawText)
            return;

        const parsed = parse(text);
        // Mid-rename the file is absent and the parse comes back empty. Holding
        // the last good palette means a theme switch never flashes the fallback
        // colours on its way to the new ones.
        if (Object.keys(parsed).length < 3)
            return;

        rawText = text;
        raw = parsed;
    }

    // Re-opening by path is what picks up the replacement inode; reload() alone
    // would re-read a file that no longer exists at that inode.
    function rearm(): void {
        livePath = "";
        livePath = colorsPath;
    }

    property string livePath: colorsPath
    onColorsPathChanged: livePath = colorsPath

    // Cheap because refresh() compares the raw text first and returns without
    // touching a single binding when nothing changed. One second is fast enough
    // that a switch reads as instant even when the watch has died.
    readonly property Timer resync: Timer {
        interval: 900
        repeat: true
        running: true
        onTriggered: {
            colorsFile.reload();
            nameFile.reload();
            root.refresh();
        }
    }

    // ---- resolution ---------------------------------------------------------
    // The whole palette is resolved in ONE binding, deliberately.
    //
    // It used to be a chain — raw -> themeHues -> hueConcentration -> collapsed
    // -> resolvedHues -> red — and QML invalidates a chain by *pushing* change
    // signals through it. A lazily-evaluated link that nothing has read yet
    // never fires its signal, so everything downstream of it keeps serving
    // cached values. The visible result was a half-applied theme: backgrounds
    // and text switched instantly while every car and every take kept the
    // previous theme's colours until something else happened to touch the
    // chain.
    //
    // One binding, one hop from `raw`, no lazy links in between. Everything
    // below is a thin accessor onto this object, so the whole palette flips in
    // the same frame or not at all.
    readonly property var palette: {
        const p = {};

        // ---- mode ----------------------------------------------------------
        // Aether swaps its anchors for light themes, so every "darker" in the
        // game has to become a "lighter". Inferred from the background when
        // unstated, which is what the colorN-only schema gives you.
        p.bg = Qt.color(pick(["darker_background", "background", "color0"], "#0b0f0d"));
        const mode = (raw.mode || "").toLowerCase();
        p.isLight = mode === "light" ? true
                  : mode === "dark" ? false
                  : relLuminance(p.bg) > 0.4;

        // ---- neutrals -------------------------------------------------------
        const rawFg = Qt.color(pick(["foreground", "color7"], "#c1c497"));

        // A surface has to stay on the background's side of the fence. Sparse
        // themes — and there are shipped ones defining only foreground,
        // background and selection — fall through to `selection`, which in many
        // palettes is a near-white highlight meant to carry dark text. Used as a
        // panel on a near-black theme it produces a surface no text colour can
        // satisfy alongside the real background, and the contrast pass then has
        // an impossible job. Anything that far out of line is derived instead.
        const surfaceOk = c => {
            const lum = relLuminance(c);
            return p.isLight ? lum >= 0.25 : lum <= 0.35;
        };
        const surface = (keys, fallback, t) => {
            const c = Qt.color(pick(keys, fallback));
            return surfaceOk(c) ? c : mix(p.bg, rawFg, t);
        };

        p.bgPanel  = surface(["dark_background", "background", "color0"], "#111c18", 0.05);
        p.bgRaised = surface(["background", "lighter_background", "color0"], "#16221d", 0.09);
        p.bgLift   = surface(["lighter_background", "selection", "color8"], "#23372b", 0.16);
        p.muted    = Qt.color(pick(["muted", "selection", "color8"], "#53685b"));

        // Text lands on all four of these, so all four have to clear.
        const surfaces = [p.bg, p.bgPanel, p.bgRaised, p.bgLift];
        p.fg       = readableOn(rawFg, surfaces, 4.5);
        p.fgDim    = readableOn(pick(["dark_foreground", "muted", "color8"], "#81b8a8"), surfaces, 4.5);
        p.fgBright = readableOn(pick(["bright_foreground", "light_foreground", "color15"], "#f7e8b2"),
                                surfaces, 4.5);

        p.accent = Qt.color(pick(["accent", "blue", "color4"], "#509475"));
        // Whichever palette extreme reads better on the accent, then pushed
        // until it actually passes: a mid-tone accent can be too dark for the
        // background colour and too light for the foreground one at once.
        const accentBase = contrast(p.bg, p.accent) >= contrast(p.fgBright, p.accent)
                         ? p.bg : p.fgBright;
        p.accentInk = readableOn(accentBase, [p.accent], 4.5);

        // Line art needs a hard outline against the car body, and the body is
        // built from the foreground — so on a light theme it has to invert.
        p.ink    = p.isLight ? Qt.lighter(p.bgRaised, 1.9) : Qt.darker(p.bg, 1.9);
        p.rubber = p.isLight ? Qt.lighter(p.bgRaised, 1.5) : Qt.darker(p.bg, 1.5);
        p.shadow = p.isLight ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(0, 0, 0, 0.42);

        // ---- gameplay hues ---------------------------------------------------
        const themeHues = [
            pick(["red", "color1"], "#ff5345"),
            pick(["orange", "bright_yellow", "color3"], "#a2734b"),
            pick(["yellow", "color3"], "#e5c736"),
            pick(["green", "color2"], "#549e6a"),
            pick(["cyan", "color6"], "#2dd5b7"),
            pick(["blue", "color4"], "#509475"),
            pick(["magenta", "color5"], "#d2689c")
        ].map(c => Qt.color(c));
        p.themeHues = themeHues;

        // Circular variance of the hues, weighted by saturation so a nearly
        // grey swatch cannot vote for a hue it does not really have. 1 means
        // they all point the same way; 0 means they cover the wheel.
        let x = 0, y = 0, weight = 0, chroma = 0;
        for (const c of themeHues) {
            chroma += c.hslSaturation;
            if (c.hslHue < 0)
                continue;
            const w = c.hslSaturation;
            const a = c.hslHue * 2 * Math.PI;
            x += Math.cos(a) * w;
            y += Math.sin(a) * w;
            weight += w;
        }
        p.concentration = weight <= 0.001 ? 1 : Math.hypot(x, y) / weight;
        p.chroma = chroma / Math.max(1, themeHues.length);

        // "Collapsed" means the accents no longer distinguish anything: they
        // all point the same way, or there is too little chroma for a hue to
        // mean anything at all.
        p.collapsed = p.concentration > 0.90 || p.chroma < 0.10;
        // Genuinely no chroma is a deliberate choice and painting a rainbow
        // over it would be vandalism, so those separate by lightness alone.
        p.achromatic = p.chroma < 0.06;

        let anchorHue = p.accent.hslHue;
        if (!(anchorHue >= 0) || p.accent.hslSaturation <= 0.05) {
            anchorHue = 0.58;
            let bestSat = 0;
            for (const c of themeHues) {
                if (c.hslHue >= 0 && c.hslSaturation > bestSat) {
                    bestSat = c.hslSaturation;
                    anchorHue = c.hslHue;
                }
            }
        }
        // Deliberately more saturated than the theme's own accent: a collapsed
        // palette is usually collapsed *and* muted, and a fan built at the
        // theme's chroma comes out as seven pastels that are technically
        // different and practically identical once the car art mixes them
        // toward the foreground.
        const anchorSat = p.achromatic ? 0
            : Math.max(0.46, Math.min(0.80, p.accent.hslSaturation * 1.35));
        const anchorLight = p.isLight ? 0.44 : 0.62;
        const n = hueRoles.length;

        // Spread across a 120 degree arc: wide enough that neighbours are
        // plainly different, narrow enough to still read as one family.
        const fan = index => {
            const span = 120 / 360;
            const step = n > 1 ? span / (n - 1) : 0;
            const h = (anchorHue - span / 2 + index * step + 1) % 1;
            // The achromatic ramp needs the whole usable range: lightness is
            // the only axis it has, and seven roles will not fit in the
            // narrower band the coloured fan uses.
            const lo = p.achromatic ? (p.isLight ? 0.12 : 0.22) : (p.isLight ? 0.24 : 0.36);
            const hi = p.achromatic ? (p.isLight ? 0.78 : 0.88) : (p.isLight ? 0.62 : 0.82);
            const l = p.achromatic
                ? lo + (hi - lo) * (index / Math.max(1, n - 1))
                : Math.max(lo, Math.min(hi, anchorLight * (index % 2 === 0 ? 1.24 : 0.72)));
            return Qt.hsla(h, anchorSat, l, 1);
        };

        // A theme is kept exactly as authored unless two of its accents are
        // close enough to be confused, and then only the second of the pair
        // moves — in lightness first, so the hue survives.
        //
        // A wholly collapsed palette skips the repair and goes straight to the
        // fan: repairing it pairwise would produce seven colours all nudged
        // away from the same starting point, which looks like a mistake rather
        // than a scheme.
        const roles = [];
        for (let i = 0; i < n; i++) {
            if (p.collapsed) {
                roles.push(fan(i));
                continue;
            }
            let c = themeHues[i];
            for (let attempt = 0; attempt < 8; attempt++) {
                let worst = 99;
                for (const other of roles)
                    worst = Math.min(worst, separation(c, other));
                if (worst >= minRoleSeparation)
                    break;
                if (attempt < 3) {
                    const src = themeHues[i];
                    const dir = (i % 2 === 0) ? 1 : -1;
                    const l = Math.max(0.20, Math.min(0.86,
                        src.hslLightness + dir * 0.11 * (attempt + 1)));
                    c = Qt.hsla(src.hslHue < 0 ? 0 : src.hslHue, src.hslSaturation, l, 1);
                } else {
                    c = mix(c, fan(i), 0.45);
                }
            }
            roles.push(c);
        }
        p.roles = roles;

        // The bright variants lift the *resolved* role rather than reading the
        // theme's bright_* keys, because on a collapsed palette those have
        // collapsed too, and a "bright" that is not brighter is worse than
        // useless.
        const lift = c => p.isLight ? Qt.darker(c, 1.32) : Qt.lighter(c, 1.32);
        const brightKeys = [
            ["bright_red", "color9", "red", "color1"],
            null,
            ["bright_yellow", "color11", "yellow"],
            ["bright_green", "color10", "green"],
            ["bright_cyan", "color14", "cyan"],
            ["bright_blue", "color12", "blue"],
            ["bright_magenta", "color13", "magenta"]
        ];
        const brightFallback = ["#db9f9c", "", "#e5c736", "#63b07a", "#8cd3cb", "#acd4cf", "#75bbb3"];
        p.bright = roles.map((c, i) => (p.collapsed || !brightKeys[i])
            ? lift(c)
            : Qt.color(pick(brightKeys[i], brightFallback[i])));

        return p;
    }

    // ---- accessors -----------------------------------------------------------
    readonly property bool isLight: palette.isLight

    readonly property color bg:        palette.bg
    readonly property color bgPanel:   palette.bgPanel
    readonly property color bgRaised:  palette.bgRaised
    readonly property color bgLift:    palette.bgLift
    readonly property color fg:        palette.fg
    readonly property color fgDim:     palette.fgDim
    readonly property color fgBright:  palette.fgBright
    readonly property color muted:     palette.muted
    readonly property color accent:    palette.accent
    readonly property color accentInk: palette.accentInk
    readonly property color ink:       palette.ink
    readonly property color rubber:    palette.rubber
    readonly property color shadow:    palette.shadow

    readonly property real hueConcentration: palette.concentration
    readonly property real meanChroma:       palette.chroma
    readonly property bool collapsed:        palette.collapsed
    readonly property bool achromatic:       palette.achromatic
    readonly property var  themeHues:        palette.themeHues

    // The order is the fan order: adjacent entries are adjacent on the wheel,
    // so the two colours most likely to be confused are the two furthest apart
    // in this list, not the two next to each other.
    readonly property var hueRoles: ["red", "orange", "yellow", "green", "cyan", "blue", "magenta"]

    // How far apart two gameplay roles have to be before a player can tell a
    // DATA car from a BEAM one at sprite size. Hue counts only in proportion to
    // the chroma both colours actually carry, so a pair separated purely by
    // lightness still scores.
    //
    // Set from what actually reads on a car sprite, not from what is measurably
    // different: an earlier 0.055 passed a palette whose seven cars were
    // indistinguishable olive in the shop.
    readonly property real minRoleSeparation: 0.10

    function separation(a: color, b: color): real {
        const ca = Qt.color(a);
        const cb = Qt.color(b);
        const dl = Math.abs(ca.hslLightness - cb.hslLightness);
        const chroma = Math.min(ca.hslSaturation, cb.hslSaturation);
        let dh = 0;
        if (ca.hslHue >= 0 && cb.hslHue >= 0) {
            dh = Math.abs(ca.hslHue - cb.hslHue);
            dh = Math.min(dh, 1 - dh);
        }
        return dh * chroma * 2.2 + dl;
    }

    function roleColor(name: string): color {
        const i = hueRoles.indexOf(name);
        return i < 0 ? accent : palette.roles[i];
    }

    readonly property color red:     palette.roles[0]
    readonly property color orange:  palette.roles[1]
    readonly property color yellow:  palette.roles[2]
    readonly property color green:   palette.roles[3]
    readonly property color cyan:    palette.roles[4]
    readonly property color blue:    palette.roles[5]
    readonly property color magenta: palette.roles[6]

    readonly property color brightRed:     palette.bright[0]
    readonly property color brightYellow:  palette.bright[2]
    readonly property color brightGreen:   palette.bright[3]
    readonly property color brightCyan:    palette.bright[4]
    readonly property color brightBlue:    palette.bright[5]
    readonly property color brightMagenta: palette.bright[6]

    // Track / terrain, derived so it works on any theme.
    readonly property color grass:     isLight ? Qt.lighter(bgPanel, 1.04) : Qt.darker(bgPanel, 1.15)
    readonly property color grassAlt:  isLight ? Qt.darker(bgPanel, 1.06)  : Qt.lighter(bgPanel, 1.12)
    readonly property color track:     mix(bgLift, fg, 0.10)
    readonly property color trackEdge: mix(bgLift, fg, 0.32)

    // `monospace` is the fontconfig alias Omarchy repoints with `omarchy font set`,
    // so binding to it means the game follows whatever the user picked.
    readonly property string mono: "monospace"
    // Happy accident: the display face on this system is literally called Quattro.
    readonly property string display: "iA Writer Quattro S"

    readonly property int fsCaption: 11
    readonly property int fsSmall: 12
    readonly property int fsBody: 13
    readonly property int fsTitle: 16
    readonly property int fsHeading: 21
    readonly property int fsDisplay: 34

    readonly property int radius: 10
    readonly property int radiusLarge: 16

    // ---- colour maths ------------------------------------------------------
    function pick(keys: var, fallback: string): string {
        for (let i = 0; i < keys.length; i++) {
            const v = raw[keys[i]];
            if (v !== undefined && v !== "" && /^#[0-9A-Fa-f]{6}$/.test(v))
                return v;
        }
        return fallback;
    }

    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // WCAG 2.1 relative luminance: sRGB channels linearised, then weighted.
    function relLuminance(c: color): real {
        const col = Qt.color(c);
        const lin = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * lin(col.r) + 0.7152 * lin(col.g) + 0.0722 * lin(col.b);
    }

    function contrast(a: color, b: color): real {
        const la = relLuminance(a);
        const lb = relLuminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // Whichever of the two palette extremes reads better on this fill — and
    // then pushed until it actually passes. A mid-tone accent (a strong red,
    // say) can be too dark for the background colour and too light for the
    // foreground one, so choosing between them is not enough on its own.
    function on(fill: color): color {
        const base = contrast(bg, fill) >= contrast(fgBright, fill) ? bg : fgBright;
        return readableOn(base, [fill], 4.5);
    }

    function grade(a: color, b: color): string {
        const r = contrast(a, b);
        return r >= 7 ? "AAA" : r >= 4.5 ? "AA" : r >= 3 ? "AA-large" : "fail";
    }

    // Nudges a colour's lightness until it clears the ratio against *every*
    // surface it is drawn on, and no further. A theme that already passes is
    // returned untouched — this corrects mistakes, it does not restyle.
    //
    // Two things this has to get right that the obvious version does not:
    //
    //   * The panel is not the only surface. The same dim text sits on bgPanel,
    //     bgRaised and bgLift, and correcting it against the darkest of those
    //     left it failing on the lightest — which is where the shop cards are.
    //   * Away-from-the-background is not always the way out. A mid-tone fill
    //     can be unreachable toward white and comfortable toward black, so both
    //     directions are tried and the better one wins rather than the assumed
    //     one losing.
    function readableOn(src: color, surfaces: var, ratio: real): color {
        const start = Qt.color(src);
        const score = c => {
            let worst = 99;
            for (const s of surfaces)
                worst = Math.min(worst, contrast(c, s));
            return worst;
        };
        if (score(start) >= ratio)
            return start;

        const hue = start.hslHue < 0 ? 0 : start.hslHue;
        const sat = start.hslHue < 0 ? 0 : start.hslSaturation;

        // Try away from the dominant surface first, so a colour that can be
        // fixed the expected way still looks the way the theme intended.
        let meanLum = 0;
        for (const s of surfaces)
            meanLum += relLuminance(s);
        meanLum /= Math.max(1, surfaces.length);
        const dirs = meanLum < 0.5 ? [1, -1] : [-1, 1];

        let best = start;
        let bestScore = score(start);

        for (const dir of dirs) {
            let l = start.hslLightness;
            for (let i = 0; i < 50; i++) {
                l = Math.max(0, Math.min(1, l + dir * 0.02));
                const c = Qt.hsla(hue, sat, l, 1);
                const sc = score(c);
                if (sc > bestScore) {
                    bestScore = sc;
                    best = c;
                }
                if (sc >= ratio)
                    return c;
                if (l <= 0 || l >= 1)
                    break;
            }
        }
        // Unreachable against this set of surfaces; hand back the closest we got
        // rather than a colour that satisfies one surface by ruining another.
        return best;
    }

    function readable(fg: color, bg: color, ratio: real): color {
        return readableOn(fg, [bg], ratio);
    }

    function parse(text: string): var {
        const out = {};
        const lines = text.split("\n");
        for (const line of lines) {
            const m = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"?(#?[0-9A-Fa-f]{6}|[a-z]+)"?\s*$/.exec(line);
            if (!m)
                continue;
            let v = m[2];
            if (/^[0-9A-Fa-f]{6}$/.test(v))
                v = "#" + v;
            out[m[1]] = v;
        }
        return out;
    }

    FileView {
        id: colorsFile
        path: root.livePath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.refresh()
        onFileChanged: {
            this.reload();
            root.refresh();
            // The inode this watch was attached to is gone; without this the
            // next theme switch is silent.
            Qt.callLater(root.rearm);
        }
    }

    FileView {
        id: nameFile
        path: root.namePath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: this.reload()
    }

    Component.onCompleted: root.refresh()
}
