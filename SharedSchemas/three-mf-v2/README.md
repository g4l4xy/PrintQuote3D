# 3MF manufacturing import contract · v2

`manufacturing.schema.json` defines the entire portable result. Individual `*.schema.json` files expose definitions for projects, printers, tools, materials, plates, objects, settings, diagnostics and other public models. Portable exports use ISO-8601 dates. Swift's private cache uses its own default Date encoding and is **not** the interchange representation. Monetary fields are JSON decimal numbers and must decode into a decimal type, never a binary floating-point currency calculation.

`*.3mf` files are synthetic fixtures generated from tetrahedra and authored metadata. They are not vendor certification samples or customer files. `golden.json` contains shared acceptance values; `*.normalized.json` are complete representative exports with stable diagnostic IDs/import dates. Source hashes correspond to the committed fixture bytes. Regeneration may update ZIP timestamps and hashes.

## Semantics

- Unknown fields are absent, not zero. Every typed imported value carries source path/key/type and independent confidence.
- `physicalToolheads`, `extruderCount`, `nozzleCount`, `filamentInputs`, and `feederSlots` are independent. Feeder capacity and material array lengths never determine physical toolheads.
- `objects` contains resource definitions and `instance:` build instances. Resource `children` reference resources; instance `children` reference instances. `resourceID` joins them. `sourceTransform` is the composed, canonical-millimeter affine transform; the literal source attribute is in `standardMetadata`.
- Quantities are source observations, not additive line items. Preserve role, plate, material, scope and units. Do not sum competing time estimates or total consumption with model/support/purge subtotals.
- Standard property/color IDs include source model paths. Slicer material slots use `filament:N` when unambiguous; independent profile sources retain distinct IDs and provenance. A material record is not necessarily a distinct physical spool.
- A plate's `objectIDs` are the slicer's source object IDs. Do not equate them with global build-instance IDs without resolving the source hierarchy and placement metadata.
- `standardMetadata` preserves core attributes and relationship evidence. `slicerMetadata` preserves raw scoped configuration records, including mapped fields. `unmappedMetadata` identifies unsupported evidence. Painted support/color data remains raw where no semantic adapter exists.
- No low-confidence match selects or overwrites a saved configuration. Embedded cost remains evidence; inventory/configured prices stay authoritative.
- `sourceType=derived` distinguishes measurements/calculations from file-provided values. Geometry volume is not automatically converted into print weight.

## Reproduce

From the repository root:

```sh
python3 tools/three-mf/generate-fixtures.py
python3 tools/three-mf/generate-schema.py
swift test
swift build --product ThreeMFProbe
# In a Python environment containing jsonschema==4.25.1:
python3 tools/three-mf/validate-contract.py --write-goldens
```

Run `ThreeMFProbe FILE --normalized` for an explicit full metadata export, or omit that flag for a summary containing counts and diagnostic codes. `--compare` also runs the legacy inspector. Never commit a customer's normalized metadata or original model as a fixture without permission.

Kotlin/Windows parity is intentionally planned for a later implementation. Use these same fixtures, provenance meanings, partial/fatal behavior and quote-update rules with native Kotlin parsing libraries.
