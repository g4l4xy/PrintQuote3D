# PrintQuote 3D — Codex Project Brief

## 1. Project Goal

Build **PrintQuote 3D**, a professional 3D-print estimating and quoting application.

The app should let a user:

1. Import `.stl` and `.3mf` files.
2. Inspect the model in a 3D viewer.
3. Estimate or import printing data such as:
   - model material
   - supports
   - purge / flush waste
   - prime tower
   - print time
   - number of filament changes
   - number of colors/materials
4. Select a printer, material, and manufacturing configuration.
5. Calculate the real internal production cost.
6. Apply pricing rules, markup or target margin.
7. Generate a customer-facing quote.
8. Save reusable printer, filament, labor, pricing, and customer presets.
9. Maintain a printer/material database with transparent sources.
10. Eventually track inventory, production jobs, actual-vs-estimated cost, and profitability analytics.

The app should feel like a combination of:
- Fusion 360
- OrcaSlicer
- modern quoting/invoicing software

It should NOT feel like a simple hobby filament calculator.

---

# 2. Primary Development Environment

The user has:

- **Mac**
- **Xcode installed**
- wants the first implementation in **Swift + SwiftUI**
- wants a later **Kotlin** version
- wants the product available on **macOS and Windows**

Important platform constraint:

- SwiftUI is the primary UI framework for the **macOS** application.
- SwiftUI is not a native Windows UI framework.
- Do NOT build the SwiftUI UI with the assumption that it will compile on Windows.
- Architect the project so the pricing engine, schemas, formulas, source data, test cases, and domain behavior can be ported cleanly to Kotlin later.
- The later Windows client should be built with **Kotlin + Compose Desktop**.
- Keep platform-specific UI and platform-neutral domain logic clearly separated.

Initial target:

**macOS 14+**

Language:

**Swift 6 where practical**

UI:

**SwiftUI**

Persistence:

**SwiftData** initially, behind repository/service abstractions so the persistence layer can be replaced later.

Networking:

**URLSession + async/await**

Testing:

**Swift Testing** or XCTest where more appropriate.

3D rendering:

Prefer **SceneKit** for the first macOS implementation if it provides the fastest reliable STL/3MF workflow.
Do not over-engineer the renderer in V1.

---

# 3. Product Name

Working name:

# PrintQuote 3D

Tagline:

**Upload. Configure. Price. Quote.**

Do not bake the name too deeply into identifiers in case branding changes later.

---

# 4. Architecture

Use a modular structure.

Suggested Swift package / app organization:

```text
PrintQuote3D/
├── App/
│   ├── PrintQuote3DApp.swift
│   ├── AppState.swift
│   └── Navigation/
│
├── Features/
│   ├── Dashboard/
│   ├── Quotes/
│   ├── QuoteBuilder/
│   ├── Customers/
│   ├── Printers/
│   ├── Filaments/
│   ├── Inventory/
│   ├── Presets/
│   ├── Analytics/
│   └── Settings/
│
├── Domain/
│   ├── Models/
│   ├── Pricing/
│   ├── Compatibility/
│   ├── Materials/
│   ├── Printers/
│   └── Validation/
│
├── Data/
│   ├── Persistence/
│   ├── Repositories/
│   ├── SeedData/
│   ├── Sources/
│   └── Networking/
│
├── Rendering/
│   ├── STL/
│   ├── ThreeMF/
│   └── ModelViewer/
│
├── Services/
│   ├── QuoteService/
│   ├── PricingService/
│   ├── MaterialService/
│   ├── PrinterService/
│   ├── ImportService/
│   └── ExportService/
│
├── Shared/
│   ├── Components/
│   ├── Formatting/
│   ├── Utilities/
│   └── Constants/
│
└── Tests/
```

Rules:

- Keep SwiftUI views thin.
- Do not put pricing formulas directly in views.
- Do not put raw web/source parsing in views.
- Domain models should be Codable where practical.
- Prefer stable IDs and explicit schema versioning.
- Store source attribution for externally sourced data.

---

# 5. Main Navigation

Desktop sidebar:

- Dashboard
- Quotes
- New Estimate
- Customers
- Jobs
- Inventory
- Filaments
- Printers
- Presets
- Analytics
- Settings

Bottom utility items:

- Material Database
- Pricing Sources

V1 does not need every section to be complete, but navigation and architecture should anticipate them.

---

# 6. V1 Scope

Build these first:

## V1.1
- macOS SwiftUI shell
- sidebar navigation
- Dashboard
- Printer Library
- Filament Library
- Presets
- Settings

## V1.2
- create quote
- customer
- quote line items
- pricing engine
- save/load quote

## V1.3
- STL import
- basic model metadata
- basic 3D preview
- manual print-data entry

## V1.4
- 3MF import
- parse multiple objects/material/color information where feasible
- improve model analysis

## V1.5
- quote PDF export
- customer/internal quote views

Do NOT start with live scraping or every slicer integration.

---

# 7. Core Domain Models

Create strongly typed domain models.

## PrinterProfile

Suggested fields:

