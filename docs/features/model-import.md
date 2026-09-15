# STL and 3MF inspection

Import a local STL or 3MF from **Inspect model** on every platform. Review a searchable report before using values in a quote. Import never modifies saved quotes, printer profiles or material costs.

The first milestone reads ASCII/binary STL geometry and inventories 3MF packages, mesh resources, components/build transforms, materials and slicer metadata. OrcaSlicer/Bambu Studio JSON settings, model settings, slice information and G-code comment metadata retain their original keys, scopes and source paths. Unknown metadata remains inspectable. Settings and slicer-reported results are separate categories. Units for STL are unknown. Mesh resource bounds are local coordinates, not assembled build dimensions. Material usage and time are slicer estimates, not measured printer consumption.

Do not infer support/tower grams from enable flags, infer filament from STL, sum duplicate project/G-code statistics, or execute embedded G-code. This milestone does not slice, render meshes, repair topology, resolve transformed assembly bounds, decode proprietary painting/texture payloads, or apply values to quote inputs. Binary assets are inventoried, not decoded. Reports are temporary; original files remain unchanged.

Limits: source 512 MiB, total expanded 512 MiB, individual ZIP entry 128 MiB, 4,096 entries, 30,000 report fields, 64 KiB per field, XML/JSON nesting 64. Reject unsafe paths, duplicate names, DTD/entity declarations, nonfinite STL coordinates, malformed STL and limit violations. Corrupt metadata fails the import with an error rather than producing a misleading complete report. No archive member is extracted to a filesystem path.

Verification and remaining work are recorded at delivery. Interaction testing must remain separate from compilation; do not launch the user's Xcode app automatically.

Sources: [3MF Core](https://github.com/3MFConsortium/spec_core/blob/master/3MF%20Core%20Specification.md), [Orca archive implementation](https://github.com/OrcaSlicer/OrcaSlicer/blob/main/src/libslic3r/Format/bbs_3mf.cpp), [Bambu archive implementation](https://github.com/bambulab/BambuStudio/blob/master/src/libslic3r/Format/bbs_3mf.cpp).

## Validation — September 14, 2026

- Android: APK assembled, lint passed, 18 tests passed. Includes four deterministic importer tests plus an explicitly enabled read of the user's local 3MF sample. No private model is committed.
- Windows 11 / JDK 21: 25 tests passed; the opt-in local-model test was skipped. Desktop compiled and MSI/EXE packages built. Installation and UI interactions were not repeated for this change.
- Apple: [GitHub build 34924006183](https://github.com/g4l4xy/PrintQuote3D/actions/runs/34924006183) passed 32 Swift tests and both macOS and iOS Simulator application builds at implementation commit `9a5a63b`. The iOS target includes iPhone and iPad.
- Local combined checks passed Android but were blocked on Apple by the installed Xcode license agreement. No license was accepted automatically. `PrintQuote3D.xcodeproj` passes plist validation.
- Shared fixture copies match byte-for-byte. Import reports distinguish project support/tower flags from sliced results, retain unknown fields, and reject malformed XML/STL, unsafe paths, entity declarations and excessive JSON nesting. Cancellation tests pass on both implementations.
- New screen interactions and actual iPhone/iPad device runs remain unverified. The app and simulator were not launched by this work.

Use `PrintQuote3D App` in Xcode, not the similarly named package scheme. The native application scheme correction is included on this branch. This milestone is an inspector, not a slicer or an automatic quote-population feature.
