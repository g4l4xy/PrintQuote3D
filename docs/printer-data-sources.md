# PrintQuote 3D — Printer Data Sources for Codex

# Recommended architecture

Use a layered printer-data strategy rather than trusting one website.

```text
Manufacturer specifications
       ↓
Normalized printer records ← Orca / Cura / PrusaSlicer profiles
       ↓
User printer configurations and overrides
```

For PrintQuote, do not use slicer profiles as the only source of truth. They are excellent for machine geometry, nozzle variants, filament compatibility, G-code flavor and process relationships, but may omit or simplify:

- rated input power
- average operating power
- heated chamber capability
- machine dimensions
- printer weight
- native feeder / multicolor expansion count
- exact toolhead topology
- current connectivity
- warranty / region variants
- discontinued status
- accessory-dependent capability

Official manufacturer documentation should override those fields whenever possible.

---

# 1. OrcaSlicer

Repository:

`https://github.com/OrcaSlicer/OrcaSlicer`

Profile documentation:

`https://github.com/OrcaSlicer/OrcaSlicer/wiki/how_to_create_profiles`

Primary data path:

```text
resources/profiles/
```

OrcaSlicer separates data into:

- `machine_model`
- `machine`
- `filament`
- `process`
- vendor meta files

Typical structure:

```text
resources/profiles/
├── Anycubic.json
├── Anycubic/
│   ├── machine/
│   ├── filament/
│   ├── process/
│   └── model/
├── BBL.json
├── BBL/
...
```

Useful printer fields include, depending on profile:

- vendor
- model
- family
- machine technology
- printer variant
- nozzle diameter
- nozzle type
- printable area
- printable height
- bed model
- bed texture
- default materials
- default filament profiles
- default print profile
- printer structure
- G-code flavor
- firmware-related behavior
- machine start/end logic
- time-cost related settings
- compatible process profiles
- compatible filament profiles

### Why PrintQuote should use it

OrcaSlicer is one of the best open machine-profile collections for modern consumer/prosumer FDM printers.

Its machine-model / machine-variant separation maps well to PrintQuote:

```text
PrinterModel
    ↓
PrinterVariant
    ↓
PrinterConfiguration
```

Do not import OrcaSlicer UI code.

Create:

```text
OrcaProfileImporter
```

which maps Orca JSON into PrintQuote's portable schema.

### License note

OrcaSlicer is AGPL-3.0.

Keep:
- source path
- upstream repository
- upstream commit SHA
- attribution

Do not casually copy large portions of Orca application code into PrintQuote.

---

# 2. UltiMaker Cura Machine Definitions

Repository:

`https://github.com/Ultimaker/Cura`

Important paths:

```text
resources/definitions/
resources/extruders/
resources/variants/
resources/quality/
resources/quality_changes/
resources/materials/
resources/meshes/
```

Cura machine profiles define values such as:

- machine width
- machine depth
- machine height
- build-plate shape
- origin location
- machine head geometry
- extruder count
- individual extruder definitions
- nozzle offsets
- nozzle sizes
- heated-bed capability
- G-code start/end sequences
- preferred material
- quality profile relationships
- material exclusions
- printer manufacturer
- file formats

Cura explicitly represents individual extruder definitions, making it valuable for dual- and multi-extrusion printers.

Example conceptual mapping:

```text
Cura Machine Definition
    +
Cura Extruder Definitions
    ↓
PrintQuote PrinterToolSystem
```

### Good PrintQuote uses

- build volume
- machine geometry
- extrusion count
- nozzle offsets
- multi-extruder configuration
- supported nozzle variants
- compatible material/profile relationships

### License

UltiMaker Cura is LGPL-3.0.

Treat license/attribution separately from AGPL sources.

---

# 3. PrusaSlicer Vendor Bundles

Main repository:

`https://github.com/prusa3d/PrusaSlicer`

Settings repositories include:

```text
https://github.com/prusa3d/PrusaSlicer-settings-prusa-fff
https://github.com/prusa3d/PrusaSlicer-settings-prusa-sla
https://github.com/prusa3d/PrusaSlicer-settings-non-prusa-fff
https://github.com/prusa3d/PrusaSlicer-settings-non-prusa-sla
```

Vendor bundles contain:

- printer profiles
- filament profiles
- print profiles
- printer variants
- nozzle variants
- compatibility conditions
- bed models
- textures
- thumbnails
- vendor metadata

Useful printer fields can include:

- printer model
- printer variant
- nozzle diameter
- extruder count
- retract settings
- compatible printer conditions
- start/end G-code
- bed shape
- print volume
- firmware/G-code flavor related settings
- material compatibility through preset conditions

### Why it matters

PrusaSlicer has especially useful handling for:

- printer variants
- multiple extruders
- dual-extruder modes
- alternate nozzle sizes
- specialized printer configurations

That makes it useful for validating PrintQuote's distinction between:

```text
physicalToolheadCount
filamentInputCount
maxSimultaneousMaterials
maxAutomaticSelectableMaterials
```

### License caution

PrusaSlicer itself is AGPL-3.0.

Some newer settings repositories have had license-clarity questions raised publicly.

Codex should record provenance and avoid assuming every settings repository has identical redistribution terms without checking the actual repository.

---

# 5. Klipper Configuration Repository

Repository:

`https://github.com/Klipper3d/klipper`

Useful path:

```text
config/
```

Klipper includes many example/reference printer configuration files.

Useful information can include:

- printer model
- MCU type
- kinematics
- build axis limits
- max velocity
- max acceleration
- extruder configuration
- heater limits
- thermistor type
- bed heater
- probe type
- stepper configuration
- pins
- macros / board configuration

### Important limitation

Klipper configs describe firmware setup, not necessarily commercial product specifications.

Do not treat:
- `max_velocity`
- heater limits
- max temperatures

as manufacturer warranty/spec limits without verification.

### Best use

Klipper should be a secondary technical-validation source, especially for:

- open/custom printers
- Voron
- RatRig
- Klipper-based OEM machines
- user-modified printers

---

# 6. Aniwaa

Catalog:

`https://www.aniwaa.com/catalog/`

Aniwaa maintains a large commercial additive-manufacturing catalog covering:

- desktop FDM
- industrial extrusion
- resin
- powder
- metal
- scanners
- related systems

Aniwaa says its product database collects detailed technical specifications directly from manufacturers and normalizes the data.

Potential use:

- model discovery
- industrial printer discovery
- historical/discontinued machines
- technology type
- build volume
- price category
- manufacturer

### Recommendation

Use for discovery and validation.

Do not bulk ingest without confirming terms/API/licensing.

---

# 7. 3DPrinting.com Printer Database

Database:

`https://3dprinting.com/products/`

Useful for:

- historical printer discovery
- industrial machines
- resin/metal printers
- technology classification
- discontinued models

Recommended as a secondary discovery source, not canonical structured data.

---

# 8. 3DPros

Database:

`https://3dpros.com/`

Useful dimensions include:

- price
- build volume
- release date
- brand
- specifications
- accessories
- recommendations

Best used for cross-checking consumer printers.

---

# 9. SpoolMath Printer Database

Database:

`https://spoolmath.com/printer/`

This is particularly interesting to PrintQuote because it includes:

- build volume
- architecture
- enclosure
- price
- estimated average wattage
- electricity-cost estimates

This can help build initial:

```text
typicalPowerWatts
```

values when manufacturer documentation only publishes maximum/rated power.

### Important

Average wattage should be stored separately from rated/max wattage.

Example schema:

```swift
var ratedMaximumPowerWatts: Double?
var typicalPrintingPowerWatts: Double?
var typicalIdlePowerWatts: Double?
```

Secondary wattage databases should never overwrite manufacturer rated power.

---

# Manufacturer sources

Official manufacturer specifications should be PrintQuote's highest-priority source for actual hardware capabilities.

---

# 10. Bambu Lab

Official sources:

`https://bambulab.com`
`https://store.bambulab.com`

Many printer pages include downloadable technical specifications / TDS.

Useful fields:

- build volume
- chassis/shell type
- enclosure
- hotend type
- extruder gear material
- nozzle material
- nozzle diameters
- max hotend temperature
- bed temperature
- toolhead speed
- acceleration
- max flow
- supported filament
- carbon/glass-fiber capability
- cameras
- sensors
- connectivity
- machine dimensions
- machine weight
- rated power

### Multi-material data