```swift
struct PrinterProfile: Identifiable, Codable {
    var id: UUID
    var manufacturer: String
    var model: String
    var variant: String?

    var buildVolumeXMM: Double
    var buildVolumeYMM: Double
    var buildVolumeZMM: Double

    var extruderCount: Int
    var nozzleCount: Int
    var toolheadCount: Int

    var maxNozzleTemperatureC: Double?
    var maxBedTemperatureC: Double?
    var maxChamberTemperatureC: Double?

    var enclosureType: EnclosureType
    var activeChamberHeating: Bool

    var multiMaterialSystem: MultiMaterialSystem?
    var maxMaterialInputs: Int
    var automaticMaterialSwitching: Bool
    var integratedDrying: Bool

    var defaultNozzleDiameterMM: Double
    var defaultNozzleMaterial: NozzleMaterial

    var firmwareFamily: FirmwareFamily?
    var connectionTypes: [PrinterConnectionType]

    var purchasePrice: Decimal?
    var replacementCost: Decimal?
    var expectedUsefulLifeHours: Double?
    var maintenanceCostPerHour: Decimal?
    var typicalPowerWatts: Double?
    var maximumPowerWatts: Double?

    var sources: [SourceReference]

    var notes: String?
}
```

---

# 8. Multi-Material Systems

Use an enum / typed model.

Examples:

- none
- manualChange
- Bambu AMS
- Bambu AMS Lite
- Anycubic ACE Pro
- Anycubic ACE 2 Pro
- Flashforge IFS
- Prusa MMU
- IDEX
- toolchanger
- multiNozzle
- custom

The database must support:
- system name
- manufacturer
- generation
- channel/input count
- automatic switching
- drying support
- purge behavior
- average change time
- known material limitations
- source references

Do not treat all automatic filament switching systems as equivalent.

---

# 10. Material / Filament Model

## FilamentProduct

Suggested fields:

```swift
struct FilamentProduct: Identifiable, Codable {
    var id: UUID

    var manufacturer: String
    var productName: String
    var materialFamily: MaterialFamily
    var materialSubtype: String?

    var colorName: String?
    var colorHex: String?

    var diameterMM: Double
    var netWeightGrams: Double

    var purchasePrice: Decimal?
    var normalizedPricePerKG: Decimal?

    var densityGPerCM3: Double?

    var nozzleTemperatureRangeC: ClosedRange<Double>?
    var bedTemperatureRangeC: ClosedRange<Double>?
    var chamberTemperatureRangeC: ClosedRange<Double>?

    var dryingRecommendation: DryingRecommendation?

    var moistureSensitivity: RatingLevel
    var abrasionLevel: RatingLevel
    var printingDifficulty: RatingLevel

    var enclosureRecommended: Bool
    var ventilationRecommended: Bool
    var hardenedNozzleRecommended: Bool
    var printFromDryBoxRecommended: Bool

    var feederCompatibility: [FeederCompatibility]

    var sources: [SourceReference]
    var userNotes: String?
}
```

---

# 11. Material Families

Seed the app with at least:

## Common
- PLA
- PLA+
- PLA Pro
- HT-PLA
- Matte PLA
- Silk PLA
- LW-PLA
- PETG
- PET
- ABS
- ASA

## Flexible
- TPU 98A
- TPU 95A
- TPU 90A
- TPU 85A
- TPU 75A
- TPE
- TPC

## Engineering
- PC
- PC Blend
- PA6
- PA12
- PA11
- PA66
- CoPA
- PP
- POM
- PCTG

## High Temperature
- PPS
- PPSU
- PSU
- PEI / Ultem
- PEEK
- PEKK

## Filled / Reinforced
- PLA-CF
- PETG-CF
- PET-CF
- PA-CF
- PC-CF
- ASA-CF
- ABS-CF
- PA-GF
- PP-GF
- PC-GF

## Specialty
- Wood
- Metal-filled
- Glow
- Conductive
- ESD-safe
- Flame-retardant
- PVA
- BVOH
- HIPS
- support materials

Manufacturer-specific data must override generic material-family guidance.

---

# 12. Filament Pricing Sources

The product database must support prices and products from multiple sources.

Initial source list:

- Flashforge
- Anycubic
- Amazon
- Kingroon
- Prusament
- Polymaker
- Bambu Lab
- Fillamentum
- ColorFabb
- Proto-pasta
- 3DXTech
- BASF Ultrafuse
- Siraya Tech
- CookieCAD
- Hatchbox
- eSUN
- Overture
- Duramic
- Elegoo
- Creality
- SUNLU
- Inland
- Eryone

Each price record should support:

```text
source
product
material
color
spool weight
retail price
sale price
shipping cost if known
normalized $/kg
currency
URL
date checked
manual override
```

Pricing basis choices:

- My inventory cost
- Cheapest available
- Manufacturer MSRP
- Average market price
- Custom value

Old quotes must store a snapshot of the price used.

---

# 13. Source Model

Create a reusable source model.

```swift
struct SourceReference: Identifiable, Codable {
    var id: UUID
    var name: String
    var url: URL?
    var sourceType: SourceType
    var retrievedAt: Date?
    var notes: String?
}
```

