# PrintQuote branding

The original 13 owner-supplied images are archived unchanged. `manifest.json` maps their descriptive filenames to the original uploads. Reference boards are design concepts, not screenshots of shipped features.

## Production assets

The initial raster exports had irregular transparency, excessive padding and inconsistent backgrounds. Production branding now uses clean geometric paths in `geometry.json`, preserving the hexagon, nozzle/cube and layered-print motif.

Run `swift tools/export-branding.swift` from the repository root on macOS to rebuild all production assets. One geometry source drives:

- Equal-size transparent light/dark SVG wordmarks for the README. Text stays crisp, and there is no background rectangle to mismatch GitHub themes.
- A transparent, high-contrast mark for dark app headers. In-app branding uses this mark, not an app-icon tile.
- A full-bleed opaque iOS icon; iOS applies the outside mask.
- macOS icons with one inset rounded background, plus the packaged `.icns`.
- Android adaptive foreground/background layers with the symbol inside the safe area, plus legacy launcher sizes.

The app headers use native text with explicit spacing and room to wrap. The supplied raster wordmarks and glossy tiles remain reference assets; do not wire them back into production layouts.

Original assets include `wordmark-light.png`, `wordmark-dark.png`, `icon-dark.png`, alternate icon variants, standalone logo variants and four reference boards. Alternate icons are not runtime icon-switching options. The app/repository name remains PrintQuote 3D; package and bundle identifiers are unchanged.
