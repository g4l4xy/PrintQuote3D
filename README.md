<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/branding/generated/wordmark-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="assets/branding/generated/wordmark-light.svg">
  <img alt="PrintQuote — Real parts. Real prices. Faster." src="assets/branding/generated/wordmark-light.svg" width="780">
</picture>

# PrintQuote 3D

### Your printer makes the part. Make sure the quote makes sense.

**Native print estimating for Mac, iPhone, iPad, Android, and Windows 11.**

Turn filament, machine time, tool changes, labor, and the little costs that love to hide into a price you can explain.

**[Get started](#-pick-your-platform)** · **[Explore the features](#-meet-your-workshop)** · **[Understand the math](#-what-goes-into-a-quote)** · **[Build both apps](#-one-repository-both-apps)** · **[Current limits](#-what-isnt-finished-yet)**

</div>

---

## 👋 Hello, actual printing costs

A spool price and a stopwatch are a start. They are not the whole invoice.

There are supports that become trash, purge that never becomes a part, electricity, worn nozzles, setup time, packaging, and the occasional print that decides to become modern art at 3 a.m.

**PrintQuote 3D brings those costs into one estimate.** Choose your equipment and material, enter your print inputs, adjust your pricing rules, and inspect the breakdown before saving the quote. Use a straightforward aggregate estimate for a simple job, or assign materials to individual tools when the machine gets more interesting.

The project includes native Apple, Android and Windows desktop apps, a shared data contract, bundled reference catalogs, and matching pricing fixtures. Your workshop data is stored locally on each device.

> **Project status:** working development apps with automated pricing and persistence tests. This repository is the source-and-build distribution; signed app-store releases and automatic installed-app updates are not implemented.

## ✨ The short tour

| What you get | What it does |
| --- | --- |
| 🧮 Detailed estimates | Account for material, machine time, labor, waste, overhead, and customer pricing rules. |
| 🧵 One Materials workspace | Keep your saved spools, costs, stock, and catalog browsing together. |
| 🖨️ 1,007 starting printer profiles | Browse 1,004 catalog profiles plus three demonstration profiles; add your own equipment too. |
| 🔧 1–12 physical tools | Model toolheads, feeders, switching waste, heater costs, and wear separately. |
| 📚 Saved quote snapshots | Reopen quotes with their original inputs, equipment, material, and calculated prices. |
| 🎛️ Reusable presets | Keep common pricing settings ready for the next estimate. |
| 📱 Native interfaces | SwiftUI on Apple; Kotlin/Compose on Android and Windows desktop. |
| 🛠️ One development workflow | Pull, check, and push both implementations from the same repository. |

## 🚀 Pick your platform

Clone the **whole repository** so the shared schemas and bundled catalogs stay with the apps:

```sh
git clone https://github.com/g4l4xy/PrintQuote3D.git
cd PrintQuote3D
```

| Platform | Minimum app target | Open this |
| --- | --- | --- |
| macOS | macOS 14 | `PrintQuote3D.xcodeproj` in Xcode |
| iPhone | iOS 17 | The same Xcode project; choose an iPhone destination |
| iPad | iPadOS 17 | The same Xcode project; choose an iPad destination |
| Android | Android 8 / API 26 | The **`android/` folder** in Android Studio |
| Windows | Windows 11, x64 app (also runs under Windows ARM emulation) | **`windows/`** in VS Code or IntelliJ; install the MSI to use the app |

Minimum deployment targets describe intended compatibility. They do not mean every OS version or device has been interaction-tested.

### 🍎 Mac, iPhone, and iPad

1. Open **`PrintQuote3D.xcodeproj`** in Xcode.
2. Select the **PrintQuote3D** scheme.
3. Choose **My Mac**, an iPhone simulator, an iPad simulator, or a connected device.
4. Press **⌘R**.

For a physical iPhone or iPad, select your development team under **Signing & Capabilities**. Install a simulator runtime in Xcode if your desired destination is missing.

The checked-in Xcode project is ready to open; you do not need XcodeGen for normal development. The shared Swift package is local, and the catalogs are bundled. This is a native macOS app, not a Catalyst wrapper.

To build and package the Mac development app from Terminal:

```sh
swift test
./Scripts/build-app.sh
open 'PrintQuote 3D.app'
```

The packaging script includes resources and license notices and signs the development app ad hoc. Distribution signing and notarization are separate work. The Apple toolchain has been verified with Xcode 27.0 / Swift 6.4 on Apple Silicon.

→ [Xcode setup and device notes](OPEN_IN_XCODE.md)

### 🤖 Android

1. Open the repository's **`android/` directory** in Android Studio.
2. Allow Gradle sync to finish.
3. Install **SDK Platform 37** and **Build Tools 36.0.0** if prompted.
4. Choose an emulator or connected Android device.
5. Run the **`app`** configuration.

Opening only the repository root may leave Run disabled because Android Studio has not imported the Android Gradle project.

The project pins Gradle 9.3.1, Android Gradle Plugin 9.1.1, built-in Kotlin 2.2.10, and Compose BOM 2026.03.00. Use Android Studio's bundled JDK; validation used JDK 25.

```sh
cd android
./gradlew :app:assembleDebug :app:testDebugUnitTest
```

The installable debug APK is generated at:

```text
android/app/build/outputs/apk/debug/app-debug.apk
```

→ [Android setup, architecture, and verification](android/README.md)

### 🪟 Windows 11

Install the MSI from the **Windows desktop** GitHub Actions artifact, or open `windows/` in VS Code with JDK 21 and run `.\gradlew.bat :desktopApp:run`. Double-click `windows/PrintQuote-Windows.cmd` for run, build, install and safe pull shortcuts. The MSI bundles Java.

Windows uses the Mac-style graphite sidebar, grouped estimate fields and live cost breakdown, with local SQLite storage and the same 1,007 printer profiles and 2,089-product material catalog.

→ [Windows setup, installer build, shortcuts and storage](windows/README.md)

## 🏭 Meet your workshop

### Dashboard, quotes, and customers

Start an estimate, revisit saved quotes, and find the equipment and materials you use. Customer views are derived from the customer names on saved quotes; they are not a separate CRM.

A quote includes project and customer details, status, expiry, notes, currency, manufacturing inputs, and the calculated result. Each quote represents **one manufacturing estimate with aggregate labor**.

Saved quotes keep snapshots of the selected printer, material, preset when applied, inputs, and calculation. Editing a library record does not silently reprice a previously saved quote.

### 🧵 Materials: one home for the spool situation

The **Materials** destination combines two views:

- **My Inventory:** your saved products, actual cost per kilogram, spool dimensions, source information, and optional stock quantities, remaining grams, location, and notes.
- **All Filaments** (opens by default): the bundled Open Filament Database, indexed at the individual color/spool level. Search manufacturer, product, material, color, SKU and source tags; combine manufacturer/material filters, favorites and recently used selections.

The bundled snapshot contains:

| Catalog level | Count |
| --- | ---: |
| Products | **2,089** |
| Color variants | **14,577** |
| Spool sizes | **22,355** |

Choose a product, color, and spool size, enter **your purchase cost**, and save it for estimates. You can also create a manual material when you need something custom or have verified dimensions the catalog does not supply.

**Where did the other filaments go?** Previous versions opened the three saved sample spools, while the full catalog lived behind a second tab. V4 opens the real catalog and shows matching/total counts. Your inventory still means spools you have actually saved.

Search is debounced and paginated (100 rows at a time). Apple uses a durable SQLite/FTS index; Android and Windows stream the bundled source into repository-level token indexes on background workers. The Data & Pricing Sources page shows discovered, decoded, normalized, rejected, inserted, updated and duplicate counts, quarantine reasons, cancel/rebuild controls and a diagnostic export.

Material editors preserve imported values alongside separate user overrides. Per-system feeder compatibility stays **Unknown / not verified** unless source data or your override supplies an answer. Prices remain your entered purchase costs.

Purchase links are references, not live prices. Catalog records retain source metadata and provenance. Saving a quote does **not** automatically subtract filament from stock.

### ⌨️ V4: fewer clicks, more confidence

Open **Search & Commands** with **⌘K** on Mac, **Ctrl+K** on Windows, or the Search action on mobile. Find saved workshop records, jump to the full filament search, create an estimate, import STL/3MF, open settings or rebuild catalog data. Desktop shortcuts also cover new quotes, save, import and search.

Quotes now show **Saving… / Saved / Save failed**, with an 800 ms debounce and separate atomic recovery journals. Relaunch offers **Restore** or **Discard** for recovered drafts. A failed save is visible; existing quotes are not silently replaced by a recovered draft. Favorites and recent selections help bring familiar library records forward. Desktop context menus include open, favorite and duplicate actions.

Switch filament and printer libraries between **Cards** and **Table**. Save column visibility, ordering and widths, or edit inventory price, remaining grams, nickname and notes directly in the table. Picker groups bring recent spools and favorites forward. Price sorting uses your saved costs; missing difficulty/drying data remains unknown. Printer quick actions start an estimate with that configuration already selected.

See the [V4 implementation and verification record](docs/features/v4-usability.md) for exact coverage and remaining acceptance work. Build checks do not establish phone, tablet or keyboard interaction acceptance.

### 🖨️ Printers: bring the machine, then bring its real costs

The initial library includes **1,007 profiles**:

- **1,001 Orca-derived printer model/nozzle configurations**.
- **3 manufacturer-sourced supplemental configurations**.
- **3 demonstration profiles**.

These are profile/configuration records, not 1,007 unique physical printer models. The Orca collection covers **383 model/configuration names across 64 vendors**.

Search the library, review an imported profile, edit your equipment, or add a custom machine. Printer configuration covers build dimensions, average operating power, machine and maintenance rates, tools, and source information. Hardware fields include mode-specific usable volumes, circular beds, thermal limits, power-quality metadata, and accessory notes.

**A technical profile is a starting point for a quote.** Enter your actual shop costs and review unconfirmed capabilities. A manufacturer's maximum power rating is not the same as measured average printing power. Recording an accessory does not automatically configure its tool or material-switching effects.

### 🔧 More tools, more interesting math

PrintQuote separates concepts that are easy to mix up:

| Concept | Meaning |
| --- | --- |
| Physical toolhead | An actual configured tool/nozzle assembly; **1–12 supported** |
| Filament input | An available material input |
| Feeder slot | A selectable feeder position |
| Simultaneous tool use | How many tools can operate at once |
| Automatic material selection | How many materials the configured system can select automatically |

Architecture choices include single-tool, shared-nozzle switching, IDEX, dual-extruder, fixed multi-nozzle, toolchanger, mixing-hotend, and custom systems.

Tool assignments describe material, role, tool index, optional feeder slot, grams, price, active hours, and activation count. The calculation can account for change time, purge and wipe waste, additional heater energy, parked heaters where applicable, tool maintenance, and abrasive nozzle wear. Capability and configuration warnings help flag assumptions that need review.

In tool-assignment mode, use **base print hours excluding change time**. Tool active hours drive tool-specific costs and must fit the configured print-time capacity. Avoid counting the same heater or maintenance expense in both the machine-level and tool-level rates.

### 🎛️ Presets and workshop defaults

Save pricing presets for repeatable settings, and configure business name, currency, electricity rate, tax, and quote validity. New estimates use relevant defaults; saved quotes keep their recorded values.

Rates are decimal fractions: **`0.40` means 40%**, and **`0.08` means 8%**.

## 🧮 What goes into a quote?

The breakdown follows the costs from raw material to customer total:

| Layer | Included inputs |
| --- | --- |
| Material | Model, supports, support interface, purge/flush, prime tower, and startup waste |
| Machine | Printing electricity, machine time, maintenance, and consumable wear |
| Preparation | Drying power, drying time, and the number of jobs sharing that drying cost |
| Tools | Applicable change time/waste, heater energy, maintenance, and nozzle wear |
| People | Labor minutes and hourly labor rate |
| Risk and direct costs | Manufacturing failure reserve, packaging, outside services, and other direct costs |
| Pricing | Overhead, material multiplier, margin or markup, minimum charge, and rush multiplier |
| Final adjustments | Discount, tax, and shipping |

The failure reserve is applied to manufacturing costs, including labor, before packaging and outside services. Pricing then follows this order:

```text
Production cost
  + overhead
  + material-multiplier adjustment
  → margin OR markup
  → minimum charge
  → rush multiplier
  → rounded subtotal
  − discount
  + tax on the discounted subtotal
  + shipping
  = customer total
```

**Margin and markup are different.** The shared standard fixture produces a **$33.31 production cost** and a **$55.52 customer total** with its 40% target margin. Applying 40% markup to that fixture produces **$46.63** instead. This is a reproducible test example, not a recommended rate for every shop.

Swift uses Decimal arithmetic; Kotlin uses BigDecimal. Shared fixtures check expected results across the implementations, including multi-tool cases.

→ [Full pricing contract](docs/pricing-engine.md)

## 🧭 Your first quote, from spool to saved

1. **Review a printer.** Choose a profile, verify its capabilities, and enter realistic operating rates.
2. **Save a material.** Browse the catalog or create a manual record; enter the cost you actually paid.
3. **Create an estimate.** Add a project name, customer, and relevant quote details.
4. **Enter the print inputs.** Use aggregate slicer totals, or switch to material-to-tool assignments for a more detailed job.
5. **Review the breakdown.** Check labor, waste, pricing rules, and any tool warnings.
6. **Save the quote.** Reopen it from Quotes with its recorded inputs and price snapshot.

Wide windows can show estimate details and costs together. Narrow layouts use **Details** and **Price breakdown** tabs so the numbers remain usable on smaller screens.

## 🔄 One repository, both apps

A feature should not disappear just because you picked up a different device.

Double-click **`PrintQuote Workflow.command`** on a Mac for a menu with status, pull, combined checks, push, and feature creation. Or use the repository-root commands:

```sh
# Inspect branch and local edits
./pq status

# Download updates for both apps
./pq pull

# Build and test Apple and Android concurrently
./pq check

# Commit and upload explicitly selected paths
./pq push -m "Improve estimates on both platforms" -- Sources android SharedSchemas docs

# Or deliberately include all non-ignored edits
./pq push --all -m "Describe the update"
```

Pull requires a clean checkout and uses fast-forward updates. Push preserves pre-existing staged selections by stopping rather than silently including them. Neither command force-pushes or discards local work.

**Source sync is not quote sync or app installation.** Each clone needs its own pull, each installed app needs a rebuild/run, and each device keeps its own workshop data.

### Add a feature across Apple, Android and Windows

```sh
./pq feature quote-pdf-export "Export a customer quote as PDF"
```

This example creates a branch and specification; it does **not** implement PDF export.

The feature template tracks shared behavior, data compatibility, Swift/SwiftUI work, Kotlin/Compose work, matching tests, and interaction verification. Keep both implementations on the same feature branch, run the combined check, and publish the completed change for review.

For coding assistants, [AGENTS.md](AGENTS.md) establishes the cross-platform conventions. GitHub feature-issue and pull-request templates keep both platforms visible during review.

→ [Complete development workflow](docs/development-workflow.md)

## 🧱 Under the hood

```text
PrintQuote3D/
├── Sources/
│   ├── QuoteDomain/          # Swift models and pricing rules
│   ├── QuoteData/            # Apple persistence and bundled catalogs
│   ├── PrintQuoteApp/        # SwiftUI application
│   └── OrcaProfiles/         # Upstream profile normalization
├── android/                 # Native Kotlin/Compose application
├── SharedSchemas/           # Shared contracts, catalogs and pricing fixtures
├── Tests/                   # Swift and workflow tests
├── tools/                   # Importers and development workflow
├── Scripts/                 # Mac app packaging
├── docs/                    # Specifications and implementation guides
└── ThirdParty/              # Upstream license notices
```

Apple uses local SwiftData persistence. Android writes its workspace atomically to private app storage. Windows stores a versioned workspace in transactional SQLite under `%LOCALAPPDATA%\PrintQuote3D`. Android and Windows stream the large filament catalog into background token indexes and retain a selected product for its detail view. Apple keeps catalog search in a separate SQLite index, alongside the SwiftData workshop.

Common JSON contracts and fixtures keep the native implementations aligned. Android packages the existing shared files and OFD catalog as build assets; it does not maintain a second checked-in catalog. Source records retain upstream paths, versions, and attribution where provided.

## 🎛️ PQ Design: the same workshop, at home on every screen

PrintQuote now has a shared design language: graphite dark and porcelain light workspaces, precise blue accents, clear technical numbers and selective depth around navigation and tools. Choose **System, Light or Dark** in Settings. Forms and large tables stay opaque and readable.

Apple uses native **Liquid Glass on supported systems**, with native-material and opaque accessibility fallbacks on older systems. Android adapts from bottom navigation to a rail and sidebar. Windows keeps desktop tables, keyboard search and a wide-window record inspector. Quote builders reveal more simultaneous information as space grows, and library filters collapse when you need room for results.

Explore the [PrintQuote Design Language](docs/design/PRINTQUOTE_DESIGN_LANGUAGE.md), [platform adaptation matrix](docs/design/platform-adaptation.md), [seven-screen concept preview](docs/design/preview.html) and [verification record](docs/design/verification.md). The HTML preview is illustrative; download/open it locally to use its controls. **Native visual, accessibility and performance acceptance is still pending**, so this is not a claim that every target device has been interaction-tested.

## ✅ What has been checked?

The latest shared workflow validation was recorded on **September 15, 2026**:

| Check | Result / scope |
| --- | --- |
| Swift tests | **68 passed** locally, including catalog scale, cancellation rollback and recovery |
| Apple builds | macOS and iOS Simulator builds passed; iOS target includes iPhone and iPad |
| Android JVM tests | **32 tests: 31 passed, one optional local-model test skipped**, including shared V4 catalog and recovery tests |
| Windows logic, importer and SQLite/catalog tests | **40 tests, 39 passed and one optional local-model test skipped** |
| Windows PQ Design MSI | 0.5.0 packaged and installed (exit 0); installed process remained running; installed classpath hashes match the package. Visual interaction check blocked by locked host. EXE packaging not repeated. |
| Windows upgrade persistence | Existing database backed up; its hash unchanged by the PQ Design MSI installation |
| Android build and lint | Passed; dependency-update notices remain |
| Git workflow tests | **6 passed**, using temporary repositories |
| Android interaction tests | **2 passed in an earlier release**; updated test source compiles, not rerun for this build |

Tests cover pricing fixtures, validation, tool limits, persistence, source handling, and workflow behavior. Android interaction coverage includes creating/reopening a quote, searching libraries, saving a catalog spool, and changing business settings. Prior native Mac checks covered catalog search/detail, printer selection, and the tool-count picker.

**Build success and interaction coverage are different things.** Physical Android devices and iPhone/iPad interactions remain unverified. The combined check does not substitute for exercising layouts and workflows on real target devices.

Repeat the checks:

```sh
./pq check
python3 -m unittest discover -s Tests/Workflow

# With an Android emulator/device running:
./android/gradlew -p android :app:connectedDebugAndroidTest
```

Combined build logs go to `.workflow/apple.log` and `.workflow/android.log`.

## 🔎 Inspect a model before quoting

Choose **Inspect STL / 3MF** on the Dashboard. On **macOS, iPhone and iPad**, 3MF now opens a manufacturing review: choose a project, inspect its printer, materials, tool evidence, plates, quantities and warnings, then accept selected fields into a quote draft. Save the draft in the quote editor when ready.

- **Geometry with context:** core resources and component/build instances remain separate. Units and affine transforms are applied before bounds and surface-area calculations. Volume is reported only within the mesh validation budget, with its confidence and limitations attached.
- **Slicer-aware evidence:** OrcaSlicer, Bambu Studio, PrusaSlicer, Anycubic and Creality families have known-key adapters. Unknown versions keep a conservative fallback; Cura and FlashPrint retain standard geometry and raw metadata. Family support does not imply every exporter version has been verified.
- **Tools are not feeder slots:** physical toolhead counts, nozzle entries, filament inputs and feeder slots remain separate. Ambiguous hardware requires review. Saved printer modifications and material prices are not silently overwritten.
- **Manufacturing quantities:** separate source estimates for time, model, support, interface, purge, flush and tower information are retained when explicitly present. Select one source per pricing field and one plate per quote. Total consumption is not automatically relabeled as model-only weight.
- **Recover useful work:** an invalid optional image or metadata section can produce a partial result. Sliced `.gcode.3mf` packages can retain manufacturing data even without mesh resources. Security-limit violations remain fatal.
- **Reimport safely:** SHA-256 fingerprints, parser/schema versions, a bounded cache, duplicate detection, reanalysis and selected-update drafts preserve user control. Exportable support diagnostics omit geometry and metadata values.

**An enabled support or prime-tower setting is not a gram estimate.** The importer does not invent toolpath-derived quantities or support-removal labor. Source files remain unchanged.

The **STL / legacy inspector** remains available on Apple. Android and Windows retain their existing inspection report while native parity for this new subsystem is deferred, as requested in the manufacturing brief. The shared JSON schemas and synthetic fixtures define that next implementation's contract.

See [manufacturing import architecture, safety limits and validation](docs/features/three-mf-manufacturing.md), [portable schemas and fixtures](SharedSchemas/three-mf-v2/README.md), and the [legacy inspection contract](docs/features/model-import.md). Customer files are never included in the fixture library.

## 🚧 What isn't finished yet?

The app already estimates and saves quotes, but the workshop still has room to grow:

- Jobs, full inventory workflows, and Analytics are unfinished; Apple has placeholder destinations. Material stock fields are implemented separately.
- A 3D viewer and toolpath-derived support/tower quantities remain unfinished. Apple has transformed geometry and selected quote updates; Android/Windows manufacturing-review parity is deferred.
- PDF quote export is not implemented.
- Live material prices, web scraping, and cloud/iCloud synchronization are not implemented.
- Listing a source does not mean its network importer exists. Cura, PrusaSlicer, Klipper, OpenPrintTag, and manufacturer TDS adapters remain future work.
- Signed production releases, notarization, and app-store publishing are outside the current development workflow.

These are scope notes, not promised release dates. Feature proposals are welcome through the repository's **Apple and Android feature** issue template.

## 📚 Follow the paper trail

| Guide | What you'll find |
| --- | --- |
| [Xcode quick start](OPEN_IN_XCODE.md) | Apple project setup, signing, and device destinations |
| [Android guide](android/README.md) | Toolchain, assets, app behavior, and test commands |
| [Development workflow](docs/development-workflow.md) | Push/pull, combined checks, and coordinated features |
| [Architecture](docs/architecture.md) | Domain and data organization |
| [Pricing specification](docs/pricing-engine.md) | Calculation behavior and assumptions |
| [Data sources](docs/data-sources.md) | Catalog and source strategy |
| [Orca import](docs/orcaslicer-import.md) | Normalized technical-profile ingestion |
| [Filament source guide](docs/filament-data-sources.md) | Filament reference sources |
| [Printer source guide](docs/printer-data-sources.md) | Printer reference sources |
| [V2 project brief](docs/project-brief-v2.md) | Product requirements and background |
| [Windows desktop guide](windows/README.md) | Run, build MSI/EXE, storage and shared Kotlin logic |

Some detailed delivery notes describe earlier milestones. The dated verification table above records the newer combined check.

## 🤝 Credits and license

PrintQuote-authored code, tools, schemas, and documentation use **AGPL-3.0-only**. See [LICENSE](LICENSE).

The bundled **Open Filament Database** catalog is separately identified under **MIT**, with its notice included. Orca-derived records retain upstream provenance and attribution, with the upstream license provided separately. The source directory includes **52 reference groups**; a reference is not a claim of partnership, certification, or a live integration.

See [ATTRIBUTION.md](ATTRIBUTION.md) and [ThirdParty/](ThirdParty/) for the project's licensing and source notices.

---

<div align="center">

**Less “that seems about right.” More “here's the breakdown.”** 🧊

</div>
