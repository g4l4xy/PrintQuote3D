You are working on **PrintQuote 3D V4**.

This version should focus heavily on:

1. Quality-of-life improvements
2. Faster navigation
3. Better data visibility
4. Smoother editing
5. More robust local data loading
6. Better filament/printer discovery
7. Fixing the filament library, which is currently only showing **3 filament options**
8. Making the app feel like a mature desktop application rather than an early prototype

Do not treat V4 as just a visual redesign.

This should be a usability, reliability, and data-quality release.

# PART 1 — FILAMENT LIBRARY IS CURRENTLY BROKEN / INCOMPLETE

The biggest immediate issue is:

> The filament library currently only shows 3 options.

This is not acceptable.

PrintQuote 3D is supposed to support a large filament database containing hundreds or thousands of products/material variants.

Investigate why only 3 filaments are appearing.

Do NOT simply hardcode more filament examples.

Determine whether the problem is caused by:

* only 3 records being included in seed data
* JSON decoding failure
* filtering
* repository fetch behavior
* SwiftData persistence
* import logic
* duplicate detection
* schema mismatch
* search/filter state
* sample-data fallback
* preview-only data being used in production
* importer only selecting first few items
* pagination bug
* data source path issue
* bundled resource not being copied into target
* schema validation rejecting most records
* normalization failure
* ID collisions
* application launching before import finishes
* database migration problem
* stale cached data

# FILAMENT DEBUGGING REQUIREMENT

Add diagnostics that report:

```text
Filament source records discovered
Filament records decoded
Filament records normalized
Filament records rejected
Filament records inserted
Filament records updated
Filament records skipped as duplicate
Filament records displayed
```

Example:

```text
Open Filament Database:
Source records: 14,577
Decoded: 14,577
Normalized: 14,120
Rejected: 457
Stored: 14,120
Visible after filters: 14,120
```

If only 3 are displayed, Codex must be able to explain exactly where the other records were lost.

# DO NOT SILENTLY DROP RECORDS

Any rejected filament record should have a reason:

```text
Missing material family
Invalid identifier
Unsupported schema version
Malformed color value
Duplicate external ID
Unknown material mapping
Invalid spool size
```

Rejected entries should go into diagnostics/quarantine rather than simply disappearing.

# FILAMENT LIBRARY DATA SOURCES

The library should support normalized data imported from:

* Open Filament Database
* OrcaSlicer filament profiles
* manufacturer data
* PrintQuote built-in material definitions
* user-created filaments

Do not make internet access required to display the library.

The app should ship with a usable local filament catalog.

# OPEN FILAMENT DATABASE

Use the normalized local data pipeline already planned for the Open Filament Database.

The UI should not directly parse remote data.

Use:

```text
Source data
   ↓
Importer
   ↓
Normalizer
   ↓
Local PrintQuote filament database
   ↓
FilamentRepository
   ↓
Filament Library
```

# FILAMENT LIBRARY SHOULD SUPPORT THOUSANDS OF RECORDS

Make sure the UI remains responsive with:

```text
10,000+
20,000+
50,000+
```

filament variants.

Do not create one SwiftUI view hierarchy containing every item at once.

Use lazy rendering, indexed queries, and sensible pagination/batching if necessary.

# FILAMENT LIBRARY NAVIGATION

The filament library should have:

```text
Search
Filters
Sorting
Favorites
Recently Used
My Inventory
All Filaments
Manufacturers
Material Families
Colors
Engineering Materials
Flexible Materials
Support Materials
Specialty Materials
```

# MATERIAL FAMILY FILTERS

Add quick filters such as:

```text
PLA
PETG
ABS
ASA
TPU
TPE
PA / Nylon
PC
PP
PCTG
PPS
PEEK
PEKK
Support
CF
GF
Specialty
```

Allow multiple filters.

# MANUFACTURER FILTER

Add manufacturer browsing.

Examples:

