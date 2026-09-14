# PrintQuote 3D for Android

Open this `android/` directory in Android Studio, allow Gradle sync, choose an emulator or connected Android device, and run `app`. Opening the repository root alone does not import the Android Gradle project. Install SDK Platform 37 and Build Tools 36.0.0 through SDK Manager if needed.

## Implemented features

- Dashboard, searchable saved quotes, and customer views derived from quote customer names.
- Editable estimates with a live detailed price breakdown. Phone layouts use Details/Price breakdown tabs; windows at least 800 dp wide show both columns.
- Material consumption, supports, interfaces, purge, towers, drying, electricity, machine time, maintenance, wear, labor, failure reserve, packaging, outside services, overhead, margin/markup, minimum charge, rush, discount, tax, and shipping.
- Tool configurations with 1–12 physical tools, separate feeder/material capacity, assignment roles and materials, activation waste/time, active/parked heater costs, tool maintenance, abrasive nozzle wear, and capability warnings.
- 1,007 seeded printer profiles: 1,004 catalog profiles plus three demonstration profiles. Search, review and edit imported profiles or add custom printers; hardware, usable build modes, sources and user overrides are retained.
- One Materials destination combines saved materials, manual stock/location, and the offline catalog: 2,089 products, 14,577 color variants and 22,355 spool sizes. Select a color/spool, enter your cost and save it for estimates. Catalog purchase links are references; prices are entered by the user.
- Editable pricing presets, business/currency/tax/electricity/expiration settings, source directory and pinned Orca technical profiles.
- Atomic private workspace storage. Quotes retain their own input, printer/material/preset and calculated-result snapshots. Updating a library record does not change previously saved quotes or consume stock automatically.

These cover the working Apple app workflows. Jobs and Analytics are placeholders in the Apple app and are not presented as finished Android features. Neither implementation currently provides STL/3MF parsing, a 3D viewer, PDF export, live pricing, cloud synchronization or production job scheduling.

## Shared data and behavior

`SharedSchemas/` remains authoritative. Gradle uses it directly for app assets and JVM test fixtures. The existing `Sources/QuoteData/SeedData/open_filaments_v2.json` is copied only into generated build assets alongside attribution/license files. No second catalog or schema has been introduced.

The Kotlin pricing engine follows the Swift calculation sequence and rounds currency using decimal arithmetic. The shared aggregate and tool fixtures are exercised by JVM tests. The catalog is streamed to build a small search index; only a selected product is retained for detail views.

Imported technical profiles need review and actual shop operating costs before quoting. Missing power data is not treated as a manufacturer-verified measurement. Local storage is separate from the Apple app; matching document keys does not imply cross-device synchronization.

## Toolchain and verification

Pinned to AGP 9.1.1, Gradle 9.3.1, built-in Kotlin 2.2.10, the matching Compose compiler and Compose BOM 2026.03.00. Use Android Studio's bundled JDK; this checkout was built with JDK 25 and API 37. AGP 9 supplies Kotlin, so do not also apply `org.jetbrains.kotlin.android`.

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest
# With an emulator or Android device running:
./gradlew :app:connectedDebugAndroidTest
```

The debug APK is `app/build/outputs/apk/debug/app-debug.apk`. Build outputs, IDE files and local SDK paths are ignored. The application ID is `local.printquote.android`.

The JVM suite covers the shared Swift fixtures, rounding and pricing order, invalid inputs, tool limits, catalog profile import, preservation of user overrides and quote snapshots, stock persistence and corrupt-storage protection. Instrumentation tests exercise quote editing/saving/reopening, complete library search, catalog detail and settings on an Android 17 ARM64 emulator. Physical-device testing remains separate.

Verified on 2026-09-13: debug APK build, all 13 JVM tests, both connected workflow tests on `PrintQuote_API_37` (Android 17 ARM64), and Android lint passed. The connected tests saved/reopened a quote across activity recreation, searched all printer/catalog records, saved a catalog spool, and edited business settings. Lint's remaining notices identify newer dependency versions; the tested versions remain pinned. Android Studio's graphical sync and physical phones/tablets were not separately verified.
