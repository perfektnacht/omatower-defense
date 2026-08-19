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

    // text() is a function but reads a notifying property, so these bindings
    // re-evaluate whenever the watched file changes on disk.
    readonly property string themeName: {
        const t = nameFile.text().trim();
        return t === "" ? "unknown" : t;
    }
    readonly property var raw: parse(colorsFile.text())

    // ---- mode --------------------------------------------------------------
    // Aether swaps its anchors for light themes, so every "darker" in the game
    // has to become a "lighter". Inferred from the palette when unstated, which
    // is what the colorN-only schema gives you.
    readonly property bool isLight: {
        const m = (raw.mode || "").toLowerCase();
        if (m === "light")
            return true;
        if (m === "dark")
            return false;
        return relLuminance(rawBg) > 0.4;
    }

    readonly property color rawBg: pick(["darker_background", "background", "color0"], "#0b0f0d")

    // ---- neutrals ----------------------------------------------------------
    readonly property color bg:        rawBg
    readonly property color bgPanel:   pick(["dark_background", "background", "color0"], "#111c18")
    readonly property color bgRaised:  pick(["background", "lighter_background", "color0"], "#16221d")
    readonly property color bgLift:    pick(["lighter_background", "selection", "color8"], "#23372b")

    readonly property color fg:        readable(pick(["foreground", "color7"], "#c1c497"), bgPanel, 4.5)
    readonly property color fgDim:     readable(pick(["dark_foreground", "muted", "color8"], "#81b8a8"), bgPanel, 4.5)
    readonly property color fgBright:  readable(pick(["bright_foreground", "light_foreground", "color15"], "#f7e8b2"), bgPanel, 4.5)
    readonly property color muted:     pick(["muted", "selection", "color8"], "#53685b")

    readonly property color accent:    pick(["accent", "blue", "color4"], "#509475")
    // Text drawn on top of a filled control. Picking the wrong end of the
    // palette here is the single most common way a themed button becomes
    // unreadable, and which end is right flips with the theme's mode.
    //
    // Not named `onAccent`: QML reads an `on<Name>` property as a signal
    // handler, accepts the declaration, never binds it, and leaves the colour
    // silently black.
    readonly property color accentInk: on(accent)

    // Line art needs a hard outline against the car body, and the body is built
    // from the foreground — so on a light theme the outline has to invert too.
    readonly property color ink:    isLight ? Qt.lighter(bgRaised, 1.9) : Qt.darker(bg, 1.9)
    readonly property color rubber: isLight ? Qt.lighter(bgRaised, 1.5) : Qt.darker(bg, 1.5)
    readonly property color shadow: isLight ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(0, 0, 0, 0.42)

    // ---- gameplay hues -----------------------------------------------------
    // The order is the fan order: adjacent entries are adjacent on the wheel, so
    // the two colours most likely to be confused are the two furthest apart in
    // this list, not the two next to each other.
    readonly property var hueRoles: ["red", "orange", "yellow", "green", "cyan", "blue", "magenta"]

    readonly property var themeHues: [
        pick(["red", "color1"], "#ff5345"),
        pick(["orange", "bright_yellow", "color3"], "#a2734b"),
        pick(["yellow", "color3"], "#e5c736"),
        pick(["green", "color2"], "#549e6a"),
        pick(["cyan", "color6"], "#2dd5b7"),
        pick(["blue", "color4"], "#509475"),
        pick(["magenta", "color5"], "#d2689c")
    ]

    // Circular variance of the theme's hues, weighted by saturation so a nearly
    // grey swatch cannot vote for a hue it does not really have. 1 means every
    // hue points the same way; 0 means they are spread right around the wheel.
    readonly property real hueConcentration: {
        let x = 0;
        let y = 0;
        let weight = 0;
        for (const c of themeHues) {
            const col = Qt.color(c);
            if (col.hslHue < 0)
                continue;
            const w = col.hslSaturation;
            const a = col.hslHue * 2 * Math.PI;
            x += Math.cos(a) * w;
            y += Math.sin(a) * w;
            weight += w;
        }
        return weight <= 0.001 ? 1 : Math.hypot(x, y) / weight;
    }

    readonly property real meanChroma: {
        let total = 0;
        for (const c of themeHues)
            total += Qt.color(c).hslSaturation;
        return total / Math.max(1, themeHues.length);
    }

    // A palette is "collapsed" when its accents no longer distinguish anything:
    // either they all point the same way on the wheel, or there is not enough
    // chroma for a hue to mean anything at all.
    readonly property bool collapsed: hueConcentration > 0.90 || meanChroma < 0.10

    // A theme with genuinely no chroma is a deliberate choice, and painting a
    // rainbow over it would be vandalism. Those get separated by lightness
    // alone; everything else gets the fan.
    readonly property bool achromatic: meanChroma < 0.06

    readonly property real anchorHue: {
        const a = Qt.color(accent);
        if (a.hslHue >= 0 && a.hslSaturation > 0.05)
            return a.hslHue;
        // Fall back to whichever theme hue carries the most chroma.
        let best = 0.58;
        let bestSat = 0;
        for (const c of themeHues) {
            const col = Qt.color(c);
            if (col.hslHue >= 0 && col.hslSaturation > bestSat) {
                bestSat = col.hslSaturation;
                best = col.hslHue;
            }
        }
        return best;
    }

    // Deliberately more saturated than the theme's own accent. A collapsed
    // palette is usually collapsed *and* muted, and a fan built at the theme's
    // own chroma comes out as seven pastels that are technically different and
    // practically identical — especially once the car art mixes them toward the
    // foreground. The floor is what keeps the roles legible at sprite size.
    readonly property real anchorSat: achromatic ? 0
        : Math.max(0.46, Math.min(0.80, Qt.color(accent).hslSaturation * 1.35))
    readonly property real anchorLight: isLight ? 0.44 : 0.62

    // Spread across a 120 degree arc — wide enough that neighbours are plainly
    // different, narrow enough that the whole set still reads as one family.
    function fanColor(index: int): color {
        const n = hueRoles.length;
        const span = 120 / 360;
        const step = n > 1 ? span / (n - 1) : 0;
        const h = (anchorHue - span / 2 + index * step + 1) % 1;

        // Alternating value so adjacent roles differ in lightness as well as
        // hue. On an achromatic theme this ramp is the only thing separating
        // them, so it widens to cover the full usable range.
        // The achromatic ramp needs the whole usable range: lightness is the
        // only axis it has, and seven roles will not fit inside the narrower
        // band the coloured fan uses without landing on top of each other.
        const lo = achromatic ? (isLight ? 0.12 : 0.22) : (isLight ? 0.24 : 0.36);
        const hi = achromatic ? (isLight ? 0.78 : 0.88) : (isLight ? 0.62 : 0.82);
        const l = achromatic
            ? lo + (hi - lo) * (index / Math.max(1, n - 1))
            : Math.max(lo, Math.min(hi, anchorLight * (index % 2 === 0 ? 1.24 : 0.72)));

        return Qt.hsla(h, anchorSat, l, 1);
    }

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

    // Resolved once for the whole palette, because a role's colour depends on
    // the roles before it: a theme is kept exactly as authored unless two of
    // its accents are close enough to be confused, and then only the second of
    // the pair moves.
    //
    // A wholly collapsed palette skips the repair and goes straight to the fan.
    // Repairing it pairwise would technically work but would produce seven
    // colours all nudged away from the same starting point, which looks like a
    // mistake rather than a scheme.
    readonly property var resolvedHues: {
        const out = [];
        for (let i = 0; i < hueRoles.length; i++) {
            if (collapsed) {
                out.push(fanColor(i));
                continue;
            }

            let c = Qt.color(themeHues[i]);
            for (let attempt = 0; attempt < 8; attempt++) {
                let worst = 99;
                for (const other of out)
                    worst = Math.min(worst, separation(c, other));
                if (worst >= minRoleSeparation)
                    break;

                // Try lightness first — it keeps the theme's hue intact — and
                // only then bend toward the role's slot on the fan.
                if (attempt < 3) {
                    const src = Qt.color(themeHues[i]);
                    const dir = (i % 2 === 0) ? 1 : -1;
                    const l = Math.max(0.20, Math.min(0.86,
                        src.hslLightness + dir * 0.11 * (attempt + 1)));
                    c = Qt.hsla(src.hslHue < 0 ? 0 : src.hslHue,
                                src.hslSaturation, l, 1);
                } else {
                    c = mix(c, fanColor(i), 0.45);
                }
            }
            out.push(c);
        }
        return out;
    }

    function roleColor(name: string): color {
        const i = hueRoles.indexOf(name);
        if (i < 0)
            return accent;
        return resolvedHues[i];
    }

    readonly property color red:     roleColor("red")
    readonly property color orange:  roleColor("orange")
    readonly property color yellow:  roleColor("yellow")
    readonly property color green:   roleColor("green")
    readonly property color cyan:    roleColor("cyan")
    readonly property color blue:    roleColor("blue")
    readonly property color magenta: roleColor("magenta")

    // The bright variants are a lift of the resolved role rather than the
    // theme's own bright_* keys, because on a collapsed palette those have
    // collapsed too — and a "bright" that is not brighter is worse than useless.
    function liftColor(c: color): color {
        return isLight ? Qt.darker(c, 1.32) : Qt.lighter(c, 1.32);
    }

    readonly property color brightRed:     collapsed ? liftColor(red)     : pick(["bright_red", "color9", "red", "color1"], "#db9f9c")
    readonly property color brightGreen:   collapsed ? liftColor(green)   : pick(["bright_green", "color10", "green"], "#63b07a")
    readonly property color brightYellow:  collapsed ? liftColor(yellow)  : pick(["bright_yellow", "color11", "yellow"], "#e5c736")
    readonly property color brightBlue:    collapsed ? liftColor(blue)    : pick(["bright_blue", "color12", "blue"], "#acd4cf")
    readonly property color brightMagenta: collapsed ? liftColor(magenta) : pick(["bright_magenta", "color13", "magenta"], "#75bbb3")
    readonly property color brightCyan:    collapsed ? liftColor(cyan)    : pick(["bright_cyan", "color14", "cyan"], "#8cd3cb")

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
        return readable(base, fill, 4.5);
    }

    function grade(a: color, b: color): string {
        const r = contrast(a, b);
        return r >= 7 ? "AAA" : r >= 4.5 ? "AA" : r >= 3 ? "AA-large" : "fail";
    }

    // Nudges a colour's lightness away from its background until it clears the
    // ratio, and no further. A theme that already passes is returned untouched,
    // which is the whole point: this corrects mistakes, it does not restyle.
    function readable(fg: color, bg: color, ratio: real): color {
        const src = Qt.color(fg);
        if (contrast(src, bg) >= ratio)
            return src;

        const up = relLuminance(bg) < 0.5;
        const hue = src.hslHue < 0 ? 0 : src.hslHue;
        const sat = src.hslHue < 0 ? 0 : src.hslSaturation;
        let l = src.hslLightness;

        for (let i = 0; i < 40; i++) {
            l = up ? Math.min(1, l + 0.025) : Math.max(0, l - 0.025);
            const c = Qt.hsla(hue, sat, l, 1);
            if (contrast(c, bg) >= ratio)
                return c;
        }
        return up ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1);
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
        path: root.colorsPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: this.reload()
    }

    FileView {
        id: nameFile
        path: root.namePath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: this.reload()
    }
}