Source types:

- manufacturer
- retailer
- community
- userEntered
- internal
- compatibilityDatabase

All externally sourced fields should be traceable.

---

# 14. Quote Model

A quote should contain:

- quote number
- customer
- project name
- status
- created date
- expiration date
- line items
- selected printer
- selected materials
- slicer / manufacturing data
- internal cost
- customer price
- taxes
- shipping
- discount
- notes
- source snapshots
- pricing preset used

Statuses:

- draft
- sent
- approved
- rejected
- expired
- convertedToJob

---

# 15. Manufacturing Estimate Model

Suggested data:

```text
model weight
support weight
support-interface weight
prime tower weight
purge/flush weight
startup purge
failed-print allowance
total material

print duration
material-change count
color count
material count

support difficulty
post-processing time
operator labor time
CAD/design time
machine setup time
quality inspection time
packaging time

risk rating
confidence rating
```

---

# 16. Pricing Engine

The app must distinguish:

## True internal production cost

from

## Customer price

Core formula:

```text
Production Cost =
    Model Material
  + Support Material
  + Purge / Flush Waste
  + Prime Tower
  + Startup Purge
  + Failure Allowance
  + Electricity
  + Drying / Conditioning
  + Machine Depreciation
  + Maintenance
  + Nozzle / Consumable Wear
  + Labor
  + Packaging
  + Outside Services
  + Other Direct Costs
```

Then apply:

```text
Overhead
Profit / margin
Minimum charge
Rush multiplier
Discount
Tax
Shipping
```

Never hide the calculation in a single magic multiplier.

---

# 17. Material Cost

```text
materialCost =
    gramsUsed / 1000
    × pricePerKG
```

Separate:
- model
- support
- support interface
- prime tower
- purge
- calibration/startup purge

Show total consumed grams and final-part grams.

Also calculate:

```text
Material Efficiency =
Final Part Material / Total Material Consumed
```

---

# 18. Electricity Cost

```text
printerEnergyKWh =
    averagePrinterWatts / 1000
    × printHours

printerEnergyCost =
    printerEnergyKWh
    × electricityRatePerKWh
```

Add other loads separately:

- filament dryer
- chamber heater
- AMS / ACE drying
- post processing

Never use maximum printer wattage as average draw unless explicitly selected.

---

# 19. Drying / Filament Care Cost

Drying model should support:

- temperature
- hours
- dryer wattage
- labor minutes
- electricity rate
- number of spools/jobs sharing a drying cycle

```text
dryingEnergyCost =
    dryerWatts / 1000
    × dryingHours
    × electricityRate
```

Allow user presets.

---

# 20. Machine Depreciation

Support both modes:

## Calculated depreciation

```text
depreciationPerHour =
    (purchasePrice - residualValue)
    / usefulLifeHours
```

## User-defined shop rate

Example:
- $0.50/hr
- $1.25/hr
- $3.50/hr
- etc.

Keep maintenance separate unless user chooses a combined machine rate.

---

# 21. Maintenance

Support:

- maintenance allowance per printer hour
- optionally future component-based tracking

Examples:
- nozzle
- belts
- build plates
- hotends
- fans
- filters
- extruder gears
- PTFE
- AMS/ACE/IFS parts

---

# 22. Abrasive Material / Nozzle Wear

Filled, glow, metal-filled and similar abrasive materials can trigger additional nozzle wear.

V1:
- boolean / severity-based surcharge
- user-defined cost per hour or per print

Later:
- component life tracking

---

# 23. Failure Risk

Do not use complexity to arbitrarily multiply the full price.

Use a risk reserve.

Example:

```text
expectedFailureCost =
    directManufacturingCost
    × failureProbability
```

Risk inputs may include:
- print duration
- material
- geometry
- support complexity
- printer history
- multicolor changes
- warping tendency
- model height
- first-layer footprint
- part count

V1 can use a manual risk rating with configurable percentages.

---

# 24. Complexity

Create a 0–100 complexity score.

Inputs can include:

- separate bodies
- thin walls
- small features
- overhangs
- bridges
- trapped supports
- model height
- bed contact
- number of colors
- tolerance-sensitive geometry
- assembly/post processing

Complexity should mainly influence:
- labor estimate
- inspection
- support-removal estimate
- risk

Do not directly use it as a broad price multiplier.

---

# 25. Supports

Track:

- none
- easy
- moderate
- heavy
- extreme

Allow:
- support material
- separate support-interface material
- support removal labor

Preset example:

```text
none: 0 minutes
easy: 5 minutes
moderate: 15 minutes
heavy: 30 minutes
extreme: 60+ minutes
```

All values editable.

---

# 26. Labor

Labor categories:

## Pre-production
- customer communication
- file inspection
- mesh repair
- orientation
- slicing
- machine setup
- material loading
- drying setup
- CAD/design

## Post-production
- part removal
- support removal
- sanding
- drilling
- inserts
- assembly
- glue
- paint
- quality inspection
- cleanup
- packaging

