You are working on **PrintQuote 3D**.

I want you to perform a major reliability and architecture upgrade of the code responsible for importing **3MF files**, with special emphasis on **printer-specific information, slicer metadata, machine configuration, toolheads, filament assignments, and manufacturing data**.

This is not a cosmetic refactor.

Treat this as a serious parser/importer hardening project.

The goal is for PrintQuote 3D to safely ingest 3MF files created by different slicers and extract as much useful printer/manufacturing information as possible without crashing, silently misinterpreting fields, or tightly coupling the app to one slicer's implementation.

# Primary goal

Upgrade the 3MF import system so it can reliably handle files produced by:

* OrcaSlicer
* Bambu Studio
* PrusaSlicer
* Anycubic Slicer / Anycubic Slicer Next
* Creality Print
* FlashPrint where applicable
* Cura where applicable
* generic standards-compliant 3MF files
* partially compatible or unknown slicers

The parser should distinguish between:

1. **standard 3MF information**
2. **slicer-specific metadata**
3. **printer-specific information**
4. **material/filament assignments**
5. **toolhead/extruder assignments**
6. **process/slicing information**
7. **PrintQuote inferred values**
8. **unknown/unmapped values**

Do not flatten all of these into one generic dictionary.

# 1. Do not assume every 3MF has the same structure

3MF is a ZIP-based container format and slicers may include:

* standard model resources
* object geometry
* relationships
* thumbnails
* build information
* metadata
* custom slicer configuration
* printer settings
* filament settings
* process settings
* plate information
* object-specific settings
* modifier meshes
* support objects
* purge structures
* custom extensions

The importer must inspect the archive instead of assuming hardcoded filenames beyond standards-required paths.

Create a clear container-inspection stage.

Conceptually:

```text
3MF File
   ↓
ZIP Container Reader
   ↓
Manifest / Relationships Inspection
   ↓
Standard 3MF Parser
   ↓
Slicer Detection
   ↓
Slicer-Specific Adapter
   ↓
Normalized PrintQuote Model
```

# 2. Separate standard parsing from slicer-specific parsing

Create separate layers such as:

```text
ThreeMFContainerReader
ThreeMFStandardParser
ThreeMFSlicerDetector
ThreeMFMetadataRouter
```

Then slicer adapters such as:

```text
OrcaThreeMFAdapter
BambuThreeMFAdapter
PrusaThreeMFAdapter
AnycubicThreeMFAdapter
CrealityThreeMFAdapter
GenericThreeMFAdapter
```

Do not put slicer-specific key parsing into the generic 3MF parser.

The generic parser must still successfully load the file even if the slicer-specific adapter does not recognize some metadata.

# 3. Preserve unknown metadata

Unknown metadata must NOT simply be discarded.

Store unmapped metadata in a structured diagnostics collection.

Example:

```swift
struct UnmappedThreeMFMetadata: Codable {
    var sourcePath: String
    var namespace: String?
    var key: String
    var value: String?
    var rawXMLSnippet: String?
}
```

Equivalent Kotlin representation should be planned later.

This allows us to add support for new slicer versions without losing evidence about what was in the file.

# 4. Detect source slicer

Attempt to identify:

* slicer name
* slicer version
* application name
* generator
* file-format version
* vendor-specific metadata version

Example result:

```text
Slicer:
OrcaSlicer

Version:
2.x.x

Confidence:
High
```

If uncertain:

```text
Slicer:
Unknown / Orca-compatible

Confidence:
Low
```

Never invent a definite slicer identity.

# 5. Normalize printer identity

Attempt to extract printer identity such as:

* manufacturer
* model
* variant
* configured machine preset name
* machine preset ID
* nozzle variant
* printer profile name
* printer profile source
* printer profile version

Normalize this into a PrintQuote model.

Example:

```text
Manufacturer:
Bambu Lab

Model:
P1S

Configuration:
P1S 0.4 nozzle

Imported preset:
Bambu Lab P1S 0.4 nozzle

Source:
3MF / slicer metadata
```

Do not assume the preset name alone is trustworthy.

Run it through the existing printer database matching system.

# 6. Printer matching engine

Build a dedicated matching stage.

Example:

```text
Imported machine metadata
       ↓
Normalize manufacturer
       ↓
Normalize model string
       ↓
Check known aliases
       ↓
Match PrinterModel
       ↓
Match PrinterConfiguration
```

Examples of aliases:

```text
Bambu Lab
Bambu
BBL
```

or:

```text
Anycubic Kobra S1
Kobra S1
Anycubic-Kobra-S1
```

Return:

```text
Exact Match
High Confidence Match
Possible Match
No Match
```

Never silently select a low-confidence match.

# 7. Do not overwrite user's existing printer

If a 3MF references a known printer but the user's saved printer configuration contains:

* custom nozzle
* hardened gears
* modified toolhead
* custom chamber
* external dryer
* firmware modifications

do not overwrite that configuration.

The import should instead say:

```text
3MF printer:
Flashforge AD5X 0.4 mm

Your configured printer:
AD5X — Engineering
0.6 mm hardened nozzle

Configuration differs.
```

Then allow:

* Use 3MF settings
* Use my printer configuration
* Review differences

# 8. Physical toolheads must stay separate from filament inputs

This requirement is critical.

The parser must distinguish:

```text
physical toolheads
extruders
nozzles
filament slots
AMS slots
ACE slots
IFS slots
MMU slots
CFS slots
material IDs
color IDs
```

Example:

```text
Bambu P1S + AMS

Physical toolheads:
1

Filament inputs:
4

Materials:
4

Colors:
4
```

This must NOT become:

```text
toolheads = 4
```

PrintQuote supports:

```text
1–12 physical toolheads
```

and the importer must preserve that architecture.

# 9. Toolhead extraction

Attempt to extract:

* toolhead count
* extruder count
* active extruders
* nozzle count
* nozzle diameter per tool
* nozzle material if available
* tool assignments
* filament assignment by tool
* support-tool assignment
* interface-tool assignment

Normalize into:

```text
PrinterToolSystem
```

and:

```text
ToolheadConfiguration[]
```

If toolhead count is ambiguous:

```text
needsReview = true
```

Never infer physical toolhead count from the number of materials.

# 10. Filament/material extraction

Extract as much as possible:

* filament type
* filament preset
* manufacturer
* product name
* material family
* material subtype
* color
* color hex
* density
* diameter
* spool/profile ID
* extrusion temperature
* bed temperature
* chamber temperature
* flow ratio
* maximum volumetric speed
* filament cost if explicitly embedded
* drying settings if embedded
* abrasive flags if represented

Map imported filament profiles to the existing PrintQuote filament database.

Matching results:

```text
Exact
Likely
Generic material only
Unknown
```

# 11. Material assignment

Track material assignment per:

* object
* part
* volume
* tool
* extruder
* support
* support interface
* purge tower
* modifier

Do not reduce a multi-material 3MF to:

```text
materials = 4
```

when richer assignment data exists.

# 12. Color extraction

Extract:

* RGB/HEX color
* material color ID
* filament color
* paint/face coloring if represented
* object/part color assignment

Store actual source color separately from user-selected display color.

Example:

```text
sourceColorHex
normalizedColorHex
manufacturerColorName
```

# 13. Build plate information

Extract:

* plate count
* active plate
* plate names
* objects per plate
* printer assignment per plate if available
* plate-specific process settings
* plate-specific filament usage
* plate-specific estimated print time
* bed type
* bed surface
* bed temperature

A multi-plate 3MF should not be treated as one undifferentiated job.

# 14. Object hierarchy

Preserve:

```text
model
assembly
object
part
volume
modifier
support object
```

