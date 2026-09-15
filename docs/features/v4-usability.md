# V4 usability, discovery and reliability

Scope: Apple, Android and Windows. App version 0.4.0. The supplied [brief](v4-brief.md) defines priorities. Keep SimplyPrint excluded per the explicit prior removal request; its appearance in a sample status list is not a request to reinstate it.

## Root cause: why the library looked like three filaments

The bundled `open_filaments_v2.json` contains **2,089 products, 14,577 color variants and 22,355 spool options**. It was already copied into the app resources. Apple's catalog was separate from `LibrarySnapshot.filaments`; the latter contains saved/user inventory, initially three sample spools. Materials opened that inventory view. Android and Windows made the same navigation choice and exposed only product-level catalog indexes behind a second tab.

There was no evidence that the source contained only three records or that all colors had collided into three IDs. The visible three were the inventory collection. Catalog search also omitted color/spool-level information. Apple coupled its initial full-catalog decode to workspace readiness and filtered product arrays during view evaluation.

V4 fixes the discovery path rather than adding sample rows or manufacturing inventory ownership:

1. Bundled OFD source → schema checks and normalization.
2. Product, variant and spool identities stay separate; spool ID is the search identity.
3. Apple writes a durable, transactional SQLite/FTS index; Android/Windows stream one product at a time into background token/facet indexes. Their authoritative offline source remains the bundled file.
4. Repository queries produce 100-row pages (maximum public limit 200).
5. **All Filaments** opens by default; **My Inventory** remains explicitly separate.
6. Matching and total counts are displayed with product and color counts.

The real source regression test now asserts **22,355 stored, zero rejected and zero duplicate spool IDs**. Diagnostic units are spool options, not the upstream count of colors. See the [shared discovery contract](../../SharedSchemas/v4-discovery-contract.md).

## Implemented

- Indexed brand/product/family/color/source-field/SKU/tag prefix search; debounce and cancellation discard stale results. Multiple manufacturers/families, favorites, recently used, reset, sorting and pagination.
- Persistent favorites/recent filament selections; remembered session catalog query/filter state. Saved inventory remains user-owned and preserves entered prices.
- Discovered/decoded/normalized/rejected/inserted/updated/duplicate/stored counters, visible filtered counts, and quarantine ID/reason/count records.
- Atomic refresh: failed/canceled Apple rebuilds roll back; Kotlin only swaps the new index after success. Loading/cancel actions and contextual errors preserve the previous usable index.
- Searchable material selection with Recent, Favorites, My Inventory, All Filaments and a Recommended group based only on saved favorites/history. Correct selected color/spool details are retained; recommendations are not compatibility certifications.
- Cards/table switching for filament and printer libraries. Column visibility, order and widths persist locally; column customization uses controls rather than drag gestures. Inventory tables validate inline price, remaining grams, nickname and notes before saving.
- Filament sorting includes name, manufacturer, material, price/kg, recent, favorite, difficulty and drying requirement. Price uses saved inventory purchase cost. Difficulty/drying sorts use explicit source fields only, with unknowns last; maximum drying temperature is not treated as a recommended drying requirement. Printer sorts include manufacturer, build volume, toolheads, recent and favorite.
- Printer row actions create a quote with the selected printer, duplicate its configuration, or open maintenance settings. Customer actions can duplicate the latest saved quote setup.
- Grouped technical details, separate feeder-system compatibility, and optional `technicalOverrides` alongside unchanged imported fields. Source/override/effective values are visible. Unknown compatibility stays unknown. Technical overrides are reference specifications and do not silently change quote consumption or slicer settings.
- Search & Commands on all platforms; Cmd+K / Ctrl+K on desktop, plus new/save/import/search shortcuts. Global saved-record search and full-catalog search entry points.
- Favorites and recent-entity tracking, duplicate actions, native desktop context menus and mobile row actions. Catalog and inventory preference presentation is platform-specific.
- Quote autosave after 800 ms, visible save state, atomic per-quote recovery journals, explicit Restore/Discard, and close/navigation warnings. Kotlin serializes writes and merges changed records so an intervening autosave does not erase an unrelated library edit.
- Recovery scans continue past an unreadable journal: valid drafts are offered, damaged bytes remain on disk and errors are surfaced.
- Settings search, app/schema/database counts, source status, refresh/rebuild/validation controls, a bounded local diagnostic-log viewer and support export without quotes/customer values/inventory prices.
- Printer refresh/cancel reads the bundled Orca/manufacturer catalogs in the background and adds missing source profiles while retaining existing user configurations. Filament refresh/cancel retains the old usable index until replacement succeeds.
- Dashboard catalog counts, low-stock references, recent customers and clear statements that live printer monitoring/job tracking are not connected. Success messages appear inside the app.

## Verification — September 15, 2026

| Check | Evidence |
| --- | --- |
| Swift | 68 tests pass; Xcode 27.0 / Swift 6.4 |
| Apple native apps | `./pq check`: macOS and generic iOS Simulator builds pass; iPhone/iPad targets retained |
| Android | `./pq check`: APK and lint pass; 32 JVM tests (31 passed, one optional local-model skip) |
| Windows host | `./pq check --platform windows`: desktop build and shared tests pass using JDK 21; 40 tests, including one optional local-model skip |
| Shared fixture | Same 4-product / 40-color / 120-spool fixture exercised by Swift and Kotlin; no collapse of 250/500/1000 g options |
| Scale | Both implementations exercise 50,000 synthetic records, search/facets and bounded nonoverlapping pages; this is backend evidence, not measured UI scrolling acceptance |
| Reliability | Favorites survive Apple rebuilds; unsupported source versions retain index; cancellation during SQLite insertion rolls back; recovery preserves newest edits and valid drafts beside corrupt files; queued Kotlin writes retain unrelated changes |
| Windows packaging | Final 0.4.0 MSI built in Parallels Windows 11, installed with exit 0; installed process remained running after launch. Earlier task-installed same-version test build was replaced after repair was rejected. |
| Upgrade data | Existing Windows database backed up and hash compared unchanged through final test-build replacement. Initial upgrade from the prior version also retained the database. |
| Interaction | Fresh visual check blocked because the Mac was locked. No Xcode or iPhone/iPad Simulator launch performed. Android emulator was not running; updated instrumentation tests compile but were not executed. |

Build logs and local installer/APK artifacts are under ignored `.workflow/`. They are local evidence, not committed customer data.

## Acceptance boundaries and remaining polish

This is a substantial V4 core implementation, not a claim that every suggestion in the long brief has been finished or visually accepted. In particular:

- Live online manufacturer/pricing adapters, live printer monitoring, jobs and revenue analytics are not introduced by this release. Existing source-directory entries do not imply healthy active network adapters. Global search covers saved records and catalog navigation; there is no new searchable jobs backend.
- Refresh rebuilds the pinned **local** filament/printer catalogs. It does not download updated internet catalogs. Catalog search uses the OFD spool index; existing Orca/manufacturer technical-profile browsers remain separate reference views inside Materials/Sources.
- Manufacturers and material families come from source data. Color/subtype/tag discovery is available through search; dedicated category landing pages and optional named saved filters are not introduced.
- Saved comparison columns and inventory edits are implemented, but native table focus, window layout and picker interaction still require visual acceptance. Technical edits use focused editors, not inline table inputs.
- The app has no comprehensive native UI acceptance result for V4. Layout, focus, keyboard/context interactions, window resizing and recovery flows still need an unlocked desktop/device pass. Prior-release interaction results are not reused as V4 acceptance.

Do not label the entire supplied V4 wish list visually accepted until the interaction checks above are completed.