Each task should support:
- minutes
- hourly rate
- cost

---

# 27. Margin vs Markup

Implement these correctly.

## Markup

```text
price = cost × (1 + markupRate)
```

Example:
$20 cost at 50% markup = $30.

## Target margin

```text
price = cost / (1 - marginRate)
```

Example:
$20 cost at 50% margin = $40.

The UI must clearly distinguish these concepts.

---

# 28. Pricing Presets

Seed editable presets:

## Friends / Student
- material multiplier: 1.25x
- machine: $0.50/hr
- labor: $15/hr
- minimum: $5

## Hobby Business
- target margin: 40%
- machine: $1.25/hr
- labor: $25/hr
- minimum: $10

## Professional Prototype
- target margin: 55%
- machine: $3.50/hr
- labor: $45/hr
- setup minimum: $25

## Engineering
- target margin: 60%
- machine: $6/hr
- labor: $65/hr
- rush: 1.5x

All values editable.

---

# 29. Minimum Charge

If calculated customer price is below the shop minimum:

```text
finalPrice = max(calculatedPrice, minimumCharge)
```

The UI must show that the minimum charge was applied.

---

# 30. Multi-Color / Multi-Material Costing

Track separately:

- number of colors
- number of materials
- number of changes
- average change time
- purge per change
- tower material
- extra machine time
- extra energy

Support automatic switching systems, IDEX, multi-nozzle, and toolchanger machines differently.

A single-nozzle AMS/ACE/IFS/MMU workflow should not be costed the same as a true multi-tool or multi-nozzle system.

---

# 31. Feeder Compatibility

Do not use a single global boolean.

Use:

```text
Material Product
    ×
Feeder System
    ×
Printer Configuration
```

Statuses:

- supported
- supportedWithConditions
- notRecommended
- unsupported
- unknown

Include explanation and source.

Example condition categories:
- flexible material
- abrasive material
- brittle filament
- oversized spool
- cardboard spool
- moisture-sensitive
- external feed recommended

---

# 32. Printer Configuration / Accessories

Separate base printer from installed accessories.

Example:

```text
Bambu P1S
+ AMS
+ hardened extruder gears
+ 0.6 mm hardened nozzle
```

Example:

```text
Flashforge AD5X
+ IFS
+ hardened nozzle
+ enclosure
+ external dryer
```

The app should determine capability based on the actual configured machine, not only the stock model.

---

# 33. Printer Presets

A single machine can have multiple configurations.

Example:

```text
AD5X — Standard
0.4 mm nozzle
IFS enabled
4 colors
```

and

```text
AD5X — Engineering
0.6 mm hardened nozzle
external dry box
IFS disabled
abrasive materials
```

Save these independently.

---

# 34. Model Import

Support:

## STL
- ASCII
- binary

Extract at minimum:
- bounding dimensions
- triangle count
- volume if possible
- surface area if practical

## 3MF
Try to extract:
- objects
- geometry
- units
- materials/colors
- metadata

3MF parsing should be isolated behind a protocol so it can be replaced.

---

# 35. 3D Viewer

V1 requirements:

- rotate
- pan
- zoom
- reset camera
- show bounding dimensions
- simple material color
- fit model to view

Later:
- overhang visualization
- face normals
- support preview
- object selection
- multi-color 3MF display

---

# 36. Quote Builder UI

Suggested desktop layout:

```text
┌──────────────────────────────────────────────────────────────┐
│ PRINTQUOTE 3D                         Quote #PQ-2026-0184    │
├───────────────┬───────────────────────────┬──────────────────┤
│ MODEL         │ MANUFACTURING             │ ESTIMATE         │
│               │                           │                  │
│ [3D VIEWER]   │ Printer   AD5X            │ Material $ 6.82  │
│               │ Material  ASA             │ Waste    $ 1.41  │
│ 148×91×63 mm  │ Color     Black           │ Energy   $ 0.38  │
│ 186.3 g       │ Layer     0.20 mm         │ Machine  $ 3.40  │
│               │ Supports  Moderate        │ Labor    $12.50  │
│ Complexity 68 │                           │ Risk     $ 2.14  │
│               │ Time      8h 42m          │                  │
│               │ Material  231 g           │ COST     $26.65  │
├───────────────┴───────────────────────────┼──────────────────┤
│ MULTI-MATERIAL                            │ PROFIT           │
│                                          │                  │
│ Colors: 3                                │ Margin     45%    │
│ Changes: 132                             │                  │
│ Purge: 49 g                              │ QUOTE            │
│ Prime tower: 18 g                        │ $48.45           │
└──────────────────────────────────────────┴──────────────────┘
```

---

# 37. Customer Quote vs Internal Cost

The customer-facing quote should NOT expose:
- internal labor rate
- raw material cost
- depreciation
- margin
- maintenance
- failure reserve

Customer-facing output should show:

- customer
- project
- material
- color
- quantity
- lead time
- subtotal
- tax
- shipping
- total
- notes
- approval / quote expiration

Internal view shows detailed costing.

---

# 38. Confidence Score

Track estimate confidence.

Example:

