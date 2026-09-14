# PrintQuote branding

Artwork supplied by the project owner on September 14, 2026. Original PNGs are preserved with descriptive names; `manifest.json` maps each to its original filename.

- `wordmark-light.png`: dark lettering for light surfaces.
- `wordmark-dark.png`: light lettering for dark surfaces.
- `icon-dark.png`: selected primary app icon (the supplied (7) variant).
- `icon-light.png`, `icon-blue.png`, `icon-dimensional-alternate.png`: alternate artwork retained for future use; not in-app icon-switching options.
- `symbol.png`, `logo-stacked.png`, `logo-monochrome.png`: standalone brand variants.
- The four brand/icon/logo boards are design references, not app screenshots or claims of shipped features.

The README chooses a wordmark using the viewer's light/dark preference. Apple and Android use the same selected dark icon. Apple app resources include a macOS icon set and an opaque iOS icon; Android includes five launcher densities. The Apple sidebar and Android dashboard also display the mark.

Run `swift tools/export-branding.swift` from the repository root on macOS to rebuild platform-size PNGs and the Mac `.icns`. Exports preserve the artwork, resize for platform use, and supply a navy background for the opaque iOS export. Keep asset catalog Contents.json files alongside the images. Original artwork is never overwritten.

The public product/repository remains PrintQuote 3D; the supplied wordmark reads PrintQuote. No package or bundle identifiers were changed.
