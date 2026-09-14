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
