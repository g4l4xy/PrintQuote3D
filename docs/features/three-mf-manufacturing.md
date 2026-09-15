# Manufacturing 3MF subsystem

The supplied [manufacturing brief](three-mf-manufacturing-brief.md) is implemented as a dedicated Swift pipeline, separate from the legacy inspector. The brief explicitly schedules Kotlin parity later; Android and Windows retain their existing importer. The [portable schemas and fixtures](../../SharedSchemas/three-mf-v2/README.md) define the later parity contract.

## Architecture and behavior

`ThreeMFImportService` snapshots and fingerprints the selected file, then runs container inspection, standard parsing, metadata routing, slicer detection, a family adapter and geometry analysis off the main UI thread. Printer/filament matching and compatibility review run separately from the parsed-result cache so saved configurations and prices are always current.

| Layer | Responsibility |
|---|---|
| Safe archive reader | Controlled temporary snapshot, SHA-256, read-only source access, path/CRC/size/ratio validation, cancellation and time budget |
| Container manifest | Inventory, content-type overrides and relationships; no external URLs fetched; root fallback is explicitly diagnosed |
| Standard parser | Event-based XML, resources, build/component instances, core material/color properties, source metadata, units and affine transforms |
| Metadata router | JSON, XML, INI/config and G-code comment evidence with source paths/scopes; optional image-header validation |
| Detector and adapters | Orca, Bambu, Prusa, Anycubic and Creality known-key families; explicit version-coverage policy; conservative generic fallback |
| Domain model | Typed printer, independent tool/feeder counts, materials, assignments, plates, process/purge settings, quantities and provenance |
| Review services | Printer aliases and candidates, saved and catalog filament matches, configuration differences, volume/material/tool/feeder warnings |
| Quote preview | Explicit field selection, one plate/source per pricing field, quote snapshots, preserved overrides and a separate Save action |

Nozzle entries, material counts and feeder slots **never become a physical toolhead count**. Explicit 1–12 tool configurations are supported. The small alias seed contains the user's P1S and XL5 acceptance baselines; those values are labeled `printerProfile` with medium confidence and still need review. It does not claim a complete verified hardware catalog.

Conflicting machine fields remain raw evidence and suppress a global selection. Per-plate overrides do not replace global machine identity. Material profiles retain independent source evidence; a material record does not necessarily represent a separate spool. Prusa multi-tool extruder assignments can carry physical tool indexes when a physical configuration is known; ambiguous slicer slot mappings remain reviewable evidence.

The review offers duplicate-source detection, opening an existing quote, creating a new draft, reanalysis, differences and selected updates. Imported hardware modifies only the explicitly accepted quote snapshot. Embedded slicer cost is retained separately and never automatically replaces user/configured prices. Existing per-tool jobs are protected from accidental scalar quantity replacement and require review in the quote editor.

## Recovery and trust

Invalid optional metadata/images produce recoverable diagnostics. Valid sibling objects can survive invalid objects/references, cycles and measurement overflow. Sliced packages without meshes can return usable manufacturing metadata with geometry/volume checks explicitly unavailable. Unknown namespaces and metadata remain available as evidence. Source archives are never edited or extracted to archive-specified filesystem paths.

Security-policy violations (DTD/entity declarations, path traversal, excessive expansion, time/depth/count budgets) remain fatal. An entirely unusable container/job returns a fatal diagnostic. Cancellation stops work rather than being presented as damaged metadata.

Measurements use millimeters, grams and seconds. Composed affine matrices preserve scale/rotation even with large translations. Triangle area is not printed material consumption. Mesh volume is withheld for open/inconsistently oriented meshes and for meshes above the topology-check budget. Closed-edge validation does not prove a mesh has no self-intersections; reported volume therefore has medium confidence and never automatically determines weight.

## Default safety and cache limits

All importer limits are configurable through `ThreeMFImportLimits`.

| Budget | Default |
|---|---:|
| Source archive / total expanded archive | 512 MiB each |
| Single entry / metadata entry | 128 MiB / 16 MiB |
| Retained metadata | 16 MiB |
| ZIP entries | 4,096 |
| Compression ratio | 2,000:1 |
| XML depth / component-reference depth | 64 / 64 |
| Distinct XML sibling element names | 4,096 |
| Resource objects / expanded instances | 10,000 / 10,000 |
| Vertices / triangles | 1,000,000 / 1,000,000 |
| Processing budget | 120 seconds per snapshot/parse phase |
| Topology validation | Up to 50,000 triangles per mesh |
| Typed material slots / tool entries | 256 / 12; original metadata remains preserved |
| Cache | 16 results, at most 8 MiB each |