when the 3MF provides this information.

Do not automatically flatten geometry.

PrintQuote should eventually be able to price:

```text
Object 1
Object 2
Object 3
```

independently.

# 15. Geometry validation

For each printable object, extract:

* bounding box
* dimensions
* triangle count
* volume
* surface area if practical
* transform matrix
* instance count
* mirrored state
* scaling
* rotation
* translation

Apply transforms correctly before computing final dimensions.

Avoid a common importer bug where raw mesh dimensions are reported instead of transformed build dimensions.

# 16. Unit handling

3MF may define model units.

Normalize everything into PrintQuote's canonical unit system.

Recommended internal units:

```text
length:
millimeters

weight:
grams

temperature:
Celsius

time:
seconds internally

energy:
kWh

currency:
Decimal
```

Never assume imported geometry is always millimeters without checking.

# 17. Process settings

Extract useful process metadata where available:

* layer height
* first-layer height
* wall/perimeter count
* top layers
* bottom layers
* infill percentage
* infill pattern
* print speed
* travel speed
* support enabled
* support type
* support threshold
* support interface
* raft
* brim
* skirt
* adaptive layers
* ironing
* fuzzy skin
* sequential printing
* variable layer height

Do not make the pricing engine depend on every one of these initially.

Store them so they can be used later.

# 18. Print-time extraction

If the 3MF contains slicer-estimated print time:

extract it with:

* value
* units
* source
* plate
* confidence

Example:

```text
Estimated print time:
8h 42m

Source:
OrcaSlicer metadata

Confidence:
High
```

If multiple estimates exist:

preserve them rather than arbitrarily selecting one.

# 19. Filament usage extraction

Extract when available:

* model material
* support material
* support-interface material
* purge material
* prime tower
* skirt
* brim
* flush
* total extrusion
* material by filament
* material by plate
* material by object

Store grams and length when available.

Do not confuse:

```text
filament used by the finished object
```

with:

```text
total filament consumed by the print
```

Both are important for PrintQuote.

# 20. Purge and flush information

This is critical for pricing.

Extract if available:

* purge volume
* flush volume
* purge multiplier
* flushing matrix
* purge tower volume
* prime tower dimensions
* purge into infill settings
* purge into supports
* purge into object
* filament change count
* tool-change count

For single-nozzle multi-color systems, this information can materially affect quote cost.

# 21. Filament-change calculation

If the slicer explicitly stores change count, use it.

If not, only derive it when there is enough reliable information.

Mark derived values:

```text
source = inferred
```

Do not present inferred change counts as exact slicer values.

# 22. Supports

Extract:

* support enabled
* support material
* support interface material
* support extruder
* interface extruder
* estimated support material
* support object data
* manual painted supports if identifiable

Map into PrintQuote:

```text
supportMaterialGrams
supportInterfaceGrams
supportTool
supportRemovalComplexity
```

Do not invent support-removal labor solely from support-enabled status.

# 23. Build-volume validation

After matching the printer:

check each plate/object against:

* usable build volume
* operating-mode build volume
* selected toolhead configuration
* nozzle/tool mode

Return warnings such as:

```text
Model exceeds configured build volume.
```

or:

```text
3MF was sliced for a different printer configuration.
```

# 24. Tool-specific build volumes

Remember some machines have:

* single-tool build volume
* dual-tool build volume
* copy-mode volume
* mirror-mode volume

Use PrintQuote's operating-mode-specific build-volume model.

# 25. Printer compatibility check

After import:

run:

```text
PrinterCompatibilityEngine
MaterialCompatibilityEngine
ToolheadCompatibilityEngine
FeederCompatibilityEngine
```

Example:

```text
Imported material:
PA-CF

Imported printer:
P1S

Imported nozzle:
0.4 mm stainless

Warning:
Abrasive material may require hardened nozzle/gears.
```

Do not block import because of a compatibility warning.

