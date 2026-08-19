pragma ComponentBehavior: Bound

import QtQuick

// Pooled screensaver-flavoured effects. Every weapon paints with the same
// vocabulary the Omarchy ttfx screensaver uses: falling glyphs and etched beams.
QtObject {
    id: fx

    property Item layer: null
    property Component glyphComponent: null
    property Component beamComponent: null

    property int glyphBudget: 420
    property int beamBudget: 28

    property var glyphPool: []
    property var beamPool: []
    property var activeGlyphs: []
    property var activeBeams: []

    readonly property var alphabet: ({
        binarypath: ["0", "1"],
        matrix: ["ｱ", "ｦ", "ﾘ", "ﾂ", "ﾈ", "0", "1", "7", "ﾊ", "ﾑ"],
        laseretch: ["/", "\\", "|", "─", "═", "┼"],
        fireworks: ["*", "✦", "+", "·", "✧", "◆"],
        blackhole: ["◌", "○", "·", "◦", "∘"],
        decrypt: ["#", "%", "&", "@", "$", "?"],
        colorshift: ["▓", "▒", "░"],
        highlight: ["▲", "△", "▴"]
    })

    function glyphFor(weapon: string): string {
        const set = alphabet[weapon] || alphabet.binarypath;
        return set[Math.floor(Math.random() * set.length)];
    }

    function reset(): void {
        for (const g of activeGlyphs) {
            g.visible = false;
            glyphPool.push(g);
        }
        for (const b of activeBeams) {
            b.visible = false;
            beamPool.push(b);
        }
        activeGlyphs = [];
        activeBeams = [];
    }

    function takeGlyph(): var {
        if (glyphPool.length > 0)
            return glyphPool.pop();
        if (activeGlyphs.length + 1 > glyphBudget || !layer || !glyphComponent)
            return null;
        return glyphComponent.createObject(layer, { visible: false });
    }

    function emit(x: real, y: real, opts: var): void {
        const g = takeGlyph();
        if (!g)
            return;
        const o = opts || {};
        g.x = x;
        g.y = y;
        g.vx = o.vx || 0;
        g.vy = o.vy || 0;
        g.drag = o.drag !== undefined ? o.drag : 1.4;
        g.life = o.life || 0.5;
        g.maxLife = g.life;
        g.text = o.text || "1";
        g.color = o.color || Theme.fgBright;
        g.font.pixelSize = o.size || 15;
        g.spin = o.spin || 0;
        g.rotation = o.rotation || 0;
        g.opacity = 1;
        g.visible = true;
        activeGlyphs.push(g);
    }

    // A shower of glyphs flying outward: impacts, deaths, explosions.
    function burst(x: real, y: real, count: int, color: color, speed: real, weapon: string, size: real): void {
        for (let i = 0; i < count; i++) {
            const a = Math.random() * Math.PI * 2;
            const s = speed * (0.35 + Math.random() * 0.9);
            emit(x, y, {
                vx: Math.cos(a) * s,
                vy: Math.sin(a) * s,
                life: 0.35 + Math.random() * 0.5,
                text: glyphFor(weapon),
                color: color,
                size: size || 15,
                spin: (Math.random() - 0.5) * 220
            });
        }
    }

    // Glyphs falling in the wake of a moving projectile.
    function trail(x: real, y: real, color: color, weapon: string, size: real): void {
        emit(x, y, {
            vx: (Math.random() - 0.5) * 26,
            vy: (Math.random() - 0.5) * 26,
            life: 0.28 + Math.random() * 0.22,
            text: glyphFor(weapon),
            color: color,
            size: size || 14,
            drag: 2.6
        });
    }

    // Glyphs spiralling into a singularity.
    function vortex(x: real, y: real, radius: real, color: color, count: int): void {
        for (let i = 0; i < count; i++) {
            const a = Math.random() * Math.PI * 2;
            const r = radius * (0.55 + Math.random() * 0.45);
            emit(x + Math.cos(a) * r, y + Math.sin(a) * r, {
                vx: -Math.cos(a) * r * 1.7,
                vy: -Math.sin(a) * r * 1.7,
                life: 0.55,
                text: glyphFor("blackhole"),
                color: color,
                size: 13,
                drag: 0.2,
                spin: 260
            });
        }
    }

    function beam(x1: real, y1: real, x2: real, y2: real, color: color, width: real): void {
        let b = beamPool.length > 0 ? beamPool.pop() : null;
        if (!b) {
            if (activeBeams.length + 1 > beamBudget || !layer || !beamComponent)
                return;
            b = beamComponent.createObject(layer, { visible: false });
        }
        b.place(x1, y1, x2, y2, color, width);
        b.life = 0.22;
        b.maxLife = 0.22;
        b.visible = true;
        activeBeams.push(b);

        // Etch marks along the beam, like laseretch scoring the canvas.
        const len = Math.hypot(x2 - x1, y2 - y1);
        const steps = Math.min(16, Math.max(3, Math.floor(len / 46)));
        for (let i = 1; i < steps; i++) {
            const t = i / steps;
            emit(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, {
                vx: (Math.random() - 0.5) * 90,
                vy: (Math.random() - 0.5) * 90,
                life: 0.3,
                text: glyphFor("laseretch"),
                color: color,
                size: 13
            });
        }
    }

    function update(dt: real): void {
        const gs = [];
        for (const g of activeGlyphs) {
            g.life -= dt;
            if (g.life <= 0) {
                g.visible = false;
                glyphPool.push(g);
                continue;
            }
            const decay = Math.max(0, 1 - g.drag * dt);
            g.vx *= decay;
            g.vy *= decay;
            g.x += g.vx * dt;
            g.y += g.vy * dt;
            if (g.spin !== 0)
                g.rotation += g.spin * dt;
            g.opacity = Math.min(1, g.life / g.maxLife * 1.6);
            gs.push(g);
        }
        activeGlyphs = gs;

        const bs = [];
        for (const b of activeBeams) {
            b.life -= dt;
            if (b.life <= 0) {
                b.visible = false;
                beamPool.push(b);
                continue;
            }
            b.opacity = b.life / b.maxLife;
            bs.push(b);
        }
        activeBeams = bs;
    }
}