## High
- exact slicer time
- exact filament use
- known printer
- known material price

## Medium
- partial slicer data
- known printer/material

## Preliminary
- STL-only estimate
- support/material assumptions

Do not present rough geometry-only estimates as guaranteed production values.

---

# 39. Automatic Warnings

Examples:

- model exceeds build volume
- nozzle incompatible with abrasive filament
- enclosure recommended
- drying recommended
- incompatible feeder
- insufficient filament inventory
- material change count is excessive
- purge waste exceeds model weight
- multi-material system increases cost
- material data is stale
- quote uses estimated rather than actual slicer data

Warnings should be advisory and explain why.

---

# 40. Alternative Manufacturing Suggestions

Later versions should compare eligible printers/configurations.

Example:

```text
Kobra S1
$18.42
7h 48m

Prusa XL
$24.83
8h 11m

AD5X
Not eligible: build volume exceeded
```

Potential recommendations:
- split model
- use another printer
- use a toolchanger
- paint instead of multicolor printing
- change support material
- batch parts differently

Do not implement AI recommendations in the first milestone.

---

# 41. Presets

Presets must be:

- editable
- duplicatable
- deletable
- importable
- exportable
- savable

Preset categories:
- printer
- printer configuration
- filament
- labor
- pricing
- customer
- electricity
- drying
- packaging
- support removal

---

# 42. Settings

## Business
- business name
- address
- logo
- currency
- sales tax
- quote expiration
- payment terms

## Electricity
- cost/kWh
- optional peak/off-peak later

## Labor
- CAD/design rate
- setup rate
- finishing rate
- general rate

## Pricing
- minimum order
- default margin or markup
- risk reserve
- rush fee
- overhead

## Filament
- preferred sources
- default pricing basis
- shipping/tax treatment

## Equipment
- depreciation model
- maintenance treatment

---

# 43. Inventory — Later V1/V2

A spool inventory record should eventually support:

- product
- original weight
- remaining weight
- purchase source
- purchase price
- date opened
- last dried
- moisture-sensitive flag
- location
- lot number

Job check:

```text
Required: 742 g
Available: 628 g
Warning: insufficient material
```

---

# 44. Production Jobs — V2

Approved quote can become a production job.

Track:
- assigned printer
- actual start
- actual completion
- actual filament
- actual print time
- failed attempts
- labor
- final cost

Then compare:

```text
Estimated cost: $26.65
Actual cost:    $29.18
Variance:       +9.5%
```

---

# 45. Analytics — V2

Examples:

- revenue
- quote conversion
- average margin
- profit/hour
- printer utilization
- failure rate
- waste
- material usage
- maintenance cost
- most profitable printer
- most profitable material
- actual vs estimated accuracy

---

# 46. Cross-Platform Strategy

## macOS first
Swift + SwiftUI.

## Windows later
Kotlin + Compose Desktop.

Do not attempt to make SwiftUI itself cross-platform to Windows.

To make the port clean:

1. Keep formulas documented.
2. Keep seed data in portable JSON.
3. Keep enums and schema names stable.
4. Add schema version numbers.
5. Create shared fixture files containing example calculations.
6. Build test cases where Swift and Kotlin must return identical results.

Suggested shared folder:

```text
SharedSchemas/
├── schema_version.json
├── printers.json
├── filaments.json
├── pricing_presets.json
├── calculation_fixtures.json
└── compatibility_rules.json
```

When Kotlin development begins:
- port domain models
- port calculation engine
- run identical fixture tests
- build Compose Desktop UI separately

---

# 47. Localization / Languages

The user requested two implementation languages:

- Swift first
- Kotlin later

Do not confuse programming-language support with UI localization.

Still, build text with localization in mind:
- no hardcoded strings scattered through logic
- use String Catalogs in SwiftUI

A future localization layer can support English and other spoken languages without architectural changes.

---

# 48. Persistence

For macOS V1:

Use SwiftData, but wrap it behind repositories.

Example protocols:

```swift
protocol PrinterRepository {
    func fetchAll() async throws -> [PrinterProfile]
    func save(_ printer: PrinterProfile) async throws
    func delete(id: UUID) async throws
}

protocol FilamentRepository {
    func fetchAll() async throws -> [FilamentProduct]
    func save(_ filament: FilamentProduct) async throws
}

protocol QuoteRepository {
    func fetchAll() async throws -> [Quote]
    func save(_ quote: Quote) async throws
}
```

Avoid making the entire domain depend on SwiftData annotations.

---

# 49. Seed Data

Use versioned JSON seed files.

Do not hard-code hundreds of printers in Swift source.

Examples:

```text
printers_seed_v1.json
materials_seed_v1.json
filament_products_seed_v1.json
pricing_presets_seed_v1.json
```

Add:
- schemaVersion
- source
- lastUpdated

---

# 50. Networking / Live Price Updates

Do NOT make live scraping a hard dependency for V1.

Build a source-provider abstraction:

```swift
protocol FilamentPriceProvider {
    func search(_ query: FilamentSearchQuery) async throws -> [FilamentPriceRecord]
}
```