# 26. Imported vs current configuration

Create a comparison object.

Example:

```text
Imported 3MF                  Current PrintQuote Printer

0.4 nozzle                    0.6 hardened nozzle
AMS enabled                   AMS enabled
PLA                           ASA
4 inputs                      4 inputs
```

Give the user a review screen.

# 27. Partial parsing

The parser should return useful data even when one section fails.

Example result:

```text
Geometry:
Success

Printer:
Success

Materials:
Success

Process metadata:
Partial

Thumbnail:
Failed

Unknown extension:
Ignored safely
```

Do not fail the entire file unless the basic 3MF container/model is unusable.

# 28. Error severity

Use categorized diagnostics:

```text
Info
Warning
Recoverable Error
Fatal Error
```

Examples:

```text
Info:
Unknown metadata key preserved.

Warning:
Printer profile could not be matched.

Recoverable Error:
One thumbnail could not be decoded.

Fatal Error:
ZIP container is corrupted and core model cannot be read.
```

# 29. Security

Treat 3MF files as untrusted input.

Protect against:

* ZIP bombs
* path traversal
* malformed XML
* excessive nesting
* giant allocation requests
* unreasonable triangle counts
* malicious relationships
* invalid file paths
* invalid UTF data
* oversized metadata
* recursive references

Never extract archive entries directly to arbitrary disk paths.

Use safe in-memory or controlled-temp extraction.

# 30. ZIP bomb protection

Set hard safety limits.

Examples:

```text
maximum archive size
maximum uncompressed size
maximum entry count
maximum entry size
maximum compression ratio
maximum XML depth
```

Values should be configurable.

Do not load an unlimited decompressed archive into RAM.

# 31. XML parsing security

Disable or reject:

* external entities
* DTD loading
* remote entity resolution

Prevent XXE-style behavior.

The parser must never fetch arbitrary URLs referenced inside an uploaded 3MF.

# 32. Streaming where practical

For large XML/model resources:

prefer streaming/event-based parsing when possible.

Avoid constructing massive full XML trees unnecessarily.

# 33. Cancellation

Parsing should be cancellable.

UI:

```text
Importing project…
[██████████------]
Parsing materials…
Cancel
```

Cancellation should stop work cleanly.

# 34. Progress reporting

Stages:

```text
Opening file
Inspecting archive
Reading relationships
Parsing model
Parsing metadata
Detecting slicer
Parsing printer settings
Parsing materials
Parsing process settings
Analyzing geometry
Matching printer
Matching filaments
Running compatibility checks
Finalizing
```

# 35. Background parsing

Do not parse 3MF files on the main UI thread.

Use async/background work.

The UI must remain responsive.

# 36. Import result model

Create a rich result.

Example:

```swift
struct ThreeMFImportResult {
    var project: ImportedPrintProject?

    var slicer: DetectedSlicer?
    var printer: ImportedPrinterConfiguration?
    var materials: [ImportedMaterial]
    var plates: [ImportedPlate]
    var objects: [ImportedObject]
    var processSettings: ImportedProcessSettings?

    var estimatedPrintTimeSeconds: Double?
    var totalMaterialGrams: Double?
    var modelMaterialGrams: Double?
    var supportMaterialGrams: Double?
    var purgeMaterialGrams: Double?

    var diagnostics: [ImportDiagnostic]
    var unmappedMetadata: [UnmappedThreeMFMetadata]

    var confidence: ImportConfidence
}
```

Do not reduce result to just:

```text
Model + metadata dictionary
```

# 37. Confidence scoring

Score imported information independently.

Example:

```text
Geometry:
High

Printer identity:
High

Toolhead count:
Medium

Filament identity:
High

Filament cost:
Unknown

Print time:
High

Purge:
Medium
```

This is more useful than one global confidence number.

# 38. Provenance

Every meaningful imported value should support provenance.

Example:

