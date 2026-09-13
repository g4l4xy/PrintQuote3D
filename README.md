# PrintQuote 3D

Native macOS 14+, iOS 17+ and iPadOS 17+ print estimating and quoting, built with SwiftUI, SwiftData and a portable Decimal pricing domain. Public source: https://github.com/g4l4xy/PrintQuote3D

## Run and build

Open **`PrintQuote3D.xcodeproj`** in Xcode and choose the **PrintQuote3D** scheme. Select **My Mac**, an iPhone simulator, an iPad simulator, or a connected device, then Run. For a physical iPhone/iPad, select your development team under Signing & Capabilities. The shared Swift package is local; all catalogs are included. The local `PrintQuote 3D.app` can also be launched from Finder. See [Xcode quick start](OPEN_IN_XCODE.md).

```sh
swift build
swift test
./Scripts/build-app.sh
open 'PrintQuote 3D.app'
```

Verified with Xcode 26.6 / Swift 6.3.3 on Apple Silicon. The Mac build script packages resources and license notices and signs the local development app ad hoc. Intel builds require an Intel target/host; distribution signing and notarization are not part of this milestone.

## Available now

- Adaptive Apple app: sidebar navigation, full-width library detail screens and Details/Price estimate tabs on narrow screens; two-pane layouts on wider iPad/Mac windows.

- Sidebar, dashboard, printer and filament editors, pricing presets, settings and saved quotes.
- Live cost breakdown with material/support/waste, power, drying, machine, maintenance, wear, labor, risk, overhead, margin/markup, minimum, rush, discount, tax and shipping.
- **1–12 physical toolheads**, independent feeder/input/material counts, per-tool capability and cost settings, plus quote material-to-tool/slot assignments.
- Architecture-specific change/waste/energy behavior for shared-nozzle switching and independent tool systems. See [pricing contract](docs/pricing-engine.md).
- **Material Database**: offline Open Filament Database snapshot with 2,089 products, 14,577 color variants and 22,355 sizes. Search a product, choose color/spool, enter your price/kg, then add it to Filaments. Purchase links are references, not live price quotes.
- **Printers**: 1,004 real printer profiles available automatically (1,001 Orca model/nozzle configurations plus three manufacturer-sourced configurations), alongside your existing equipment. Search by manufacturer, model or nozzle in the library and estimate chooser. The Orca collection covers 383 model/configuration names across 64 vendors, including every manufacturer named in the supplied printer guide. Imported costs and unverified tool capabilities require review.
- **Pricing Sources**: 52 source groups from the supplied filament and printer data-source guides, including manufacturer references, Cura, PrusaSlicer, Klipper and packaging/color catalogs.
- Editable mode-specific build volumes, circular-bed diameter, rated maximum power separate from average-power quality, thermal fields and accessory notes.

## Quote workflow

Create/select your printer and filament in their libraries, then create a New Estimate. Enter project/customer details and print quantities. Rates use decimal fractions (`0.40` = 40%). Save quote and reopen it from Quotes.

Aggregate mode uses total slicer print time and manual gram categories. Tool-assignment mode initializes rows from those gram categories and then uses those rows instead. Enter base print hours excluding change time; enter each material's tool, feeder slot, grams, price and activation count. Tool active hours drive additional wear/heater costs and do not replace overall print duration. Base and per-tool energy/maintenance settings must not count the same cost twice.

Quote records retain selected equipment, material catalog provenance, price and calculation snapshots. Catalog refreshes never automatically overwrite library profiles or recalculate saved quotes. Library edits are in-memory until Save; subsequent workspace saves include current edits.

## Architecture and data

`QuoteDomain` contains Codable models and formulas; `QuoteData` isolates SwiftData and local catalogs; `PrintQuoteApp` contains UI/application state; `OrcaProfiles` and the CLI normalize upstream data without UI dependencies. OFD has its own Python importer and license boundary.

[Architecture](docs/architecture.md) · [Pricing](docs/pricing-engine.md) · [Data sources](docs/data-sources.md) · [Orca import](docs/orcaslicer-import.md) · [Windows port](docs/windows-port.md)

[Filament source guide](docs/filament-data-sources.md) · [Printer source guide](docs/printer-data-sources.md) · [V2 brief](docs/project-brief-v2.md)

SharedSchemas includes JSON schemas, version conventions, catalog manifests and calculation fixtures for the later Kotlin/Compose Desktop port. v1 saves decode with v2 optional additions; old aggregate totals remain unchanged. Local SwiftData stores and customer data are excluded from Git.

## Validation and remaining scope

Automated tests cover the original **$33.31 → $55.52** fixture, margin versus markup, invalid input, disk persistence, legacy decoding, tool counts, assignment validation, architecture costs, portable tool fixtures, inheritance cycles/vendor scope, catalog decoding and source precedence. Native Mac UI checks cover catalog search/detail, the estimate printer chooser and the 1–12 tool picker. Xcode macOS tests and both iOS SDK builds pass; simulator/device interaction has not been tested on this host.

Quotes still contain one manufacturing estimate, with aggregate labor. Jobs, Inventory and Analytics remain placeholders. Source-directory entries do not imply implemented ingestion: network adapters for Cura, PrusaSlicer, Klipper, OpenPrintTag and manufacturer TDS feeds remain future work. Accessories are recorded as notes; configure their actual tool/capability effects explicitly. No STL/3MF parsing, 3D viewer, live pricing, web scraping, PDF export or Kotlin UI is included yet.

## License

PrintQuote-authored code is **AGPL-3.0-only**. OFD data remains **MIT** with its notice; Orca-derived records are separately identified with upstream attribution and license. See [ATTRIBUTION.md](ATTRIBUTION.md), LICENSE and ThirdParty.