```text
3DXTech
Anycubic
Bambu Lab
BASF
ColorFabb
CookieCAD
Creality
Duramic
ELEGOO
Eryone
eSUN
Fillamentum
Flashforge
Hatchbox
Inland
Kingroon
Overture
Polymaker
Proto-pasta
Prusament
Siraya Tech
SUNLU
```

This list should come from the database, not be hardcoded into the UI.

# FILAMENT SEARCH

Search should match:

```text
brand
product
material
color
SKU
material subtype
tags
aliases
```

Examples:

```text
Overture Easy Nylon
Bambu ASA
Polymaker PA6-CF
black PETG
red PLA
TPU 95A
```

Search should be debounced and cancellable.

# FILAMENT CARD / ROW

Each filament result should show useful information without opening the full page.

Suggested layout:

```text
Polymaker PolyLite PLA

PLA
Army Beige

$19.99/kg

Nozzle:
190–230°C

Bed:
25–60°C

Drying:
55°C / 6h

AMS:
Supported

Difficulty:
Easy
```

Do not clutter the row with every technical property.

# FILAMENT DETAILS PAGE

Add sections:

```text
Overview
Printing
Drying
Compatibility
Mechanical Properties
Spool Information
Pricing
Sources
User Overrides
```

# FILAMENT COMPATIBILITY

Show individual system compatibility:

```text
AMS
AMS Lite
AMS 2 Pro
AMS HT

ACE Pro
ACE 2 Pro

IFS

MMU

CFS

External Spool
```

Do not use one generic:

```text
Automatic feeder compatible
```

# USER FILAMENT OVERRIDES

Allow users to override:

* price
* drying
* temperature
* flow
* max volumetric speed
* compatibility
* density
* notes

But preserve the original imported values.

Show:

```text
Source Value
User Override
Effective Value
```

# FAVORITES

Allow filament favorites.

Examples:

```text
★ Overture ABS Black
★ Polymaker PA6-CF
★ Flashforge ASA
```

Favorites should appear near the top of filament selectors.

# RECENTLY USED FILAMENTS

When selecting material for a quote:

show:

```text
Recently Used
Favorites
My Inventory
Recommended
All Filaments
```

This avoids searching through thousands of filaments every time.

# QUICK FILAMENT PICKER

Quote screens should NOT show a giant dropdown containing thousands of entries.

Instead use a searchable popover/modal:

```text
Select Filament

Search...

Recently Used

Overture ABS Black
Polymaker PolyLite PLA
Anycubic PETG

────────────

All Results
```

# PART 2 — V4 QUALITY OF LIFE

# DASHBOARD

Upgrade the dashboard.

Show:

```text
New Quote
Quick Quote
Import STL/3MF
Recent Quotes
Recent Customers
Active Jobs
Printer Status
Material Alerts
```

Optional metrics:

```text
Quotes this month
Revenue
Average margin
Printer hours
Filament consumed
```

Do not make analytics block app startup.

# COMMAND PALETTE

Add:

```text
Cmd+K on macOS
Ctrl+K on Windows
```

Commands might include:

```text
New Quote
Open Quote
Add Printer
Add Filament
Search Printers
Search Filaments
Import 3MF
Settings
Refresh Data
```

# UNIVERSAL SEARCH

Add global search across:

```text
quotes
customers
printers
filaments
presets
jobs
```

# RECENT ITEMS

Track:

```text
recent quotes
recent printers
recent filaments
recent customers
recent presets
```

# FAVORITES

Allow favorite:

```text
printers
filaments
pricing presets
customers
```

# DUPLICATE

Add Duplicate to:

```text
quote
printer configuration
filament preset
pricing preset
customer job setup
```

# CONTEXT MENUS

Use right-click/context menus for desktop users.

Examples:

```text
Open
Duplicate
Favorite
Edit
Archive
Delete
```

# KEYBOARD SHORTCUTS

macOS:

```text
Cmd+N
New Quote

Cmd+S
Save

Cmd+O
Import

Cmd+F
Search

Cmd+K
Command Palette
```