```swift
struct ImportedValue<T> {
    var value: T
    var sourcePath: String?
    var metadataKey: String?
    var sourceType: ImportSourceType
    var confidence: ImportConfidence
}
```

Source types:

```text
standard3MF
slicerMetadata
printerProfile
filamentProfile
derived
userOverride
```

# 39. Do not silently convert inferred values into source values

Example:

If weight is calculated from:

```text
mesh volume × filament density
```

then store:

```text
source = derived
```

not:

```text
source = slicer
```

# 40. Version-specific adapters

Slicer metadata changes over time.

Adapters should support version-aware parsing.

Example:

```text
Orca adapter
 ├── supported metadata family A
 ├── supported metadata family B
 └── unknown/new metadata fallback
```

Avoid giant chains of fragile string comparisons scattered through the app.

# 41. Adapter capabilities

Each adapter should declare capabilities.

Example:

```text
printer metadata      supported
filament metadata     supported
process metadata      supported
plate metadata        supported
purge metadata        partial
thumbnail             supported
```

# 42. Raw-file fixtures

Create a test fixture library.

Include representative 3MF files from:

* OrcaSlicer
* Bambu Studio
* PrusaSlicer
* Anycubic Slicer
* Creality Print
* generic 3MF
* single-material
* multicolor
* multimaterial
* multi-plate
* support-material jobs
* toolchanger jobs
* IDEX jobs
* corrupted file
* partially valid file
* giant metadata file

Do not commit copyrighted or customer files without permission.

Use synthetic fixtures where needed.

# 43. Golden parser tests

For each fixture, define expected normalized values.

Example:

```text
fixture:
bambu_p1s_ams_4color.3mf

expected:
printer = P1S
physicalToolheads = 1
filamentInputs = 4
materials = 4
nozzleDiameter = 0.4
```

This specifically prevents the classic error:

```text
4 AMS slots → 4 toolheads
```

# 44. Multi-tool fixture

Example:

```text
fixture:
prusa_xl_5tool.3mf

expected:
physicalToolheads = 5
filamentInputs >= 5
architecture = toolChanger
```

# 45. Regression tests

Whenever a real-world 3MF breaks import:

1. create a sanitized fixture
2. add a test reproducing it
3. fix parser
4. retain regression fixture permanently

Do not fix parsing bugs without adding regression coverage.

# 46. Fuzz testing

Add fuzz/property testing for:

* malformed ZIP entries
* random XML ordering
* missing metadata
* duplicated metadata
* unknown namespaces
* truncated files
* excessive object counts
* invalid transforms

The importer should fail safely, not crash.

# 47. Performance tests

Test at least:

```text
small:
< 5 MB

medium:
20–100 MB

large:
100–500 MB where practical
```

Track:

* parse time
* peak memory
* object count
* triangle count

Set reasonable performance budgets.

# 48. Import cache

Cache parsed results using:

```text
file content hash
+
parser version
```

If the same unchanged 3MF is opened again:

reuse normalized metadata when safe.

Invalidate cache if:

* file changes
* parser version changes
* schema version changes

# 49. Parser version

Add:

```text
threeMFImporterVersion
```

to imported projects.

This allows old imported projects to be reparsed when importer quality improves.

# 50. Reimport support

Add:

```text
Re-analyze 3MF
```

This should:

* preserve user-entered quote data
* rerun the improved parser
* show differences
* let the user accept selected updates

Never blindly replace an existing quote.

# 51. Import review screen

After a rich 3MF is imported, show:

```text
3MF IMPORT SUMMARY

Printer
Bambu Lab P1S
Matched: High confidence

Tool system
1 toolhead
4 AMS inputs

Materials
1 Black PLA
2 White PLA
3 Red PLA
4 Blue PLA

Print time
8h 42m

Material
Model: 183 g
Support: 22 g
Purge: 71 g
Prime tower: 18 g

Warnings
• Purge accounts for 24% of consumed filament
```