Also model:

- AMS
- AMS Lite
- AMS 2 Pro
- AMS HT
- slot count
- expansion limits
- drying capability
- material compatibility

Important:

```text
Bambu P1S + AMS
physical toolheads = 1
filament inputs = 4
```

Never represent AMS slots as toolheads.

---

# 11. Prusa Research

Official sources:

`https://www.prusa3d.com`
`https://help.prusa3d.com`

Excellent structured technical parameter pages.

Useful fields:

- build volume
- filament diameter
- layer-height range
- machine dimensions
- weight
- electronics
- extruder design
- nozzle type
- max nozzle temperature
- max bed temperature
- connectivity
- tool count

Prusa is especially important because the XL provides real multi-tool configurations.

PrintQuote should support:

```text
XL single-tool
XL dual-tool
XL five-tool
```

while allowing custom systems up to 12 toolheads.

---

# 12. Anycubic

Official:

`https://store.anycubic.com`

Anycubic product pages often expose unusually useful structured specs:

- printing volume
- construction
- speed
- acceleration
- nozzle max temperature
- nozzle sizes
- bed max temperature
- firmware
- extrusion type
- leveling
- pressure advance
- flow calibration
- sensors
- camera
- dimensions
- weight
- active drying
- multicolor capability

### ACE / ACE 2 Pro

Track separately:

- ACE model/generation
- slots per unit
- expansion count
- maximum colors
- drying temperature
- material compatibility
- change time if available

Example current Kobra S1 ACE 2 Pro configuration:

```text
physical toolheads = 1
base filament inputs = 4
expandable colors = 16
```

---

# 13. Flashforge

Official:

`https://www.flashforge.com`

Product/specification pages expose:

- extruder quantity
- build volume
- bed temperature
- nozzle diameter options
- supported filament
- print speed
- acceleration
- max nozzle temperature
- connectivity
- filament sensors
- outage recovery

### IFS

For printers such as AD5X:

```text
physical toolheads = 1
IFS filament channels = separate field
```

Do not represent IFS inputs as toolheads.

---

# 14. Creality

Official:

`https://www.creality.com`
`https://store.creality.com`

Creality support/product pages can provide:

- build volume
- machine dimensions
- machine weight
- max nozzle temperature
- bed temperature
- active chamber temperature
- rated power
- nozzle diameter
- printer architecture
- supported filament
- speed
- acceleration
- connectivity
- internal storage
- camera
- firmware download/support
- CFS compatibility

### CFS

Creality's CFS should be modeled separately from physical tools.

Example K2 Plus:

```text
physical toolheads = 1
one CFS = 4 filament slots
up to 4 CFS units
max automatic selectable materials = 16
```

Official K2 Plus data also includes a 350°C nozzle, 120°C bed, 60°C active chamber and 1200 W rated power.

These are exactly the fields PrintQuote needs for engineering-material capability and electricity modeling.

---

# 15. ELEGOO

Official:

`https://www.elegoo.com`

Good product pages include:

- build volume
- print speed
- acceleration
- nozzle temperature
- bed temperature
- nozzle material
- enclosure
- material support
- machine dimensions
- weight
- rated power
- connectivity
- camera
- operating system
- supported slicers

Current Centauri-class pages are especially detailed.

---

# 16. QIDI Tech

Official:

`https://qidi3d.com`
regional QIDI stores

QIDI product pages are particularly important for engineering-material printers.

Useful:

- build size
- active chamber heating
- chamber temperature
- nozzle temperature
- material support
- printer enclosure
- auto calibration
- multi-color / QIDI Box compatibility
- price

High priority for:
- PA
- PC
- PPS-class use
- CF/GF materials

---

# 17. Raise3D

Official:

`https://www.raise3d.com`
`https://support.raise3d.com`

One of the best professional-printer specification sources.

Useful structured fields:

- single-extruder build volume
- dual-extruder build volume
- machine size
- weight
- print technology
- print-head system
- filament diameter
- nozzle options
- max nozzle temperature
- max bed temperature
- automatic filament switching
- HEPA/carbon filtration
- electrical data

Important lesson:

PrintQuote must support build volume that changes by active tool configuration.

Example:

```text
single-extruder build volume != dual-extruder build volume
```

Therefore schema should support:

```swift
var buildVolumeByOperatingMode: [OperatingModeBuildVolume]
```

---

# 18. Snapmaker

Official:

`https://www.snapmaker.com`
`https://shop.snapmaker.com`

Excellent for multi-head / IDEX / modular systems.

J1s data includes:

- IDEX architecture
- default mode
- backup mode
- copy mode
- mirror mode
- different build volumes by mode
- max nozzle temperature
- bed temperature
- nozzle options
- material capability

Artisan adds modular 3-in-1 functionality.

PrintQuote should therefore support:

```text
printer technology mode
tool architecture
build volume by mode
```

---

# 19. LulzBot

Official:

`https://lulzbot.com`
`https://buy.lulzbot.com`

TAZ Pro pages include detailed:

- toolhead model
- dual extrusion
- build volume
- nozzle material
- nozzle diameter
- hotend temp
- bed temp
- filament diameter
- movement system
- travel speed
- calibration

Good source for older/open professional machines.

---

# 20. UltiMaker

Official:

`https://ultimaker.com`
UltiMaker support/manual PDFs

Manuals are highly useful.

Example fields:

- build volume
- nozzle / print-core temperature
- bed temperature
- dimensional accuracy
- flow rate
- print-core type
- material ecosystem
- dual-extrusion architecture

Print cores mean nozzle capability may depend on installed tool component.

Model that as a configurable toolhead component.

---

# 21. Voron Design

Official/community:

`https://vorondesign.com`
`https://github.com/VoronDesign`

Voron is not a normal fixed-spec commercial printer.

PrintQuote should treat it as:

```text
configurable/open printer family
```

A Voron 2.4 may be built in multiple sizes and heavily modified.

Do NOT create one fixed universal spec.

Instead:

```text
Voron 2.4
reference configuration
user-defined build size
user-defined hotend
user-defined nozzle
user-defined heater
user-defined chamber behavior
```

This same model works for RatRig and custom machines.

---

# 22. RatRig

Official:

`https://ratrig.com`

Treat similarly to Voron:

- reference size
- configurable kit size
- user-selected hotend
- user-selected electronics
- user mods

Do not hard-code material capability from the frame model alone.

---

# 23. FLSUN

Official:

`https://flsun3d.com`

Useful for delta-specific machines.

Fields should include:

- delta architecture
- cylindrical / circular build area
- build diameter
- build height
- speed
- acceleration
- nozzle
- bed
- enclosure
- chamber capability

PrintQuote's geometry model should not assume all beds are rectangular.

Suggested build volume model:

```swift
enum BuildPlateShape {
    case rectangular
    case circular
    case customPolygon
}
```

---

# 24. Printer source priority

Recommended technical priority:

```text
1. Manufacturer TDS/manual/specification
2. Manufacturer support page / firmware docs
3. OrcaSlicer machine profile
4. Cura machine definition
5. PrusaSlicer vendor bundle
7. Klipper reference configuration
8. Trusted commercial database
9. Community profile
10. User-entered value
```

User override should win locally but retain original source.

---

# 25. Recommended PrintQuote printer schema

Codex should support these categories.

## Identity

```text
manufacturer
model
variant
generation
release year
discontinued
region
SKU
technology
```

## Geometry

```text
build plate shape
build X
build Y
build Z
build diameter
usable area
machine dimensions
machine weight
```

## Motion

```text
cartesian
bedslinger
coreXY
coreXZ
delta
IDEX
toolchanger
belt printer
custom

max speed
recommended speed
max acceleration
```

## Tool system

```text
physical toolhead count: 1...12
simultaneously active tools
shared nozzle
tool architecture
tool changer
IDEX
dual fixed heads
single-nozzle material switching
mixing nozzle
```

## Each toolhead

```text
tool index
nozzle diameter
supported nozzle diameters
nozzle material
max nozzle temperature
extruder type
direct/bowden
abrasive capable
flexible capable
heater power
tool change time
purge behavior
```

## Filament/material inputs

```text
filament input count
automatic selectable material count
manual input count

AMS
AMS Lite
AMS 2 Pro
AMS HT
ACE Pro
ACE 2 Pro
IFS
CFS
MMU
QIDI Box
custom
```

## Thermal

