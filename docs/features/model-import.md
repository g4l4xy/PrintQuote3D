# STL and 3MF inspection

Import a local STL or 3MF from **Inspect model** on every platform. Review a searchable report before using values in a quote. Import never modifies saved quotes, printer profiles or material costs.

The first milestone reads ASCII/binary STL geometry and inventories 3MF packages, mesh resources, components/build transforms, materials and slicer metadata. OrcaSlicer/Bambu Studio JSON settings, model settings, slice information and G-code comment metadata retain their original keys, scopes and source paths. Unknown metadata remains inspectable. Settings and slicer-reported results are separate categories. Units for STL are unknown. Mesh resource bounds are local coordinates, not assembled build dimensions. Material usage and time are slicer estimates, not measured printer consumption.

Do not infer support/tower grams from enable flags, infer filament from STL, sum duplicate project/G-code statistics, or execute embedded G-code. This milestone does not slice, render meshes, repair topology, resolve transformed assembly bounds, decode proprietary painting/texture payloads, or apply values to quote inputs. Binary assets are inventoried, not decoded. Reports are temporary; original files remain unchanged.

Limits: source 512 MiB, total expanded 512 MiB, individual ZIP entry 128 MiB, 4,096 entries, 30,000 report fields, 64 KiB per field, XML/JSON nesting 64. Reject unsafe paths, duplicate names, DTD/entity declarations, nonfinite STL coordinates, malformed STL and limit violations. Corrupt metadata fails the import with an error rather than producing a misleading complete report. No archive member is extracted to a filesystem path.

Verification and remaining work are recorded at delivery. Interaction testing must remain separate from compilation; do not launch the user's Xcode app automatically.

Sources: [3MF Core](https://github.com/3MFConsortium/spec_core/blob/master/3MF%20Core%20Specification.md), [Orca archive implementation](https://github.com/OrcaSlicer/OrcaSlicer/blob/main/src/libslic3r/Format/bbs_3mf.cpp), [Bambu archive implementation](https://github.com/bambulab/BambuStudio/blob/master/src/libslic3r/Format/bbs_3mf.cpp).

## Validation in progress

Android assembled and passed lint and all 18 tests, including four deterministic importer tests and an opt-in local real-model test. The user's model is not included in the repository. Local Apple checks are blocked by the installed Xcode license agreement; the project plist validates. Apple build-only CI is included for package tests and macOS/iOS compilation. Windows build/package validation is in progress. No new app/simulator interaction checks have been performed.