Allow:

```text
Accept Import
Review Details
Choose Different Printer
Choose Different Filament
```

# 52. Price data

Do not trust embedded filament pricing blindly.

If the slicer file contains material cost:

store it as:

```text
embeddedSlicerCost
```

Then compare with:

```text
user inventory cost
current PrintQuote material price
```

Default pricing priority should remain:

```text
user actual inventory cost
→ configured pricing source
→ current catalog
→ embedded slicer price
→ fallback estimate
```

# 53. Never mutate source file

3MF import must be read-only.

Do not modify the original file.

Any normalized data should be stored separately.

# 54. File fingerprint

Store:

```text
SHA-256
file size
filename
import date
```

for provenance and cache use.

# 55. Duplicate detection

If the same 3MF is imported again:

detect it.

Offer:

```text
Open existing quote
Create new quote from same file
Re-analyze source file
```

# 56. Logging

Use structured log categories:

```text
3MF.Container
3MF.XML
3MF.Geometry
3MF.Metadata
3MF.SlicerDetection
3MF.Printer
3MF.Materials
3MF.Toolheads
3MF.Purge
3MF.Compatibility
```

Never log entire customer geometry or private metadata by default.

# 57. Support diagnostics

Support bundles may include:

* filename
* file hash
* parser version
* slicer detection
* metadata keys
* import diagnostics

but should not include full customer model files unless explicitly approved.

# 58. Domain architecture

Target architecture:

```text
File Picker
   ↓
ThreeMFImportService
   ↓
SafeArchiveReader
   ↓
ThreeMFContainerManifest
   ↓
StandardThreeMFParser
   ↓
SlicerDetector
   ↓
SlicerAdapter
   ↓
NormalizedThreeMFProject
   ↓
PrinterMatcher
   ↓
FilamentMatcher
   ↓
Compatibility Engines
   ↓
Quote Import Preview
```

# 59. Swift architecture

For the macOS implementation, keep 3MF logic outside SwiftUI.

Potential modules:

```text
Rendering/
  ThreeMF/
    ThreeMFImportService.swift
    SafeArchiveReader.swift
    StandardThreeMFParser.swift
    ThreeMFSlicerDetector.swift
    ThreeMFImportResult.swift
    ThreeMFDiagnostics.swift

    Adapters/
      OrcaThreeMFAdapter.swift
      BambuThreeMFAdapter.swift
      PrusaThreeMFAdapter.swift
      AnycubicThreeMFAdapter.swift
      CrealityThreeMFAdapter.swift
      GenericThreeMFAdapter.swift
```

Do not put XML parsing in a ViewModel.

# 60. Windows parity

Later, the Kotlin implementation should reproduce the same normalized result structure.

Do not require Swift and Kotlin to use identical parser libraries.

They should agree on:

```text
schemas
normalized fields
confidence meanings
toolhead behavior
diagnostic severity
pricing inputs
```

# 61. Shared schemas

Add portable JSON definitions for:

```text
ThreeMFImportResult
ImportedPrintProject
ImportedPrinterConfiguration
ImportedToolSystem
ImportedMaterial
ImportedPlate
ImportedObject
ImportedProcessSettings
ImportDiagnostic
UnmappedMetadata
```

This will make Windows parity easier later.

# 62. Migration path

Do NOT delete the existing importer immediately.

First:

```text
Existing importer
      ↓
wrap with tests
      ↓
introduce new pipeline
      ↓
compare results
      ↓
switch default
      ↓
retain fallback briefly
      ↓
remove legacy importer after confidence is high
```

# 63. Comparison mode during development

For representative 3MF files, log:

```text
Legacy parser:
printer=P1S
materials=4
time=8h42m

New parser:
printer=P1S
materials=4
physicalToolheads=1
AMSInputs=4
purge=71g
time=8h42m
```

Use this to catch regressions.

