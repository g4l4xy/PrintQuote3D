# PrintQuote 3D

An initial native macOS 14+ estimating app built with SwiftUI, SwiftData and Swift 6. The first functional milestone supports manual print data, live costing and local quote save/reopen.

## Run

Double-click **PrintQuote 3D.app** in this folder. The included development build is for Apple Silicon and is locally ad-hoc signed.

For development, open **Package.swift** in Xcode, select the **PrintQuote3D** scheme and **My Mac**, then Run. This is an Xcode-compatible Swift package, not a generated `.xcodeproj`. Xcode 26.6 / Swift 6.3.3 was used for verification.

```sh
swift build
swift test
./Scripts/build-app.sh
open 'PrintQuote 3D.app'
```

The script produces a standalone app with bundled seed resources. Build on an Intel Mac to generate an Intel binary. Distribution signing/notarization is a later step.

## Using the app

1. Open Printers or Filaments, select a profile or add one, edit its values and press Save.
2. Open New Estimate. Choose printer and filament profiles and optionally apply a pricing preset.
3. Enter material grams, print hours and labor. The estimate updates as numeric fields commit edits.
4. Set profit mode, rates and charges. Fractional rates use decimals: `0.40` means 40%.
5. Enter a project/customer and press Save quote.
6. Open Quotes and click the project title to reopen and edit the saved quote.

Save stores a complete snapshot of inputs, selected equipment/material/preset and calculated totals. Editing a library price does not rewrite existing quote costs. Rates and currency are copied from Settings when creating new estimates. Currency selection changes the denomination; it does not convert prices.

## Architecture

- `Sources/QuoteDomain`: Codable value types and Decimal pricing engine; no SwiftUI or SwiftData dependency.
- `Sources/QuoteData`: repository protocol, SwiftData adapter and local JSON seed loader. A versioned Codable library is stored as a SwiftData record, keeping persistence annotations out of the domain.
- `Sources/PrintQuoteApp`: observable application state and SwiftUI screens. Views route persistence through application state.
- `SharedSchemas`: pricing-input JSON schema, portable calculation fixture, schema conventions and seed data for the later Kotlin port.
- `Tests/QuoteTests`: pricing, validation, rounding, zero-consumption and disk save/reopen tests.

Local storage uses SwiftData's application-default store. No network access is required. A storage failure is reported and the workspace disabled rather than silently replacing user data.

## Pricing contract

Calculations use base-10 Decimal values. Material is grams / 1000 × price/kg. Model/waste, support and support-interface unit prices are independent. Power uses **average** watts. The machine hourly rate is user-entered; maintenance stays separate.

Failure reserve is the selected probability times material, electricity, drying, machine, maintenance, wear and labor; packaging, external services and other direct costs are added after the reserve. Overhead applies to total production cost. The optional material selling multiplier adds to the pricing basis and does not inflate reported internal cost.

Apply margin (`basis / (1-rate)`) or markup (`basis × (1+rate)`), then minimum, rush, discount, tax and shipping. Shipping is not taxed in this initial policy. Tax treatment is configurable only through the rate; jurisdiction-specific rules are not implemented. Minimum applies before rush and discount, so a discount can reduce the eventual subtotal below that minimum.

Internal components retain precision. Round subtotal, discount, tax and shipping to two decimal places using half-up rounding; total is their sum. Only currencies with two fractional digits are offered. The shared fixture verifies **$33.31 cost → $55.52 at 40% margin**.

## Verified

- `swift build` and release app packaging succeed.
- Xcode command-line build succeeds for My Mac.
- Eight automated tests pass, including a real disk store reopened through a new repository instance.
- Native UI launch, manual quote save and reopening the saved quote were exercised.

## Deliberate initial scope

Three illustrative printer configurations and PLA/PETG/ASA products are bundled. These are explicitly labeled demo data, not verified manufacturer specs or live retail prices. SimplyPrint support remains unknown and is separate from capability. Four editable pricing presets are included.

Quotes currently represent one manufacturing estimate rather than multiple independently priced line items. Labor is one aggregate minutes/rate pair. Machine depreciation is represented by an editable hourly shop rate. Presets support editing, duplication, deletion and save; UI import/export is pending. Unsaved library edits remain in memory and may be included in the next workspace save.

Jobs, Inventory and Analytics are navigation placeholders. The material database is a small product-family view; the full material taxonomy, compatibility rules, configured accessories, detailed labor categories, verified printer sources and customer management remain future work. There is no STL/3MF parsing, model viewer, networking, scraping, live pricing, PDF export or Kotlin UI in this pass.

TODO: isolate future STL/3MF services, add quote line items, expand typed hardware/material capabilities, add preset file exchange and String Catalog localization, then implement the later import milestones.