Windows equivalents:

```text
Ctrl+N
Ctrl+S
Ctrl+O
Ctrl+F
Ctrl+K
```

# AUTOSAVE

Quotes should autosave.

Show:

```text
Saving…
Saved
Save Failed
```

Use debounced saves.

# UNSAVED CHANGE PROTECTION

If autosave fails, do not allow silent loss.

Warn before closing if necessary.

# CRASH RECOVERY

On relaunch:

```text
Recovered Draft Found
```

Allow:

```text
Restore
Discard
```

# TOAST NOTIFICATIONS

Use subtle desktop notifications inside the app:

```text
Quote saved
Printer added
Filament updated
Database refreshed
Import completed
```

Do not use modal dialogs for success messages.

# ERROR MESSAGES

Replace generic errors such as:

```text
Operation failed
```

with useful messages:

```text
Filament database could not be refreshed.

Your existing local library is still available.

Technical details:
HTTP timeout contacting data source.
```

# LOADING STATES

Do not show blank screens during database operations.

Use:

```text
Loading filament library…
Loading printers…
Analyzing 3MF…
```

Prefer skeleton/loading states for longer operations.

# CANCELLABLE TASKS

Allow cancellation for:

```text
3MF import
large STL import
database refresh
filament import
printer import
```

# PROGRESS INDICATORS

Show meaningful stages.

Example:

```text
Updating filament database

Downloading source
████████████████ 100%

Normalizing
██████████------ 70%

Updating search index
████------------ 25%
```

# SETTINGS SEARCH

Settings may become large.

Add:

```text
Search Settings
```

# FILTER MEMORY

Remember library filter choices.

Example:

User filters:

```text
Material = ASA
Manufacturer = Polymaker
```

When returning to the filament library during the same session, preserve it.

Provide:

```text
Reset Filters
```

# SAVED FILTERS

Optional V4 feature:

Allow:

```text
My Engineering Filaments
My Cheap PLA
Carbon Fiber
TPU
```

as saved filters.

# SORTING

Filament library should support:

```text
Name
Manufacturer
Material
Price/kg
Recently Used
Favorite
Difficulty
Drying Requirement
```

Printer library:

```text
Name
Manufacturer
Build Volume
Toolheads
Recently Used
Favorite
```

# TABLE VS CARD VIEW

Allow filament/printer libraries to switch:

```text
Cards
Table
```

Table view is especially valuable for technical comparisons.

# COLUMN CUSTOMIZATION

Table view should support:

```text
show/hide columns
resize columns
reorder columns
remember layout
```

# INLINE EDITING

Allow safe inline editing for fields such as:

```text
inventory remaining
purchase price
nickname
notes
favorite
```

Do not use inline editing for complex technical configuration.

# QUICK ACTIONS

For printer rows:

```text
New Quote
Open
Duplicate Config
Maintenance
```

Filament rows:

```text
Use in Quote
Add to Inventory
Favorite
Edit Override
```

# SMART EMPTY STATES

If a filter produces zero results:

Do not show:

```text
No filaments
```

Show:

```text
No filaments match these filters.

Material: PA-CF
Manufacturer: Overture

[Clear Manufacturer Filter]
[Clear All Filters]
```

# LIBRARY COUNTS

Display:

```text
Filaments
14,382
```

and when filtered:

```text
132 of 14,382
```

This will also make database-load failures obvious.

# SOURCE STATUS

Add a Data Sources page showing:

```text
Open Filament Database
Healthy
Last updated: Today

OrcaSlicer
Healthy
Commit: abc123

Manufacturer Data
Partial

SimplyPrint
Healthy
```

# DATABASE STATUS

Under advanced settings:

```text
Printers: 846
Filament Products: 2,143
Filament Variants: 14,382
Material Families: 61
```

This is extremely useful for debugging.

# REFRESH DATA BUTTON

Allow:

```text
Refresh Printer Data
Refresh Filament Data
Rebuild Search Index
Validate Database
```