Initial implementation:
- local/manual data

Later:
- manufacturer APIs if available
- approved web feeds
- retailer integrations
- background update process

The UI should always display:
- source
- URL
- retrieved date
- manual override status

---

# 51. PDF Export

Customer quote PDF should include:

- logo
- company
- quote number
- date
- expiration
- customer
- project
- line items
- material/color
- quantity
- lead time
- subtotal
- tax
- shipping
- total
- terms
- acceptance area

Internal PDF/report can include full costing.

---

# 52. Design Direction

Visual style:

- dark graphite
- white / light text
- royal/electric blue accent
- clean cards
- engineering-focused
- restrained green/yellow/red status colors
- data-dense without feeling cluttered

Do not copy another company's visual identity.

Use native macOS conventions where reasonable.

---

# 53. Initial Screens Codex Should Build

Build these first:

1. App shell + sidebar
2. Dashboard
3. Printer Library
4. Printer Detail
5. Filament Library
6. Filament Detail
7. New Quote
8. Quote Cost Breakdown
9. Presets
10. Settings

Use mock seed data so navigation and pricing can work before model import.

---

# 54. First Functional Milestone

The first truly functional milestone should allow a user to:

1. Launch app in Xcode.
2. Create/select a printer.
3. Create/select a filament.
4. Enter:
   - model grams
   - support grams
   - purge grams
   - print hours
   - labor
5. Set:
   - electricity rate
   - material price
   - machine rate
   - maintenance
   - margin
6. See a live calculation.
7. Save the quote.
8. Reopen the quote.

Do this before spending substantial time on STL analysis.

---

# 55. Calculation Test Fixture

Codex should create unit tests.

Example fixture:

```text
Material:
200 g
$20/kg
= $4.00

Support:
50 g
$20/kg
= $1.00

Purge:
30 g
$20/kg
= $0.60

Printer:
150 W
10 hours
$0.14/kWh
= $0.21

Machine:
$1.00/hour
10 hours
= $10.00

Maintenance:
$0.25/hour
10 hours
= $2.50

Labor:
30 minutes
$30/hour
= $15.00
```

Before overhead/risk:

```text
$4.00
+ $1.00
+ $0.60
+ $0.21
+ $10.00
+ $2.50
+ $15.00
= $33.31
```

At 40% target margin:

```text
$33.31 / (1 - 0.40)
= $55.516666...
```

Display with normal currency rounding:

**$55.52**

Write automated tests for this.

---

# 56. Guardrails

Codex should NOT:

- put all logic in one giant view
- make SwiftUI views own persistence logic
- hardcode filament price assumptions
- assume PLA = one price
- assume all printers from one brand are equivalent
- use maximum wattage as average power
- confuse margin and markup
- hide multi-material purge
- ignore support material
- ignore drying
- ignore labor
- ignore machine wear
- make online connectivity mandatory
- build Windows using SwiftUI

---

# 57. Definition of Done for Initial Codex Pass

The repository should:

- open in Xcode
- compile without manual fixes
- run on macOS
- include seed printer data
- include seed filament data
- show sidebar navigation
- support basic quote creation
- implement the pricing engine
- include calculation unit tests
- save data locally
- contain README instructions
- contain clean TODO markers for later STL/3MF import
- keep domain logic separate from UI
- contain no secrets/API keys

---

# 58. Codex Working Style

Codex should work incrementally.

For every major change:

1. inspect existing project structure
2. make the smallest coherent change
3. build
4. run tests
5. fix compiler warnings/errors
6. summarize what changed

Do not generate a huge uncompiled project in one pass.

Start with a compileable skeleton and build outward.

---

# 59. First Codex Task

Use this as the first implementation request:

> Create the initial macOS SwiftUI project structure for PrintQuote 3D. The user has Xcode installed on their Mac. Target macOS 14+. Use SwiftUI and SwiftData, but isolate persistence behind repository protocols. Create the sidebar navigation, Dashboard, Printer Library, Filament Library, New Quote, Presets, and Settings screens with clean placeholder content. Implement the core domain models and a tested PricingEngine. Seed the app with a few representative printers and filaments from local JSON files. Do not implement networking, scraping, STL parsing, 3MF parsing, or PDF export yet. The project must compile and the pricing unit tests must pass before moving to later features.

---

# 60. Later Kotlin Port

When the Swift version is stable:

Create a Kotlin implementation using:

- Kotlin
- Compose Desktop
- kotlinx.serialization
- coroutines
- repository/service architecture
- portable JSON seed files
- equivalent calculation fixtures

The Kotlin implementation should be a behavioral port, not a line-by-line translation of SwiftUI.

Both clients should agree on:
- pricing results
- schemas
- compatibility states
- preset behavior
- quote totals
- rounding rules

# 61. Public GitHub Repository Requirement

Codex must create and use a **public GitHub repository** for this project so all application code, schemas, seed data, tests, documentation, and migration notes have a durable home.

Preferred repository name: `PrintQuote3D`

Preferred repository description:

`Open-source 3D printing cost estimation, printer/material intelligence, and customer quoting software for macOS first, Windows later.`