```text
max nozzle temp
max bed temp
active chamber heating
max chamber temp
heated enclosure
air filtration
```

## Material capability

```text
PLA
PETG
ABS
ASA
TPU
PA
PC
PP
PPS
PEEK
PEI
CF filled
GF filled

manufacturerSupported
communityValidated
requiresUpgrade
unsupported
unknown
```

## Electrical

Store separate values:

```text
input voltage
rated max power W
measured/typical printing power W
idle power W
standby power W
heated chamber power if known
feeder/dryer power if known
```

Never use rated power as average electricity usage automatically.

## Connectivity

```text
USB
SD
microSD
Ethernet
Wi-Fi
Bluetooth
NFC
manufacturer cloud
local API
Moonraker
OctoPrint
Bambu LAN
custom
```

## Firmware

```text
Marlin
Klipper
RepRapFirmware
Bambu firmware
Kobra OS
Creality OS
Elegoo OS
Flashforge firmware
Prusa firmware
RaiseTouch
custom
unknown
```

## Automation

```text
auto leveling
flow calibration
pressure advance calibration
input shaping
camera
AI failure detection
filament runout
tangle detection
RFID
power-loss recovery
object exclusion
```

## Costing

```text
purchase price
replacement price
useful life hours
maintenance cost/hour
typical power
failure-rate history
tool-change overhead
material-switch overhead
```

## Provenance

Every important field should include:

```text
source name
source URL
source type
retrieval date
source path
source commit/tag
confidence
user override
```

---

# 26. Toolhead requirement

PrintQuote must continue to support:

```text
1–12 physical toolheads
```

Do not confuse toolheads with filament inputs.

Correct examples:

### Bambu P1S + AMS

```text
physicalToolheads = 1
filamentInputs = 4
automaticSelectableMaterials = 4
simultaneousTools = 1
```

### Anycubic Kobra S1 + ACE 2 Pro

```text
physicalToolheads = 1
filamentInputs = 4
automaticSelectableMaterials = 4+
simultaneousTools = 1
```

### Prusa XL 5-tool

```text
physicalToolheads = 5
filamentInputs = 5
automaticSelectableMaterials = 5
simultaneousTools = 1
```

### Snapmaker J1s

```text
physicalToolheads = 2
architecture = IDEX
simultaneousTools = 2 in applicable modes
```

### Raise3D Pro3 HS

```text
physicalToolheads = 2
architecture = lifting dual extruder
build volume changes in dual-tool mode
```

### Custom toolchanger

```text
physicalToolheads = 1...12
simultaneousTools = configurable
```

---

# 27. Build volume should be mode dependent

Do not store only:

```swift
buildVolumeX
buildVolumeY
buildVolumeZ
```

Some printers lose build area in:
- dual extrusion
- mirror mode
- copy mode
- multiple-tool operation

Use:

```swift
struct OperatingModeBuildVolume: Codable {
    var mode: PrinterOperatingMode
    var widthMM: Double
    var depthMM: Double
    var heightMM: Double
}
```

Examples:

```text
single extrusion
dual extrusion
copy
mirror
toolchanger
full plate
belt
custom
```

---

# 28. Manufacturer source strategy

Codex should create manufacturer adapters/document records such as:

```text
BambuSource
PrusaSource
AnycubicSource
FlashforgeSource
CrealitySource
ElegooSource
QidiSource
Raise3DSource
SnapmakerSource
LulzBotSource
UltiMakerSource
```

Do NOT hard-code web scraping directly into SwiftUI.

Use:

```text
Raw Source
    ↓
Source Adapter
    ↓
Normalized Printer DTO
    ↓
Validation
    ↓
Printer Database
```

---

# 29. Versioning

Every printer record should support versions.

Example:

```text
Creality K2
Creality K2 Pro
Creality K2 Plus
```

Do not merge them.

Likewise:

```text
Anycubic Kobra S1
Kobra S1 Combo
Kobra S1 + ACE Pro
Kobra S1 + ACE 2 Pro
```

A "combo" should ideally be modeled as:

```text
base printer
+
installed accessory configuration
```

rather than duplicated hardware whenever practical.

---

# 30. Accessories should modify capability

Examples:

