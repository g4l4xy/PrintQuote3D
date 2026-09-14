# Shared PrintQuote branding

Use the owner-supplied PrintQuote logo system in the GitHub README and native Apple/Android apps. Preserve original artwork and use the supplied dark (7) icon consistently.

- [x] Shared artwork stored with source filename mapping.
- [x] README light/dark wordmarks.
- [x] Apple app icon catalog and sidebar branding.
- [x] Android launcher densities and dashboard branding.
- [x] SwiftPM Mac packaging includes icon and UI resources.
- [x] Reproducible macOS asset export tool.

No quote schemas, pricing, identities or saved data change. Variant assets are available in the repository; runtime icon switching is not introduced.

Verification: platform builds and shared test suite results recorded with the delivery. Visual inspection covers the exported icon. Device launcher appearance and iPhone/iPad interactions require device-specific verification.

Delivery verification (2026-09-14): `./pq check` passed (28 Swift tests, macOS/iOS Simulator builds, 13 Android JVM tests and lint). Both Android connected workflow tests passed. `Scripts/build-app.sh` built and signed the branded Mac development package. All 13 original files match their source hashes; the iOS icon is RGB with no alpha channel.

## Placement and background correction

The original raster integration was replaced with deterministic geometric exports after reports of clipping and mismatched backgrounds. README wordmarks have identical view boxes and transparent theme-specific artwork. Headers use a transparent mark and native text. iOS uses one full-bleed background; Android uses adaptive layers with a safe inset; macOS uses a single rounded tile. The SwiftPM Mac header now loads its packaged PNG explicitly instead of treating a plain PNG as a named asset-catalog image. Android accent and system-bar colors match the dark branded interface.

Visual acceptance includes browser previews on light/dark surfaces and actual Mac/Android app captures. Original files remain archived unchanged.

Correction verification (2026-09-14): latest combined Apple/Android check passes. Android's two connected workflow tests passed after the header layout change. Browser light/dark previews and actual rebuilt Mac/Android dashboard captures were visually inspected. The Mac inspection exposed and verified the repair of the missing packaged PNG. Physical iPhone/iPad launcher appearance remains unverified.