The user is on a Mac and already has Xcode installed.

Use GitHub CLI if available:

```bash
gh repo create PrintQuote3D --public --source=. --remote=origin --push
```

Repository requirements:

- public visibility
- `main` default branch
- README
- deliberate LICENSE choice
- Xcode/Swift/macOS `.gitignore`
- no secrets, API keys, tokens, passwords, customer data, or local credentials
- all portable schemas and seed JSON committed
- tests committed
- architecture documentation committed
- data-source attribution committed

Suggested layout:

```text
PrintQuote3D/
├── README.md
├── LICENSE
├── ATTRIBUTION.md
├── docs/
│   ├── architecture.md
│   ├── pricing-engine.md
│   ├── data-sources.md
│   ├── orcaslicer-import.md
│   └── windows-port.md
├── macOS/
│   └── PrintQuote3D/
├── SharedSchemas/
│   ├── schema_version.json
│   ├── printers.json
│   ├── filaments.json
│   ├── compatibility_rules.json
│   ├── pricing_presets.json
│   └── calculation_fixtures.json
├── tools/
│   └── OrcaProfileImporter/
└── tests/
```

Do not store customer quote data in the public repository.

---

# 62. OrcaSlicer as Printer and Filament Profile Source

Use:

`https://github.com/OrcaSlicer/OrcaSlicer`

as a major reference/import source for printer and filament profile information.

OrcaSlicer stores vendor/profile information under:

```text
resources/profiles/
```

including vendor JSON files and vendor-specific profile folders.

Examples:

```text
resources/profiles/Anycubic.json
resources/profiles/Anycubic/
resources/profiles/BBL.json
resources/profiles/BBL/
```

Build an isolated **OrcaProfileImporter**. Do not make SwiftUI views depend on OrcaSlicer's native profile format.

Importer goals:

1. Read upstream OrcaSlicer profile JSON.
2. Normalize printer information into PrintQuote's portable schema.
3. Normalize filament/profile information into PrintQuote's portable filament schema.
4. Preserve source attribution and upstream path.
5. Record exact upstream commit SHA or release/tag.
6. Treat OrcaSlicer as technical/profile data, not retail-price truth.
7. Keep PrintQuote-specific extensions separate from imported values.

Potential printer fields to map when available:

- manufacturer/vendor
- model
- variant
- build dimensions
- nozzle diameters
- printable height
- process/profile references
- firmware/profile metadata
- filament profile references
- bed/build-surface information
- technical notes

Potential filament/profile fields to map when available:

- vendor/material
- profile name
- filament type
- nozzle temperature
- bed temperature
- chamber-related values
- cooling
- maximum volumetric speed
- density if present
- flow/shrinkage values if present
- compatible printer/vendor references
- notes

Use an explicit mapping boundary:

```text
Orca source JSON
      ↓
OrcaProfileDTO
      ↓
OrcaProfileMapper
      ↓
PrintQuote normalized model
      ↓
Portable JSON / repositories
```

---

# 63. OrcaSlicer Licensing and Attribution

OrcaSlicer is licensed under **GNU AGPL-3.0**.

Codex must:

- preserve attribution
- add OrcaSlicer to `ATTRIBUTION.md`
- record source repository URL
- record source path
- record commit/tag
- keep imported-source metadata attached to normalized data
- avoid copying substantial OrcaSlicer application source code unless the project deliberately accepts the corresponding AGPL obligations
- clearly separate imported Orca data from PrintQuote-authored data
- flag redistribution/licensing questions for review before shipping large copied datasets

Prefer reading/importing profile information with attribution over embedding OrcaSlicer application code.

---

# 64. Orca Source Tracking Model

Example:

```swift
struct ExternalProfileSource: Codable {
    var sourceName: String
    var repositoryURL: URL
    var sourcePath: String
    var commitSHA: String?
    var releaseTag: String?
    var importedAt: Date
}
```

Every imported profile should answer:

> Where did this data come from?

---

# 65. Orca Data Update Workflow

The app must not require live GitHub access every time it launches.

Use:

```text
OrcaSlicer upstream
        ↓
Importer/update tool
        ↓
Validation
        ↓
Normalized portable JSON
        ↓
App bundle/database
```

A later maintenance command may be:

```bash
swift run OrcaProfileImporter update
```

The updater should:
- retrieve/clone upstream
- identify exact commit
- scan supported profile files
- map recognized fields
- validate schema
- output normalized JSON
- report unmapped/ambiguous records
- never silently overwrite user overrides

---

# 66. Source Priority

For technical capability:

1. manufacturer documentation
2. current manufacturer profile
3. OrcaSlicer profile
5. trusted community source
6. user override

User overrides remain allowed and must be marked.

For pricing:

1. actual user inventory/purchase cost
2. retailer/manufacturer current price
3. market average
4. manual estimate

Do not use OrcaSlicer as a primary retail-pricing source.

---

# 67. Toolhead Requirement: 1–12 Physical Toolheads

The printer architecture must support **1 through 12 available physical toolheads**.

