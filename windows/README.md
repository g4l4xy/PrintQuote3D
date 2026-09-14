# PrintQuote3D for Windows 11

The Windows desktop client lives alongside Apple and Android in this repository. Its graphite sidebar, grouped estimate editor and live blue price summary follow the Mac application. Windows retains its own window controls and keyboard conventions.

## Open and run

1. Clone the **whole repository**, then open `windows/` in Visual Studio Code or IntelliJ IDEA.
2. Install a **JDK 21 LTS** (Temurin is supported) and set `JAVA_HOME` to it. Git is needed for repository syncing. The installed app itself needs neither Java nor Git.
3. In a terminal inside `windows/`, run:

```powershell
.\gradlew.bat :desktopApp:run
```

You can also double-click `PrintQuote-Windows.cmd` for Run, Build installers, Install, and safe fast-forward Pull. Close the running app before rebuilding its installer.

## Build a distributable

Run these **on Windows**, not macOS:

```powershell
.\gradlew.bat :sharedLogic:test :desktopApp:build
.\gradlew.bat :desktopApp:packageMsi :desktopApp:packageExe
```

The packages appear in `desktopApp/build/compose/binaries/main/msi/` and `exe/`. Install the MSI, then open PrintQuote3D from Start or its desktop shortcut. The installer bundles a reduced Java runtime. Development builds are unsigned.

GitHub Actions builds both installer formats on `windows-latest`, tests the shared logic, installs the MSI and checks that the installed process remains running. Download the **PrintQuote3D-Windows** artifact from the repository's Actions tab. This CI process check complements actual interactive testing; it does not establish visual acceptance.

## Everyday use

- **Ctrl+N:** new estimate.
- **Ctrl+S:** save the current estimate or editing dialog.
- **Ctrl+O:** open the saved Quotes browser.
- **Ctrl+F:** focus the current library search.
- **Escape:** close a picker or editor.
- Use the sidebar to switch between the same workspaces as the Mac app.
- The estimate editor uses two columns in wide windows and a vertically scrolling layout when narrower. No fixed-width cost panel is allowed to escape the window.
- Materials combines your saved spools and the searchable offline catalog. Enter your own purchase price when importing a catalog size.
- Printer profiles include imported catalogs; review actual machine cost, power and tool configuration before quoting.
- Jobs, Inventory and Analytics remain the same future-work sections as the current Mac application.

## Storage and compatibility

The installer puts binaries under `%LOCALAPPDATA%\PrintQuote3D-App`, separate from the data directory. The writable database is `%LOCALAPPDATA%\PrintQuote3D\database\workspace.sqlite`. Keep the entire database directory together when backing up with the app closed. Do not store data under the installation directory. For an isolated test workspace, launch the JVM with `-Dprintquote.dataDir=<directory>`.

SQLite transactions persist a versioned JSON workspace envelope through kotlinx.serialization. Unknown fields, UUIDs, source metadata, decimal precision, stock and saved quote snapshots survive round trips. Existing corrupt or unsupported data causes a visible load error instead of being replaced by seed data. Quotes retain their original rates and snapshots when a library profile changes. Saving a quote does not consume stock.

This is **local storage**, not automatic device-to-device cloud sync. Git push/pull updates the application source, not private workshop data.

## One product, shared logic

`sharedLogic` compiles the existing Android `Documents.kt`, `PricingEngine.kt`, and `WorkspaceRepository.kt` directly. They contain no Android framework dependencies. Windows uses the same exact BigDecimal calculation order and profile validation, so an engine change reaches Android and Windows together. Swift has equivalent behavior checked against the same fixtures.

The Windows repository implementation is behind `WorkspaceStore`; SQLite is a persistence adapter. The desktop views are separate from pricing/storage. Catalog resources are bundled from their existing authoritative locations, without committing a second set of data files.

Pinned build versions are in `gradle/libs.versions.toml`: Kotlin 2.4.20 with its matching Compose compiler plugin, Compose Multiplatform 1.12.0, and JDK 21. The Gradle wrapper is committed. See the official [compatibility guide](https://kotlinlang.org/docs/multiplatform/compose-compatibility-and-versioning.html) and [native distribution documentation](https://kotlinlang.org/docs/multiplatform/compose-native-distribution.html) for packaging requirements.

Before publishing changes, run `./pq check` for Apple/Android and `./pq check --platform windows` with JDK 21 (or use the commands above on Windows). The GitHub Windows workflow owns MSI/EXE packaging. Installer binaries stay out of Git history.
