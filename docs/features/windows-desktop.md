# Windows 11 desktop parity

## Shared outcome

Build estimates and manage the same workshop libraries offline on Windows 11, with the Mac application's graphite sidebar, grouped forms, blue accent and live cost breakdown. Native Windows window chrome remains native.

## Implementation

- `windows/sharedLogic` compiles the existing Android BigDecimal pricing engine, document defaults and profile conversion/validation directly. These files have one implementation, not divergent copies.
- `windows/desktopApp` supplies desktop navigation, resizable quote panels, catalogs and editing dialogs. Detailed library/tool editors use desktop form rows and the same validation and fields as Android.
- Bundled resources come from `SharedSchemas/`, `Sources/QuoteData/SeedData/` and the corrected branding system.
- SQLite stores a transactional versioned workspace document. kotlinx.serialization validates the envelope and preserves unknown JSON fields. Quote snapshots and decimal precision are retained.
- Writable files live under `%LOCALAPPDATA%\PrintQuote3D`; installation files contain no mutable workshop data.
- Unified Materials, no excluded third-party provider integration. Jobs, Inventory and Analytics retain the current Mac placeholders.

## Acceptance evidence

Verified on 2026-09-14 in the user's Parallels Windows 11 VM (Windows ARM host running the x64 JDK/application):

- JDK 21 LTS, Kotlin 2.4.20, Compose Multiplatform 1.12.0, Gradle 9.3.1.
- `:sharedLogic:test :desktopApp:build :desktopApp:packageMsi :desktopApp:packageExe`: passed; 13 tests (10 shared Android parity tests and 3 SQLite/catalog adapter tests).
- Both installers built, final version 0.3.5. MSI installed with exit 0; installed executable launched in the signed-in user's desktop session using the bundled runtime.
- Installed app displays 1,007 printer profiles and 2,089 catalog products.
- New estimate displays fixture production cost 33.31 and total 55.52. Ctrl+N, Ctrl+S and Ctrl+O exercised using VM keyboard events.
- Saved quote persisted in SQLite. Actual MSI upgrades after separating the directories preserve the complete workspace, checked by comparing parsed database documents before and after the upgrade.
- Catalog product opened, 1.75 mm / 1,000 g black spool priced at 24.95/kg and saved through the GUI; its price and provenance persisted.
- Window resized from 1,100 × 800 to 850 × 600 logical pixels (200% display scaling); editor switches to a single scrolling column with Save visible. Corrected transparent logo, title icon and dark-theme scrollbar contrast inspected.
- `./pq check`: passed Apple Swift tests (28), macOS/iOS Simulator builds, Android JVM tests (13), build and lint. Workflow tests: 6 passed.

Installer binaries use `%LOCALAPPDATA%\PrintQuote3D-App`; data uses `%LOCALAPPDATA%\PrintQuote3D\database`. Early development packaging overlapped the data folder; actual upgrade testing caught and corrected it before publication.

This establishes working installed-app behavior on Parallels. It does not claim pixel-for-pixel identity with SwiftUI, physical Windows PC testing, all DPI settings, screen-reader acceptance, or every editor interaction. Windows uses native Windows chrome; the layout, palette and working feature scope follow the Mac app. Existing future-work placeholders remain placeholders. GitHub CI status is independent of these local results.