XML is event-based, but each model part is held in a bounded buffer. Geometry arrays are bounded globally. Optional non-image binary assets are checked without retaining their decompressed payload. Thumbnails are checked through image headers without allocating full pixel buffers. This is bounded parsing, not a constant-memory claim for arbitrary meshes.

Cache identity includes content SHA-256, importer `2.0.0`, schema `2`, and safety-policy hash. Changed bytes, versions or policy bypass stale results. Corrupt cache entries are ignored. Reanalysis always bypasses the cache. Source attributes are read fresh from the filesystem, avoiding stale URL attribute caches after saving a replacement file.

Support export includes filename, hash, parser version, detected slicer, diagnostic codes and metadata keys. It excludes geometry, raw metadata values and the original archive. Full normalized exports are available only through an explicit developer probe option; treat them as potentially private.

## Validation evidence

Validation is recorded for this branch; build results do not establish device interaction acceptance.

- **59 Swift tests passed**, including **21 manufacturing tests**. **macOS and iOS Simulator native app builds passed**. **Android APK, unit tests and lint passed** through `./pq check`.
- Shared synthetic fixtures cover the five adapter families, Cura/FlashPrint fallback, generic geometry, multi-plate, AMS, XL5, 1/2/12 tools, IDEX evidence, support/interface settings, transforms/units/mirrors, production references, corrupt thumbnails, malformed metadata, missing meshes, namespace isolation, duplicate IDs, conflicting metadata, truncated ZIPs, traversal, excessive XML depth and expansion limits.
- Property tests exercise transforms and malformed inputs. Cache tests cover changed content, versions, policy, corruption and original-file preservation. Cancellation is tested both before reading and during geometry analysis.
- All **38 synthetic fixture results**, including partial/fatal results, is validated against the portable JSON Schema. Complete normalized examples accompany the golden acceptance values.
- Two local Bambu Studio exports were read without adding them to the repository: a project with **458,724 triangles**, and a sliced G-code package without mesh resources. Both produced useful results. The first exposed a duplicate-plate reference; the second exposed metadata-only recovery and G-code profile grouping. Each now has a synthetic regression fixture.
- A read-only legacy/new comparison probe is retained for migration. The legacy inspector stays available, including STL support. A corrupt optional thumbnail is explicitly tested as legacy failure/new partial success.

Measured release-build synthetic performance is recorded in [performance evidence](three-mf-performance.md). Run `swift build -c release --product ThreeMFProbe` then `python3 tools/three-mf/benchmark.py` to reproduce it. Artifacts are written under ignored `.workflow/`.

## Boundaries that remain explicit

- Real exporter coverage in this pass is Bambu Studio. Other adapter families are covered by authored fixtures; that is not certification across every slicer release.
- Cura/FlashPrint use standard geometry and raw metadata fallback. Unknown/new vendor schemas remain evidence instead of guessed fields.
- Painted support/color encodings, advanced extensions and some object/tool assignments remain raw where semantics are not established. The subsystem does not slice toolpaths, derive missing support/purge grams, or provide a 3D viewer.
- Plate membership retains source object IDs; resource/build-instance resolution must not be guessed when a slicer supplies ambiguous placement IDs.
- Compatibility warnings are advisory. Bounds checks do not prove printer readiness, bed placement clearance, printable topology or material safety.
- iPhone/iPad/macOS interaction testing is unverified. No application or simulator was launched during this work; native Xcode builds are build-only verification.
- Android/Windows implementations of the new normalized manufacturing review are deferred by the supplied brief. Existing Android regression/build checks still run to guard shared-project compatibility.

## Specification references

- [3MF Core Specification](https://github.com/3MFConsortium/spec_core/blob/master/3MF%20Core%20Specification.md)
- [3MF Production Extension](https://github.com/3MFConsortium/spec_production/blob/master/3MF%20Production%20Extension.md)
- [3MF Materials Extension](https://github.com/3MFConsortium/spec_materials/blob/master/3MF%20Materials%20Extension.md)
- [PrusaSlicer 3MF implementation](https://github.com/prusa3d/PrusaSlicer/blob/master/src/libslic3r/Format/3mf.cpp)
- [OrcaSlicer 3MF implementation](https://github.com/OrcaSlicer/OrcaSlicer/blob/main/src/libslic3r/Format/bbs_3mf.cpp)
- [Bambu Studio 3MF implementation](https://github.com/bambulab/BambuStudio/blob/master/src/libslic3r/Format/bbs_3mf.cpp)