# 64. Do not over-trust slicer metadata

Some 3MF files may contain:

* stale presets
* renamed presets
* custom presets
* edited printer names
* missing vendor data
* inconsistent nozzle information

Treat metadata as evidence, not absolute truth.

# 65. User-facing trust model

Show labels such as:

```text
Read directly from file
Matched to PrintQuote database
Inferred
User confirmed
Needs review
```

# 66. Required parser guarantees

The importer must guarantee:

1. Unknown metadata cannot crash import.
2. Missing slicer metadata cannot prevent standard 3MF geometry import.
3. Bad thumbnail data cannot fail the job.
4. One malformed object should not necessarily kill valid objects.
5. Filament inputs must never be automatically treated as physical toolheads.
6. Imported printer data must never silently overwrite user configuration.
7. External entities/network resources must never be fetched during XML parsing.
8. Archive extraction must be protected against path traversal and ZIP bombs.
9. UI must remain responsive.
10. Partial successful imports must return diagnostics instead of only throwing an error.

# 67. Priority implementation order

## Phase 1 — Parser foundation

1. SafeArchiveReader
2. container inspection
3. standard model parser
4. relationships parser
5. secure XML settings
6. diagnostic system

## Phase 2 — Normalized model

7. import-result models
8. plates
9. objects
10. materials
11. printer metadata
12. process metadata

## Phase 3 — Slicer adapters

13. OrcaSlicer
14. Bambu Studio
15. PrusaSlicer
16. Anycubic
17. Creality
18. generic fallback

## Phase 4 — Printer intelligence

19. printer matcher
20. alias normalization
21. toolhead extraction
22. feeder/input extraction
23. current-printer comparison
24. compatibility engine

## Phase 5 — Pricing intelligence

25. print time
26. material weight
27. support weight
28. purge
29. prime tower
30. filament changes
31. plate-specific costing

## Phase 6 — Hardening

32. ZIP limits
33. XML limits
34. cancellation
35. progress
36. large-file tests
37. fuzz tests
38. regression fixtures
39. import caching

# 68. Definition of done

The upgraded importer is complete when:

```text
[ ] standard 3MF geometry still imports
[ ] OrcaSlicer files parse
[ ] Bambu Studio files parse
[ ] PrusaSlicer files parse
[ ] Anycubic files have adapter support or safe fallback
[ ] Creality files have adapter support or safe fallback
[ ] generic 3MF works without slicer metadata
[ ] slicer/version detection works
[ ] printer matching works
[ ] physical toolheads remain separate from filament inputs
[ ] 1–12 toolheads are supported
[ ] materials are mapped per tool/object where available
[ ] multiple plates are represented
[ ] transformations are correctly applied
[ ] units are normalized correctly
[ ] print time is captured where available
[ ] model/support/purge usage is separated where available
[ ] purge/change information is captured where available
[ ] compatibility checks run after import
[ ] unknown metadata is preserved
[ ] partial imports return diagnostics
[ ] malformed thumbnails do not kill imports
[ ] archive path traversal is blocked
[ ] ZIP bomb protections exist
[ ] XXE/external entity behavior is disabled
[ ] parsing is cancellable
[ ] parsing is off the main UI thread
[ ] progress reporting exists
[ ] large files do not cause uncontrolled memory growth
[ ] parser regression fixtures exist
[ ] importer version is stored
[ ] file hashes are stored
[ ] duplicate imports can be detected
[ ] existing quote/user data is never silently overwritten
```

# Final instruction

Do not approach this as “add a few more metadata keys.”

Treat the 3MF importer as a dedicated subsystem with:

* secure container handling
* version-aware slicer adapters
* normalized printer/tool/material models
* source provenance
* partial recovery
* diagnostics
* compatibility validation
* test fixtures
* performance protections

The end goal is for a 3MF file to become a **rich manufacturing job import**, not merely a way to retrieve geometry.
