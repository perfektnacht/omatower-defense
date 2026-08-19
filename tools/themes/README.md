# Theme fixtures

Palettes that do not exist in Omarchy's shipped set but that Aether can
absolutely produce, kept here so `tools/dev.sh themecheck` grades them on any
machine rather than only on one where someone happens to have installed
something unusual.

| fixture | what it exercises |
|---|---|
| `aether-light` | `mode = "light"`, distinct hues. Every "darker" in the game has to become a "lighter". |
| `aether-mono-light` | light **and** monochromatic — the two hard cases at once. |
| `aether-greyscale` | zero chroma. Must separate roles by lightness alone rather than painting a rainbow over a deliberate choice. |
