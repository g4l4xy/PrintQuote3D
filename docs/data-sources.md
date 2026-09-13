# Data sources and update streams

The complete user-supplied guides are committed as `filament-data-sources.md` and `printer-data-sources.md`. The app's Data & Pricing Sources screen includes 52 source groups drawn from both guides, with links and ingestion guidance. A directory entry does not mean that its website has been ingested or its endpoints verified.

Implemented offline sources:

- Open Filament Database bulk JSON, normalized by `tools/OpenFilamentImporter/import_filaments.py`. The included 2026.09.12 snapshot contains 2,089 products, 14,577 color variants and 22,355 sizes, with purchase links where present. The source snapshot SHA-256, generated/retrieved timestamps, version and MIT license are stored in the bundle catalog. Each technical field retains the upstream table/ID/field path.
- OrcaSlicer, through the isolated Swift importer, with all 1,001 instantiated machine profiles registered in the pinned vendor manifests, plus three filament profiles. Three additional manufacturer records cover Prusa XL two-tool and Raise3D Pro3 HS / Pro3 Plus HS.
- User-supplied reference directory covering official manufacturer sources, Cura, PrusaSlicer, Klipper, secondary catalogs, packaging/color references and approved-feed retail pricing.

To refresh OFD, download the documented bulk export to a local file and run `python3 tools/OpenFilamentImporter/import_filaments.py all.json Sources/QuoteData/SeedData/open_filaments_v2.json`. The importer never contacts sites or reads the user's database. It retains unknown fields as absent, distinguishes colors/sizes, preserves source IDs, and does not invent prices. The normalized bundle is portable JSON and is the single checked-in copy (see SharedSchemas/catalog-manifest.json).

The app lets the user search products, inspect technical data, choose a color/spool, enter their own price/kg and explicitly add it to Filaments. Existing library IDs are not overwritten. Quotes snapshot the selected catalog provenance and user price. Import updates and technical manufacturer overlays remain separate from retail pricing.

`ManufacturerDataProvider` and `PrinterSourceProvider` provide boundaries for future adapters. `FieldPrecedence`/`PrinterSourceResolver` retain local overrides and prefer higher-authority incoming fields. Original normalized source records remain in the catalog. Physical versus usable dimensions must use separate fields, not compete under one generic height key.

Cura, PrusaSlicer, Klipper, OpenPrintTag and brand-specific network adapters are cataloged but not implemented in this milestone. Review actual licensing/API/terms before bulk ingestion. No Amazon HTML scraper or live pricing updater is included. Official manufacturer TDS/hardware specifications should override technical fallback values; source URLs alone are not verified hardware facts.