These are separate from:

- filament input count
- color count
- feeder channel count
- AMS/ACE/IFS/MMU slot count

Examples:

```text
Bambu P1S + AMS
Physical toolheads: 1
Filament inputs: 4
Automatic selectable materials: 4
```

```text
Prusa XL 5-tool
Physical toolheads: 5
Filament inputs: at least 5
Automatic selectable materials: 5
```

```text
Custom toolchanger
Physical toolheads: 12
Filament inputs: 12+
```

UI must allow:

```text
Available Toolheads
1  2  3  4  5  6  7  8  9  10  11  12
```

Enforce:

```text
1 <= availableToolheads <= 12
```

Do not reduce this to a Boolean such as `isMultiTool`.

---

# 68. Toolhead Data Model

Suggested:

```swift
struct ToolheadConfiguration: Identifiable, Codable {
    var id: UUID
    var index: Int
    var name: String

    var nozzleDiameterMM: Double
    var nozzleMaterial: NozzleMaterial
    var maxNozzleTemperatureC: Double?

    var directDrive: Bool?
    var hardenedDriveComponents: Bool?

    var supportedMaterialFamilies: [MaterialFamily]
    var abrasiveMaterialsAllowed: Bool
    var flexibleMaterialsAllowed: Bool

    var assignedMaterialID: UUID?
    var assignedColorName: String?

    var changeOverheadSeconds: Double?
    var purgeRequiredOnActivation: Bool

    var notes: String?
}
```

```swift
struct PrinterToolSystem: Codable {
    var availableToolheadCount: Int
    var toolheads: [ToolheadConfiguration]

    var architecture: ToolArchitecture
    var simultaneousToolUseCount: Int

    var filamentInputCount: Int
    var automaticMaterialSwitching: Bool

    var sharedNozzle: Bool
}
```

Tool architectures:

```text
singleTool
singleNozzleSwitcher
idex
dualExtruder
fixedMultiNozzle
toolChanger
mixingHotend
custom
```

---

# 69. Toolhead Validation

Validate:

```text
toolheads.count == availableToolheadCount
1 <= availableToolheadCount <= 12
1 <= simultaneousToolUseCount <= availableToolheadCount
```

Do not assume all available toolheads can print simultaneously.

---

# 70. Toolhead Costing

Each toolhead may have independent:

- nozzle replacement cost
- expected nozzle life
- heater wattage
- tool-change time
- purge amount
- wipe amount
- maintenance rate
- abrasive wear multiplier
- material capability

The pricing engine should know which toolhead printed which material.

---

# 71. Filament Inputs vs Toolheads

Create separate values:

```swift
var physicalToolheadCount: Int
var filamentInputCount: Int
var maxSimultaneousMaterials: Int
var maxAutomaticSelectableMaterials: Int
```

Never infer toolhead count from color count or feeder slot count.

---

# 72. Quote Builder Tool Assignment

For true multi-tool machines:

```text
Black ASA       Tool 1
White ASA       Tool 2
PVA Support     Tool 3
Red TPU         Tool 4
```

For single-nozzle switching:

```text
Black PLA       AMS Slot 1 → Tool 1
White PLA       AMS Slot 2 → Tool 1
Red PLA         AMS Slot 3 → Tool 1
```

These must produce different waste/time/cost behavior.

---

# 73. Toolhead UI

Printer editor should contain:

```text
TOOL SYSTEM

Architecture
[ Toolchanger             ▼ ]

Available Toolheads
[ 5 ▼ ]

Simultaneously Active
[ 1 ▼ ]

Filament Inputs
[ 5 ]

Automatic Switching
[✓]

Tool 1   0.40 mm Brass
Tool 2   0.40 mm Brass
Tool 3   0.40 mm Hardened
Tool 4   0.60 mm Hardened
Tool 5   0.25 mm Brass
```

Increasing the count should create additional editable tool records with safe defaults and a review flag.

---

# 74. Orca Import + Toolhead Mapping

When importing from OrcaSlicer:

- map tool/extruder data only when clearly represented
- map into PrintQuote's 1–12 toolhead model
- never invent extra physical toolheads
- if ambiguous, set `needsReview`
- allow user correction
- never interpret AMS/ACE/IFS/MMU slots as physical toolheads

---

# 75. Updated First Codex Task

Before the original first milestone:

> Create a local Git repository for PrintQuote 3D and a public GitHub repository named `PrintQuote3D` under my GitHub account. I am on a Mac with Xcode installed. Use GitHub CLI (`gh`) if available. Initialize `main`, add an Xcode/Swift `.gitignore`, create README and `ATTRIBUTION.md`, commit the project brief, and push the initial commit. Do not commit secrets or customer data.

Then:

> Create the SwiftUI macOS application and an isolated OrcaProfileImporter. Use OrcaSlicer profile data as an imported/reference source while preserving source paths and upstream commit/tag. Implement 1–12 configurable physical toolheads, separate from feeder slots, filament inputs, and material-switching channels. Keep multi-tool, IDEX, fixed multi-nozzle, and single-nozzle switcher costing distinct.
