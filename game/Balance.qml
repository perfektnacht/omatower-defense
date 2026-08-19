pragma Singleton

import QtQuick
import Quickshell

// Data-driven configuration for the whole game. Nothing in here knows about
// rendering; the managers read it and the views only read the managers.
// Distances are logical field units, speeds are units per second.
Singleton {
    id: root

    readonly property int fieldW: 1600
    readonly property int fieldH: 900
    readonly property int slotSpacing: 96      // min gap between two parking slots
    readonly property int snapRadius: 78       // how close a click has to land on a slot

    // Car footprint, shared by the tower views and the placement ghost. The
    // Quattro is drawn in a fixed 104x54 space and then scaled down as a whole,
    // so the artwork keeps its proportions while the cars sit lighter on the
    // circuit; every placement number below stays in the unscaled space.
    readonly property int carW: 104
    readonly property int carH: 54
    readonly property real carScale: 0.84
    // Half the road, plus the car's own reach. A parked car rotates to aim, so
    // this has to clear its LENGTH, not its width, or a car pointed at the
    // circuit puts its nose over the kerb.
    readonly property int towerClearance: Math.round(trackWidth / 2)
                                          + Math.round(carW * carScale / 2) + 8

    readonly property int startCash: 400
    readonly property int startLives: 20

    // Calling a wave early pays this much per second of unused planning time.
    readonly property int earlyCallBonusPerSecond: 3
    readonly property int planningSeconds: 25

    // Past this wave the run stops being a script and becomes a treadmill:
    // health compounds every round and the fourth development tier unlocks.
    readonly property int prestigeWave: 30

    // Some cars are limited per run. Two service barges is a team; five is a
    // printing press, and the whole economy collapses into "buy more barges".
    readonly property var towerLimit: ({ barge: 2 })

    function limitFor(id: string): int {
        return towerLimit[id] !== undefined ? towerLimit[id] : -1;
    }

    // ---- damage types -----------------------------------------------------
    // The rock-paper-scissors layer: no single tower class clears everything.
    readonly property var damageTypes: ({
        data:  { label: "DATA",  hue: "accent",  note: "Bread and butter. Blocked by armour." },
        beam:  { label: "BEAM",  hue: "magenta", note: "Ignores armour entirely. Poor against swarms." },
        blast: { label: "BLAST", hue: "orange",  note: "Splash. Many enemies resist it." },
        field: { label: "FIELD", hue: "cyan",    note: "Slows and chips. Some enemies are immune." }
    })

    // A beam that pierces N targets for full damage is far stronger on a
    // circuit than the number suggests: every take walks the same racing line
    // in single file, so "up to five in a line" is very nearly always five.
    // Each successive target it punches through takes this much less, which
    // keeps the long-range single-target sniping the E2 is for while stopping
    // one car from clearing a whole convoy.
    readonly property real beamFalloff: 0.35

    // Damage the Nth target in a beam takes, N being 0-indexed.
    function beamShare(index: int): real {
        return Math.pow(1 - beamFalloff, Math.max(0, index));
    }

    readonly property var targetModes: [
        { id: "first",  label: "FIRST",  note: "Closest to the end of the route." },
        { id: "last",   label: "LAST",   note: "Furthest from the end." },
        { id: "strong", label: "STRONG", note: "Highest remaining health." },
        { id: "close",  label: "CLOSE",  note: "Nearest to this car." }
    ]

    // ---- towers -----------------------------------------------------------
    // weapon ids are ttfx screensaver effects.
    // role: "damage" | "economy" | "support"
    readonly property var towers: [
        {
            id: "q80",
            name: "Quattro 80",
            role: "damage",
            weapon: "binarypath",
            weaponName: "BINARYPATH",
            dmgType: "data",
            blurb: "Homing streams of ones and zeroes. Cheap, reliable, always correct.",
            hue: "accent",
            cost: 100,
            turnRate: 320,
            levels: [
                { dmg: 20, rate: 1.7, range: 250, splash: 0, slow: 0, maxTargets: 1, detect: false },
                { dmg: 36, rate: 2.0, range: 285, splash: 0, slow: 0, maxTargets: 1, detect: false, cost: 130,
                  note: "Heavier payload." },
                { dmg: 62, rate: 2.4, range: 320, splash: 0, slow: 0, maxTargets: 1, detect: true, cost: 260,
                  note: "Adds packet inspection: sees stealth." },
                { dmg: 118, rate: 2.9, range: 355, splash: 0, slow: 0, maxTargets: 2, detect: true, cost: 720,
                  note: "Works car. Twin streams, and it never misses a stealth run." }
            ]
        },
        {
            id: "s1",
            name: "Quattro S1",
            role: "damage",
            weapon: "matrix",
            weaponName: "MATRIX",
            dmgType: "data",
            blurb: "Short-range digital rain. Shreds swarms, useless against armour.",
            hue: "green",
            cost: 160,
            turnRate: 520,
            levels: [
                { dmg: 8, rate: 6.5, range: 185, splash: 0, slow: 0, maxTargets: 1, detect: false },
                { dmg: 13, rate: 8.0, range: 205, splash: 0, slow: 0.12, maxTargets: 1, detect: false, cost: 170,
                  note: "Rain drags targets down." },
                { dmg: 19, rate: 9.5, range: 225, splash: 0, slow: 0.20, maxTargets: 2, detect: false, cost: 330,
                  note: "Twin downpour hits two takes at once." },
                { dmg: 33, rate: 11.5, range: 250, splash: 0, slow: 0.28, maxTargets: 3, detect: false, cost: 820,
                  note: "Standing water. Three lanes of rain, and it drags hard." }
            ]
        },
        {
            id: "e2",
            name: "Sport Quattro E2",
            role: "damage",
            weapon: "laseretch",
            weaponName: "LASERETCH",
            dmgType: "beam",
            blurb: "Long etching beam. Ignores armour and sees through stealth, but it attenuates through a queue.",
            hue: "magenta",
            cost: 260,
            turnRate: 130,
            levels: [
                { dmg: 95, rate: 0.55, range: 720, splash: 0, slow: 0, maxTargets: 1, detect: true },
                { dmg: 165, rate: 0.65, range: 800, splash: 0, slow: 0, maxTargets: 1, detect: true, cost: 280,
                  note: "Tighter focus." },
                { dmg: 280, rate: 0.8, range: 900, splash: 0, slow: 0, maxTargets: 3, detect: true, cost: 520,
                  note: "Punches through three, weaker with every one it passes." },
                { dmg: 495, rate: 0.95, range: 1000, splash: 0, slow: 0, maxTargets: 5, detect: true, cost: 1320,
                  note: "Full-bore etch. Cuts the length of a straight, but the far end of the line barely feels it." }
            ]
        },
        {
            id: "rs",
            name: "Quattro RS",
            role: "damage",
            weapon: "fireworks",
            weaponName: "FIREWORKS",
            dmgType: "blast",
            blurb: "Lobbed shells bursting into sparks. Clears clumps, wasted on tanks that resist blast.",
            hue: "orange",
            cost: 300,
            turnRate: 200,
            levels: [
                { dmg: 48, rate: 0.8, range: 400, splash: 115, slow: 0, maxTargets: 6, detect: false },
                { dmg: 74, rate: 0.95, range: 440, splash: 135, slow: 0, maxTargets: 8, detect: false, cost: 320,
                  note: "Bigger burst radius." },
                { dmg: 112, rate: 1.1, range: 480, splash: 158, slow: 0, maxTargets: 12, detect: false, cost: 620,
                  note: "Airburst shells." },
                { dmg: 186, rate: 1.3, range: 525, splash: 186, slow: 0, maxTargets: 18, detect: false, cost: 1450,
                  note: "Grand finale. The whole clump goes up at once." }
            ]
        },
        {
            id: "bh",
            name: "Quattro Concept",
            role: "damage",
            weapon: "blackhole",
            weaponName: "BLACKHOLE",
            dmgType: "field",
            blurb: "Drags the discourse into a slow, dense singularity. Chip damage, heavy slow.",
            hue: "cyan",
            cost: 200,
            turnRate: 999,
            levels: [
                { dmg: 5, rate: 2.0, range: 210, splash: 210, slow: 0.35, maxTargets: 99, detect: true },
                { dmg: 10, rate: 2.5, range: 240, splash: 240, slow: 0.48, maxTargets: 99, detect: true, cost: 220,
                  note: "Denser core." },
                { dmg: 18, rate: 3.0, range: 275, splash: 275, slow: 0.60, maxTargets: 99, detect: true, cost: 430,
                  note: "Event horizon. Nothing leaves quickly." },
                { dmg: 32, rate: 3.5, range: 315, splash: 315, slow: 0.72, maxTargets: 99, detect: true, cost: 1050,
                  note: "Collapse. Everything inside is barely moving." }
            ]
        },
        {
            id: "barge",
            name: "Service Barge",
            role: "economy",
            weapon: "colorshift",
            weaponName: "COLORSHIFT",
            dmgType: "none",
            blurb: "Team support truck. Pays out at the end of every wave. Cannot shoot.",
            hue: "brightYellow",
            cost: 240,
            turnRate: 60,
            levels: [
                { dmg: 0, rate: 0, range: 0, splash: 0, slow: 0, maxTargets: 0, detect: false, income: 44 },
                { dmg: 0, rate: 0, range: 0, splash: 0, slow: 0, maxTargets: 0, detect: false, income: 88, cost: 240,
                  note: "Second service crew." },
                { dmg: 0, rate: 0, range: 0, splash: 0, slow: 0, maxTargets: 0, detect: false, income: 160, cost: 470,
                  note: "Full works team." },
                { dmg: 0, rate: 0, range: 0, splash: 0, slow: 0, maxTargets: 0, detect: false, income: 265, cost: 1150,
                  note: "Factory backing. Pays like a title sponsor." }
            ]
        },
        {
            id: "pace",
            name: "Pace Car",
            role: "support",
            weapon: "highlight",
            weaponName: "HIGHLIGHT",
            dmgType: "none",
            blurb: "Buffs every car in range and clears tower stuns. Deals no damage itself.",
            hue: "brightBlue",
            cost: 280,
            turnRate: 90,
            levels: [
                { dmg: 0, rate: 0, range: 230, splash: 0, slow: 0, maxTargets: 0, detect: false,
                  buffRate: 0.20, buffRange: 0.10, cleanse: true },
                { dmg: 0, rate: 0, range: 265, splash: 0, slow: 0, maxTargets: 0, detect: false,
                  buffRate: 0.35, buffRange: 0.16, cleanse: true, cost: 300, note: "Stronger tow." },
                { dmg: 0, rate: 0, range: 300, splash: 0, slow: 0, maxTargets: 0, detect: false,
                  buffRate: 0.55, buffRange: 0.24, cleanse: true, grantDetect: true, cost: 560,
                  note: "Shares packet inspection with everyone in range." },
                { dmg: 0, rate: 0, range: 345, splash: 0, slow: 0, maxTargets: 0, detect: false,
                  buffRate: 0.85, buffRange: 0.36, cleanse: true, grantDetect: true, cost: 1250,
                  note: "Safety car deployed. The whole sector runs to your pace." }
            ]
        }
    ]

    // ---- enemies ----------------------------------------------------------
    // Every one of these is a take somebody has actually posted about Omarchy.
    // resist values are fractional mitigation per damage type; 1.0 is immunity.
    readonly property var enemies: [
        {
            sprite: { form: "blob",  eyes: 2 },
            id: "notadistro", label: "not-a-distro", tagline: "\"it's just Arch with dotfiles\"",
            hp: 60, speed: 132, bounty: 12, leak: 1, armor: 0, radius: 19, hue: "fgDim",
            resist: ({}), traits: []
        },
        {
            sprite: { form: "worm",  eyes: 2 },
            id: "bashscript", label: "shell-script-slop", tagline: "\"the whole thing is shell scripts\"",
            hp: 46, speed: 172, bounty: 10, leak: 1, armor: 0, radius: 17, hue: "brightGreen",
            resist: ({}), traits: []
        },
        {
            sprite: { form: "blob",  eyes: 3, teeth: true },
            id: "bloated", label: "bloatware", tagline: "\"500 packages you never asked for\"",
            hp: 360, speed: 62, bounty: 32, leak: 2, armor: 4, radius: 31, hue: "orange",
            resist: ({ blast: -0.25 }), traits: [], note: "Big target: takes extra blast damage."
        },
        {
            sprite: { form: "ghost", eyes: 2, spikes: true },
            id: "ricing", label: "touch-grass", tagline: "\"ricing is a waste of a life\"",
            hp: 115, speed: 150, bounty: 16, leak: 1, armor: 1, radius: 21, hue: "magenta",
            resist: ({}), traits: []
        },
        {
            sprite: { form: "bug", eyes: 2, horns: true, armored: true, legs: 4 },
            id: "notforbeginners", label: "gatekeeper", tagline: "\"you still need to know Arch\"",
            hp: 200, speed: 102, bounty: 21, leak: 1, armor: 10, radius: 24, hue: "brightYellow",
            resist: ({}), traits: [], note: "Heavy armour. Beam ignores it."
        },
        {
            sprite: { form: "ghost", eyes: 1 },
            id: "hype", label: "influencer-slop", tagline: "\"pure influencer hype\"",
            hp: 72, speed: 198, bounty: 14, leak: 1, armor: 0, radius: 17, hue: "brightMagenta",
            resist: ({}), traits: []
        },
        {
            sprite: { form: "blob",  eyes: 2, horns: true, teeth: true },
            id: "curlbash", label: "curl-bash-yolo", tagline: "\"you pipe a script straight into bash\"",
            hp: 130, speed: 182, bounty: 19, leak: 3, armor: 2, radius: 20, hue: "red",
            resist: ({}), traits: [], note: "Costs three lives if it gets through."
        },
        {
            sprite: { form: "skull", eyes: 2 },
            id: "breaks", label: "syu-and-pray", tagline: "\"one -Syu and it's gone\"",
            hp: 215, speed: 112, bounty: 26, leak: 2, armor: 3, radius: 25, hue: "brightRed",
            resist: ({}), traits: ["split"], splitInto: "notadistro", splitCount: 2,
            note: "Splits into two on death. The halves pay nothing."
        },
        {
            sprite: { form: "bug",   eyes: 4, antennae: true, legs: 6 },
            id: "wheel", label: "nix-did-it-first", tagline: "\"NixOS already solved this\"",
            hp: 240, speed: 96, bounty: 29, leak: 2, armor: 4, radius: 26, hue: "cyan",
            resist: ({ field: 0.4 }), traits: ["regen"], regen: 24,
            note: "Regenerates. Resists field damage."
        },
        {
            sprite: { form: "blob",  eyes: 2, horns: true, teeth: true, armored: true },
            id: "omakase", label: "omakase-cult", tagline: "\"opinionated means you can't change it\"",
            hp: 430, speed: 88, bounty: 40, leak: 2, armor: 16, radius: 29, hue: "brightBlue",
            resist: ({ beam: 0.5 }), traits: [],
            note: "Armoured and beam-resistant. Blast it."
        },
        {
            sprite: { form: "ghost", eyes: 1, antennae: true },
            id: "telemetry", label: "cachy-is-better", tagline: "\"just run CachyOS, it benchmarks faster\"",
            hp: 150, speed: 168, bounty: 34, leak: 2, armor: 0, radius: 20, hue: "muted",
            resist: ({}), traits: ["stealth"],
            note: "STEALTH. Invisible to towers without packet inspection."
        },
        {
            sprite: { form: "blob",  eyes: 2, armored: true },
            id: "vcfunded", label: "reply-guy", tagline: "\"he's already typing\"",
            hp: 180, speed: 118, bounty: 30, leak: 2, armor: 2, radius: 24, hue: "yellow",
            resist: ({ data: 0.35 }), traits: ["shield"], shield: 220, shieldRegen: 45, shieldDelay: 3.5,
            note: "Regenerating shield. Needs burst damage, not chip."
        },
        {
            sprite: { form: "skull", eyes: 2, horns: true },
            id: "archbtw", label: "arch-btw", tagline: "\"just install Arch properly\"",
            hp: 260, speed: 128, bounty: 27, leak: 2, armor: 6, radius: 25, hue: "brightCyan",
            resist: ({ field: 1.0 }), traits: ["slowproof"],
            note: "Immune to FIELD damage and cannot be slowed."
        },
        {
            sprite: { form: "blob",  eyes: 4, horns: true, teeth: true, crown: true, legs: 4 },
            id: "nix", label: "THE-NIXPILL", tagline: "\"declarative or it didn't happen\"",
            hp: 3400, speed: 68, bounty: 340, leak: 6, armor: 20, radius: 44, hue: "brightCyan",
            resist: ({ blast: 0.35 }), traits: ["boss", "regen"], regen: 60,
            note: "BOSS. Armoured, regenerating, shrugs off blast."
        },
        // ---- the wave-30 trio, fought together --------------------------------
        {
            sprite: { form: "blob",  eyes: 6, spikes: true, teeth: true, crown: true, legs: 6 },
            id: "discourse", label: "THE-ALGORITHM", tagline: "\"nobody talks about the tech any more\"",
            hp: 6200, speed: 74, bounty: 420, leak: 8, armor: 14, radius: 50, hue: "brightRed",
            resist: ({ data: 0.3, blast: 0.3 }), traits: ["boss", "frontliner", "summon"],
            summonInto: "hype", summonEvery: 4.0, summonCount: 2,
            note: "FRONTLINER. Soaks the shots meant for what is behind it, and summons free hype."
        },
        {
            sprite: { form: "ghost", eyes: 3, horns: true, teeth: true, crown: true },
            id: "ragebait", label: "ENGAGEMENT-FARM", tagline: "\"engagement is the only metric\"",
            hp: 3000, speed: 82, bounty: 300, leak: 4, armor: 8, radius: 38, hue: "magenta",
            resist: ({ field: 0.5 }), traits: ["boss", "buffer"],
            stunEvery: 7.0, stunRadius: 320, stunSeconds: 2.6, hasteRadius: 300, hasteAmount: 0.35,
            note: "BUFFER. Stuns your cars and speeds up everything around it."
        },
        {
            sprite: { form: "skull", eyes: 2, spikes: true, crown: true },
            id: "uninstall", label: "DISTRO-HOPPER", tagline: "\"I wiped it after a week\"",
            hp: 1100, speed: 168, bounty: 260, leak: 10, armor: 0, radius: 34, hue: "red",
            resist: ({ beam: 0.4 }), traits: ["boss", "glasscannon"],
            note: "GLASS CANNON. Fragile, fast, and costs ten lives. Snipe it before it passes."
        }
    ]

    function tower(id: string): var {
        return towers.find(t => t.id === id) || null;
    }

    function enemy(id: string): var {
        return enemies.find(e => e.id === id) || null;
    }

    // The fourth tier exists from the start but stays locked until the run has
    // survived the prestige wave, so it is a reward for lasting rather than a
    // thing you buy your way to on wave 8.
    function maxLevel(): int {
        return 3;
    }

    function maxLevelAt(waveNumber: int): int {
        return waveNumber > prestigeWave ? 3 : 2;
    }

    // Total spent on a tower at `level` (0-indexed). Sell returns 70% of this.
    function investedIn(towerId: string, level: int): int {
        const def = tower(towerId);
        if (!def)
            return 0;
        let total = def.cost;
        for (let i = 1; i <= level; i++)
            total += def.levels[i].cost;
        return total;
    }

    function sellValue(towerId: string, level: int): int {
        return Math.floor(investedIn(towerId, level) * 0.7);
    }

    // ---- waves ------------------------------------------------------------
    // Pure data: [{ id, count, gap, delay }]. The WaveManager knows nothing else.
    readonly property var scriptedWaves: [
        [{ id: "notadistro", count: 8, gap: 0.85 }],
        [{ id: "notadistro", count: 10, gap: 0.7 }, { id: "bashscript", count: 5, gap: 0.5, delay: 3 }],
        [{ id: "bashscript", count: 14, gap: 0.45 }],
        [{ id: "notadistro", count: 12, gap: 0.5 }, { id: "bloated", count: 2, gap: 3.0, delay: 2 }],
        [{ id: "ricing", count: 10, gap: 0.6 }, { id: "hype", count: 8, gap: 0.35, delay: 5 }],
        [{ id: "bloated", count: 4, gap: 2.0 }, { id: "notforbeginners", count: 5, gap: 1.2, delay: 1 }],
        [{ id: "telemetry", count: 4, gap: 1.6 }, { id: "ricing", count: 10, gap: 0.5, delay: 3 }],
        [{ id: "curlbash", count: 12, gap: 0.6 }, { id: "hype", count: 14, gap: 0.3, delay: 3 }],
        [{ id: "breaks", count: 8, gap: 1.2 }, { id: "bloated", count: 4, gap: 2.5, delay: 2 }],
        [{ id: "nix", count: 1, gap: 1 }, { id: "hype", count: 16, gap: 0.35, delay: 4 }],
        [{ id: "vcfunded", count: 7, gap: 1.1 }, { id: "bashscript", count: 16, gap: 0.3, delay: 2 }],
        [{ id: "omakase", count: 6, gap: 1.5 }, { id: "telemetry", count: 5, gap: 1.2, delay: 4 }],
        [{ id: "archbtw", count: 9, gap: 0.9 }, { id: "breaks", count: 6, gap: 1.4, delay: 3 }],
        [{ id: "wheel", count: 8, gap: 1.1 }, { id: "curlbash", count: 12, gap: 0.5, delay: 4 }],
        [{ id: "omakase", count: 7, gap: 1.3 }, { id: "vcfunded", count: 8, gap: 0.9, delay: 2 },
         { id: "telemetry", count: 6, gap: 1.0, delay: 6 }]
    ]

    // Endless mode past the script. A boss lands every 10, the trio every 30.
    function wave(n: int): var {
        if (n <= scriptedWaves.length)
            return scriptedWaves[n - 1];

        const over = n - scriptedWaves.length;
        const pool = ["ricing", "notforbeginners", "curlbash", "breaks", "wheel",
                      "omakase", "bloated", "hype", "telemetry", "vcfunded", "archbtw"];
        const groups = [];
        const kinds = Math.min(3 + Math.floor(over / 4), 6);
        for (let i = 0; i < kinds; i++) {
            groups.push({
                id: pool[(over * 3 + i * 5) % pool.length],
                count: 6 + Math.floor(over * 1.3) + i * 2,
                gap: Math.max(0.20, 0.9 - over * 0.028),
                delay: i * 2.2
            });
        }
        if (n % 30 === 0) {
            // The trio archetype: frontliner, buffer, glass cannon, together.
            const reps = 1 + Math.floor(n / 60);
            groups.push({ id: "discourse", count: reps, gap: 8, delay: 2 });
            groups.push({ id: "ragebait", count: reps, gap: 8, delay: 4 });
            groups.push({ id: "uninstall", count: reps * 2, gap: 5, delay: 9 });
        } else if (n % 10 === 0) {
            groups.push({ id: "nix", count: 1 + Math.floor(over / 15), gap: 6, delay: 3 });
        }
        return groups;
    }

    // Takes get louder every week. Health ramps from wave 6 onward so a
    // defence that was comfortable ten waves ago stops being comfortable.
    // Linear growth lets a player simply out-buy the curve, because income is
    // linear too. The extra superlinear term from wave 15 is what eventually
    // makes a defence stop being good enough.
    //
    // Past the prestige wave a compounding term takes over. It is deliberately
    // gentle per round — about 4.5% — but it never stops, so no defence holds
    // an endless run forever; it only decides how far you get.
    function waveScale(n: int): real {
        const linear = n <= 5 ? 0 : (n - 5) * 0.10;
        const late = n <= 15 ? 0 : Math.pow(n - 15, 1.7) * 0.05;
        const base = 1.0 + linear + late;
        return n <= prestigeWave ? base : base * Math.pow(1.045, n - prestigeWave);
    }

    // Income has to LOSE ground to the difficulty curve. Bounties, wave bonuses
    // and barge payouts are all multiplied by this, so a kill on wave 30 pays
    // less than half what the same kill paid on wave 5. Without it, income and
    // threat both grow and the late game degenerates into "park one more car"
    // rather than "park the right car in the right bay".
    function incomeScale(n: int): real {
        return Math.max(0.40, 1 / (1 + Math.max(0, n - 5) * 0.05));
    }

    function bountyFor(def: var, n: int): int {
        return Math.max(1, Math.round(def.bounty * incomeScale(n)));
    }

    function waveBonus(n: int): int {
        return Math.round((45 + n * 8) * incomeScale(n));
    }

    function isBossWave(n: int): bool {
        return n % 10 === 0 || wave(n).some(g => (enemy(g.id) || { traits: [] }).traits.indexOf("boss") >= 0);
    }

    // ---- circuits ---------------------------------------------------------
    // Stylised real Grand Prix layouts. Control points are authored in a 0..100
    // square and splined into a smooth lap. A take that completes the lap and
    // crosses the start/finish line takes a life off you.
    property int circuitIndex: 0

    readonly property var circuits: [
        {
            id: "monza",
            name: "MONZA",
            country: "ITALY",
            nick: "The Temple of Speed",
            quarterTurn: true,
            blurb: "Enormous straights and heavy braking zones. Long sightlines suit range.",
            difficulty: "ROOKIE",
            width: 60,
            points: [
                { x: 14, y: 88, name: "START/FINISH" },
                { x: 14, y: 42 },
                { x: 16, y: 34, name: "Rettifilo" },
                { x: 23, y: 32 },
                { x: 25, y: 26 },
                { x: 33, y: 23, name: "Curva Grande" },
                { x: 46, y: 21 },
                { x: 57, y: 26 },
                { x: 63, y: 34 },
                { x: 65, y: 41, name: "Roggia" },
                { x: 60, y: 45 },
                { x: 65, y: 50 },
                { x: 71, y: 56, name: "Lesmo 1" },
                { x: 69, y: 63 },
                { x: 62, y: 65, name: "Lesmo 2" },
                { x: 55, y: 60 },
                { x: 40, y: 46 },
                { x: 36, y: 43, name: "Ascari" },
                { x: 31, y: 47 },
                { x: 36, y: 53 },
                { x: 50, y: 68 },
                { x: 60, y: 80 },
                { x: 63, y: 88, name: "Parabolica" },
                { x: 56, y: 95 },
                { x: 38, y: 97 },
                { x: 21, y: 94 },
                { x: 14, y: 88 }
            ]
        },
        {
            id: "silverstone",
            name: "SILVERSTONE",
            country: "UNITED KINGDOM",
            nick: "Home of British Motor Racing",
            blurb: "Fast and flowing, with a slow Arena loop. Rewards anything with reach.",
            difficulty: "ROOKIE",
            width: 56,
            points: [
                { x: 24, y: 78, name: "START/FINISH" },
                { x: 40, y: 78 },
                { x: 50, y: 74, name: "Abbey" },
                { x: 57, y: 66 },
                { x: 60, y: 57, name: "Village" },
                { x: 55, y: 50 },
                { x: 47, y: 51, name: "The Loop" },
                { x: 45, y: 59 },
                { x: 52, y: 66, name: "Aintree" },
                { x: 68, y: 74 },
                { x: 84, y: 79, name: "Brooklands" },
                { x: 92, y: 74 },
                { x: 90, y: 65, name: "Luffield" },
                { x: 80, y: 62 },
                { x: 72, y: 57, name: "Woodcote" },
                { x: 66, y: 48 },
                { x: 63, y: 37, name: "Copse" },
                { x: 55, y: 30 },
                { x: 46, y: 28, name: "Maggotts" },
                { x: 39, y: 22 },
                { x: 31, y: 21, name: "Becketts" },
                { x: 25, y: 26 },
                { x: 21, y: 34, name: "Chapel" },
                { x: 16, y: 44 },
                { x: 9, y: 55, name: "Stowe" },
                { x: 8, y: 66 },
                { x: 14, y: 75, name: "Club" },
                { x: 24, y: 78 }
            ]
        },
        {
            id: "spa",
            name: "SPA-FRANCORCHAMPS",
            country: "BELGIUM",
            nick: "Eau Rouge, Raidillon, Kemmel",
            quarterTurn: true,
            blurb: "A huge triangle through the Ardennes. The lap is long, so economy pays off.",
            difficulty: "PRO",
            width: 54,
            points: [
                { x: 16, y: 26, name: "START/FINISH" },
                { x: 27, y: 18 },
                { x: 34, y: 21, name: "La Source" },
                { x: 27, y: 27 },
                { x: 22, y: 33, name: "Eau Rouge" },
                { x: 29, y: 39, name: "Raidillon" },
                { x: 49, y: 51, name: "Kemmel" },
                { x: 67, y: 60 },
                { x: 77, y: 57, name: "Les Combes" },
                { x: 82, y: 49 },
                { x: 89, y: 55, name: "Malmedy" },
                { x: 91, y: 66 },
                { x: 82, y: 70, name: "Rivage" },
                { x: 74, y: 69 },
                { x: 70, y: 76, name: "Pouhon" },
                { x: 75, y: 85 },
                { x: 85, y: 88, name: "Fagnes" },
                { x: 89, y: 94 },
                { x: 78, y: 97, name: "Stavelot" },
                { x: 57, y: 93 },
                { x: 36, y: 81, name: "Blanchimont" },
                { x: 22, y: 65 },
                { x: 14, y: 45, name: "Bus Stop" },
                { x: 12, y: 33 },
                { x: 16, y: 26 }
            ]
        },
        {
            id: "suzuka",
            name: "SUZUKA",
            country: "JAPAN",
            nick: "The only figure-eight on the calendar",
            blurb: "The lap crosses itself. A car on the crossover covers two sections at once.",
            difficulty: "PRO",
            width: 50,
            points: [
                { x: 88, y: 58, name: "START/FINISH" },
                { x: 75, y: 62 },
                { x: 65, y: 63, name: "First Curve" },
                { x: 57, y: 59 },
                { x: 51, y: 53, name: "S Curves" },
                { x: 44, y: 51 },
                { x: 38, y: 45 },
                { x: 32, y: 43 },
                { x: 26, y: 37, name: "Degner" },
                { x: 17, y: 33 },
                { x: 9, y: 35, name: "Hairpin" },
                { x: 7, y: 43 },
                { x: 16, y: 47 },
                { x: 27, y: 53 },
                { x: 35, y: 61, name: "Spoon" },
                { x: 31, y: 71 },
                { x: 20, y: 73 },
                { x: 15, y: 65 },
                { x: 26, y: 60 },
                { x: 47, y: 38 },
                { x: 67, y: 20, name: "130R" },
                { x: 79, y: 16 },
                { x: 89, y: 23 },
                { x: 93, y: 35, name: "Casio Triangle" },
                { x: 89, y: 46 },
                { x: 88, y: 58 }
            ]
        },
        {
            id: "monaco",
            name: "MONACO",
            country: "MONTE CARLO",
            nick: "No room. None. Anywhere.",
            blurb: "Barriers everywhere, almost nowhere to park. Every placement must earn its space.",
            difficulty: "LEGEND",
            width: 42,
            points: [
                { x: 20, y: 84, name: "START/FINISH" },
                { x: 34, y: 87 },
                { x: 41, y: 83, name: "Ste Devote" },
                { x: 43, y: 74 },
                { x: 49, y: 61, name: "Beau Rivage" },
                { x: 58, y: 50 },
                { x: 64, y: 44, name: "Massenet" },
                { x: 73, y: 42, name: "Casino" },
                { x: 79, y: 47 },
                { x: 79, y: 55, name: "Mirabeau" },
                { x: 72, y: 59 },
                { x: 66, y: 63, name: "Fairmont" },
                { x: 68, y: 70 },
                { x: 75, y: 70 },
                { x: 84, y: 67, name: "Portier" },
                { x: 91, y: 74 },
                { x: 93, y: 84, name: "Tunnel" },
                { x: 85, y: 92 },
                { x: 74, y: 94, name: "Chicane" },
                { x: 69, y: 89 },
                { x: 63, y: 94 },
                { x: 53, y: 95, name: "Tabac" },
                { x: 46, y: 91 },
                { x: 43, y: 84, name: "Piscine" },
                { x: 37, y: 87 },
                { x: 34, y: 94 },
                { x: 27, y: 95, name: "Rascasse" },
                { x: 19, y: 94 },
                { x: 15, y: 89, name: "A. Noghes" },
                { x: 20, y: 84 }
            ]
        }
    ]

    readonly property var circuit: circuits[Math.min(circuitIndex, circuits.length - 1)]
    readonly property int trackWidth: circuit.width

    function selectCircuit(i: int): void {
        circuitIndex = Math.max(0, Math.min(i, circuits.length - 1));
    }

    // ---- track geometry ---------------------------------------------------
    // Catmull-Rom through the control points, so corners actually curve instead
    // of reading as a polygon.
    // Centripetal Catmull-Rom (alpha = 0.5). Uniform parameterisation overshoots
    // and self-intersects on tight chicanes like the Rettifilo or Rascasse;
    // centripetal does not.
    function splined(pts: var, samples: int): var {
        const n = pts.length;
        if (n < 2)
            return pts.map(p => Qt.point(p.x, p.y));

        const knot = (ti, a, b) => {
            const d = Math.hypot(b.x - a.x, b.y - a.y);
            return ti + Math.max(1e-4, Math.pow(d, 0.5));
        };

        const out = [];
        for (let i = 0; i < n - 1; i++) {
            const p0 = pts[Math.max(0, i - 1)];
            const p1 = pts[i];
            const p2 = pts[i + 1];
            const p3 = pts[Math.min(n - 1, i + 2)];

            const t0 = 0;
            const t1 = knot(t0, p0, p1);
            const t2 = knot(t1, p1, p2);
            const t3 = knot(t2, p2, p3);

            for (let k = 0; k < samples; k++) {
                const t = t1 + (t2 - t1) * (k / samples);
                const a1x = (t1 - t) / (t1 - t0) * p0.x + (t - t0) / (t1 - t0) * p1.x;
                const a1y = (t1 - t) / (t1 - t0) * p0.y + (t - t0) / (t1 - t0) * p1.y;
                const a2x = (t2 - t) / (t2 - t1) * p1.x + (t - t1) / (t2 - t1) * p2.x;
                const a2y = (t2 - t) / (t2 - t1) * p1.y + (t - t1) / (t2 - t1) * p2.y;
                const a3x = (t3 - t) / (t3 - t2) * p2.x + (t - t2) / (t3 - t2) * p3.x;
                const a3y = (t3 - t) / (t3 - t2) * p2.y + (t - t2) / (t3 - t2) * p3.y;

                const b1x = (t2 - t) / (t2 - t0) * a1x + (t - t0) / (t2 - t0) * a2x;
                const b1y = (t2 - t) / (t2 - t0) * a1y + (t - t0) / (t2 - t0) * a2y;
                const b2x = (t3 - t) / (t3 - t1) * a2x + (t - t1) / (t3 - t1) * a3x;
                const b2y = (t3 - t) / (t3 - t1) * a2y + (t - t1) / (t3 - t1) * a3y;

                out.push(Qt.point(
                    (t2 - t) / (t2 - t1) * b1x + (t - t1) / (t2 - t1) * b2x,
                    (t2 - t) / (t2 - t1) * b1y + (t - t1) / (t2 - t1) * b2y));
            }
        }
        out.push(Qt.point(pts[n - 1].x, pts[n - 1].y));
        return out;
    }

    readonly property int padX: 104
    readonly property int padY: 86

    // Each circuit is authored freehand, so fit its bounding box to the field
    // rather than trusting the author to use the full 0..100 square.
    // Circuit maps get printed at whatever orientation fits the page, so tall
    // layouts are turned a quarter turn to sit in a 16:9 field.
    readonly property var circuitPoints: {
        const pts = circuit.points;
        if (!circuit.quarterTurn)
            return pts;
        return pts.map(p => ({ x: 100 - p.y, y: p.x, name: p.name }));
    }

    readonly property var fit: {
        const pts = circuitPoints;
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (const p of pts) {
            minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x);
            minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y);
        }
        const w = Math.max(1, maxX - minX);
        const h = Math.max(1, maxY - minY);
        const availW = fieldW - 2 * padX;
        const availH = fieldH - 2 * padY;

        // Fill the field, but never stretch a circuit past this much distortion.
        const maxStretch = 1.35;
        const uniform = Math.min(availW / w, availH / h);
        const sx = Math.min(availW / w, uniform * maxStretch);
        const sy = Math.min(availH / h, uniform * maxStretch);

        return {
            minX: minX, minY: minY, sx: sx, sy: sy,
            ox: padX + (availW - w * sx) / 2,
            oy: padY + (availH - h * sy) / 2
        };
    }

    function toField(p: var): var {
        return Qt.point(fit.ox + (p.x - fit.minX) * fit.sx,
                        fit.oy + (p.y - fit.minY) * fit.sy);
    }

    readonly property var track: splined(circuitPoints, 9).map(p => toField(p))

    // Fits any circuit into an arbitrary box, for the little maps on the
    // circuit picker cards.
    function previewTrack(index: int, w: real, h: real, pad: real): var {
        const c = circuits[Math.max(0, Math.min(index, circuits.length - 1))];
        const raw = c.quarterTurn
            ? c.points.map(p => ({ x: 100 - p.y, y: p.x }))
            : c.points;
        const pts = splined(raw, 5);

        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (const p of pts) {
            minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x);
            minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y);
        }
        const bw = Math.max(1, maxX - minX);
        const bh = Math.max(1, maxY - minY);
        const s = Math.min((w - 2 * pad) / bw, (h - 2 * pad) / bh);

        return pts.map(p => Qt.point(
            pad + (w - 2 * pad - bw * s) / 2 + (p.x - minX) * s,
            pad + (h - 2 * pad - bh * s) / 2 + (p.y - minY) * s));
    }

    readonly property var segments: {
        const segs = [];
        let acc = 0;
        const tr = track;
        for (let i = 0; i < tr.length - 1; i++) {
            const a = tr[i];
            const b = tr[i + 1];
            const dx = b.x - a.x;
            const dy = b.y - a.y;
            const len = Math.hypot(dx, dy);
            if (len < 0.0001)
                continue;
            segs.push({ ax: a.x, ay: a.y, dx: dx, dy: dy, len: len, start: acc,
                        angle: Math.atan2(dy, dx) * 180 / Math.PI });
            acc += len;
        }
        return segs;
    }

    readonly property real trackLength: {
        const s = segments;
        return s.length === 0 ? 1 : s[s.length - 1].start + s[s.length - 1].len;
    }

    function pointAt(d: real): var {
        const segs = segments;
        const clamped = Math.max(0, Math.min(d, trackLength));
        let lo = 0;
        let hi = segs.length - 1;
        while (lo < hi) {
            const mid = (lo + hi + 1) >> 1;
            if (segs[mid].start <= clamped) lo = mid; else hi = mid - 1;
        }
        const s = segs[lo];
        const t = s.len === 0 ? 0 : (clamped - s.start) / s.len;
        return { x: s.ax + s.dx * t, y: s.ay + s.dy * t, angle: s.angle };
    }

    // ---- parking slots ------------------------------------------------------
    // Cars go in fixed bays laid out along both sides of the circuit rather than
    // anywhere the player clicks. Free placement could always be defeated by a
    // car rotating its nose over the kerb; a bay that was generated clear of the
    // road stays clear at every angle.
    readonly property var slots: {
        const out = [];
        const clearance = towerClearance;
        const step = 78;

        for (let d = 0; d < trackLength; d += step) {
            const p = pointAt(d);
            const rad = p.angle * Math.PI / 180;
            // perpendicular to the racing line
            const nx = -Math.sin(rad);
            const ny = Math.cos(rad);

            for (const side of [-1, 1]) {
                for (let ring = 0; ring < 3; ring++) {
                    const off = clearance + 10 + ring * slotSpacing;
                    const sx = p.x + nx * off * side;
                    const sy = p.y + ny * off * side;

                    if (sx < 70 || sy < 70 || sx > fieldW - 70 || sy > fieldH - 70)
                        continue;
                    // A perpendicular offset can land on a different part of the
                    // lap, so every candidate is re-checked against the whole route.
                    if (distanceToTrack(sx, sy) < clearance)
                        continue;

                    let clash = false;
                    for (const o of out) {
                        if (Math.hypot(o.x - sx, o.y - sy) < slotSpacing) {
                            clash = true;
                            break;
                        }
                    }
                    if (clash)
                        continue;

                    out.push({ id: out.length, x: sx, y: sy });
                }
            }
        }
        return out;
    }

    function distanceToTrack(px: real, py: real): real {
        let best = Infinity;
        for (const s of segments) {
            let t = ((px - s.ax) * s.dx + (py - s.ay) * s.dy) / (s.len * s.len);
            t = Math.max(0, Math.min(1, t));
            const d = Math.hypot(px - (s.ax + s.dx * t), py - (s.ay + s.dy * t));
            if (d < best) best = d;
        }
        return best;
    }
}