```text
P1S
+ AMS

Kobra S1
+ ACE 2 Pro

AD5X
+ IFS

K2 Plus
+ CFS

MK4S
+ MMU

QIDI Plus4
+ QIDI Box
```

Printer capability should be calculated from:

```text
BasePrinter
+ InstalledAccessories
+ Toolheads
+ UserUpgrades
```

This will prevent a huge amount of duplicate data.

---

# 31. Upgrade tracking

Allow user modifications:

```text
hardened nozzle
hardened gears
high-flow hotend
enclosure
chamber heater
external dryer
Beacon probe
CAN toolhead
custom extruder
firmware conversion
```

Material compatibility may change after an upgrade.

Example:

```text
stock nozzle:
PA-CF = not recommended

hardened nozzle + gears:
PA-CF = supported with conditions
```

---

# 32. Electricity source quality

PrintQuote should distinguish:

```text
Manufacturer rated maximum
Manufacturer typical
Measured independent average
User measured
Estimated
```

Example:

```swift
enum PowerDataQuality {
    manufacturerRated
    manufacturerTypical
    measuredIndependent
    userMeasured
    estimated
}
```

This is important because a printer rated at 1200 W may average far less during an actual job.

---

# 33. Recommended first importer stack

Codex should implement sources in this order:

## Phase 1

1. OrcaSlicer
2. Cura
4. manufacturer overrides
5. manual user editing

## Phase 2

6. PrusaSlicer vendor bundles
7. Klipper configs
8. average-power database
9. accessory database
10. printer-price database

---

# 34. Suggested normalized source precedence by field

## Build volume

```text
Manufacturer
→ Orca
→ Cura
→ PrusaSlicer
→ secondary DB
```

## Toolheads

```text
Manufacturer
→ Cura extruder definitions
→ Orca machine profile
→ PrusaSlicer
→ manual review
```

## Max nozzle / bed / chamber temperatures

```text
Manufacturer only preferred
→ verified slicer profile as fallback
```

Do not interpret slicer print temperatures as hardware maximum temperature.

## Supported material

```text
Manufacturer
→ manufacturer accessory requirement
→ Orca profile compatibility
→ validated community
```

## Power

```text
Manufacturer rated power
+
measured average source
+
user measured override
```

Never collapse all three into one number.

---

# 35. Codex implementation recommendation

Create:

```text
PrinterSourceProvider
```

protocol.

Example Swift:

```swift
protocol PrinterSourceProvider {
    var sourceName: String { get }

    func fetchPrinterRecords() async throws -> [RawPrinterRecord]

    func sourceMetadata() async throws -> SourceMetadata
}
```

Providers:

```text
OrcaPrinterSourceProvider
CuraPrinterSourceProvider
ManufacturerPrinterSourceProvider
LocalJSONPrinterSourceProvider
```

Then normalize via:

```text
PrinterNormalizer
```

and resolve conflicts via:

```text
PrinterSourceResolver
```

---

# 36. Do not silently merge conflicting data

Example:

```text
Orca:
build Z = 250 mm

Manufacturer:
build Z = 256 mm

Bambu slicer usable default:
250 mm because of cutter clearance
```

These may all be correct in context.

Store:

```text
physicalBuildHeight = 256
defaultUsableBuildHeight = 250
conditionalMaximumBuildHeight = 256
```

with notes.

This is much better than overwriting one with another.

---

# 37. Recommended source-status labels

UI/database:

```text
Manufacturer Verified
Official Slicer Profile
Community Maintained
Measured
Imported
Needs Review
User Override
Legacy
Discontinued
```

---

# 38. Recommended Codex instruction

Give Codex this:

> Build PrintQuote's printer database around normalized, source-attributed records. Use OrcaSlicer machine profiles, UltiMaker Cura machine/extruder definitions, PrusaSlicer vendor bundles, and official manufacturer specifications. Manufacturer documentation must take precedence for physical hardware limits. Keep physical toolheads (1–12), filament inputs, automatic material switching slots, and simultaneously active tools as separate fields. Support mode-dependent build volume for IDEX, dual extruder, copy/mirror and toolchanger systems. Store rated maximum power separately from measured/typical power. Every imported value must retain source URL/path, retrieval date, and confidence. Build all importers behind provider/normalizer abstractions so the later Kotlin/Windows port can consume the same normalized JSON database.