Do not require the user to restart the app.

# PART 3 — PERFORMANCE

Make libraries responsive.

Do not:

```text
load everything
sort in SwiftUI body
filter tens of thousands of items synchronously
```

Use repository-level queries.

Example:

```text
FilamentRepository.search(
    searchText,
    filters,
    sort,
    offset,
    limit
)
```

# SEARCH INDEX

Create normalized searchable fields.

Examples:

```text
normalizedBrand
normalizedProduct
normalizedMaterial
normalizedColor
searchTokens
```

# INDEXED DATABASE FIELDS

Ensure the local database has indexes for frequent lookups such as:

```text
manufacturer
materialFamily
productName
favorite
lastUsed
externalID
```

# BACKGROUND INDEXING

Search-index rebuilds must not freeze the UI.

# PART 4 — FILAMENT IMPORT TESTING

Add tests specifically for the current 3-filament bug.

Create a fixture containing:

```text
100+ filaments
multiple brands
multiple materials
multiple colors
```

Test:

```text
source records = 100+
repository records = 100+
library query = 100+
```

If the UI receives only 3:

the test should fail.

# LARGE DATABASE TEST

Generate or use synthetic data:

```text
20,000 filament variants
```

Verify:

```text
database imports
search works
filters work
scrolling remains usable
```

# DUPLICATE TEST

Make sure different colors or spool sizes do not collapse accidentally.

Example:

```text
Overture PLA Black 1kg
Overture PLA White 1kg
Overture PLA Red 1kg
```

must not all become one database record.

# ID DESIGN

Use separate IDs for:

```text
Brand
Filament Product
Variant
Spool Size
Retail Offer
```

Example:

```text
Overture
   ↓
Easy Nylon
   ↓
Black
   ↓
1 kg
   ↓
Amazon offer
```

Do not make:

```text
manufacturer + material family
```

the unique key.

That could explain why records are being collapsed.

# PART 5 — V4 POLISH

Add:

```text
About PrintQuote
Version
Database Version
Schema Version
Printer Count
Filament Count
```

Add diagnostics:

```text
Open Logs
Create Support Bundle
Validate Database
Rebuild Index
```

# V4 DEFINITION OF DONE

V4 should not be considered complete until:

```text
[ ] filament library shows the actual imported catalog instead of 3 sample items
[ ] importer diagnostic counts explain every stage
[ ] rejected filaments have reasons
[ ] no silent data loss
[ ] duplicate variants remain distinct
[ ] search works across thousands of filaments
[ ] filters work
[ ] favorites work
[ ] recent filaments work
[ ] filament selector is searchable
[ ] cards and/or table view are polished
[ ] library counts are visible
[ ] source status is visible
[ ] data refresh does not block UI
[ ] global search works
[ ] command palette exists
[ ] autosave works
[ ] crash recovery works
[ ] context menus work
[ ] keyboard shortcuts work
[ ] app remains usable offline
[ ] large filament database does not freeze the UI
[ ] Swift/macOS build succeeds
[ ] tests pass
```

# PRIORITY ORDER

Do this in this order:

## Priority 1

Fix the filament library only showing 3 records.

Before changing UI, trace:

```text
source
→ decode
→ normalize
→ persistence
→ repository
→ filter
→ UI
```

Report exactly where records are lost.

## Priority 2

Add library diagnostics and database counts.

## Priority 3

Make filament library scalable.

## Priority 4

Improve the filament picker.

## Priority 5

Add favorites/recent items/search.

## Priority 6

Add global command/search improvements.

## Priority 7

Polish autosave, notifications, empty states, and background operations.

# FINAL INSTRUCTION

Do not fix the 3-filament issue by adding a larger hardcoded array.

Find and fix the actual data pipeline problem.

PrintQuote should be capable of displaying and searching a **large real filament catalog**, with user inventory and favorites layered on top.

The V4 goal is:

> The app should feel fast and simple when doing common work, while still having a large and technically rich printer/filament database underneath it.
