# Printer catalog coverage

The app automatically adds 1,004 real printer profiles at launch, preserving existing records and saved quotes. Three legacy demo profiles remain for fixture compatibility. Both Printers and the estimate chooser support manufacturer/model/nozzle search.

## Included snapshot

- OrcaSlicer commit `8500fcdccaa10b5099ac20d252af3a7c560046f1`: all 1,001 registered instantiated machine profiles; 383 distinct vendor/model names across 64 vendors. Counts include nozzle and configuration variants, not 1,001 unique printer models.
- Manufacturer supplement: Prusa XL two-tool, Raise3D Pro3 HS and Pro3 Plus HS. These fill specific named gaps in the supplied guide. The Raise3D records retain separate single/dual build widths.
- All 14 manufacturer groups named in the source guide have included profiles: Bambu Lab, Prusa, Anycubic, Flashforge, Creality, Elegoo, Qidi, Raise3D, Snapmaker, LulzBot, UltiMaker, Voron, RatRig and FLSUN.

## Scope and quality

The supplied guide is a directory of sources, not a finite list of printer models. This release imports the full pinned Orca collection; it does not claim exhaustive coverage of every printer on every linked website. Cura, PrusaSlicer, Klipper and commercial databases remain source-directory references, not bulk imported datasets. Missing or uncertain tool topology is explicitly marked for review; slicer nozzle arrays are not assumed to be physical toolheads. Unknown shop rates and average power start at zero with a visible review notice. Manufacturer rated maximum power is never substituted for average operating power.

Manufacturer references: [Prusa XL two-tool](https://www.prusa3d.com/en/product/original-prusa-xl-2-toolhead-3d-printer-5/) and [Raise3D Pro3 HS series manual](https://support.raise3d.com/Pro3-HS-Series/raise3d-pro3-hs-series-3d-printer-user-manual-35-1701.html).

## Validation

Full import completes with zero diagnostics. Tests verify manufacturer/model coverage, unique IDs, tool-system validity, nearest-directory inheritance, idempotent migration preserving user costs and quote snapshots, and manufacturer mode geometry.
