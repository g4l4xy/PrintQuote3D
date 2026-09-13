# PrintQuote 3D — Filament Data Sources for Codex

## Recommended source hierarchy

1. Open Filament Database (primary open catalog/API)
2. Manufacturer technical documentation / TDS / official product catalog
3. OrcaSlicer slicer-profile repositories for process/profile data
4. OpenPrintTag database for packaging/GTIN/container metadata
5. Secondary normalized databases such as SpoolScout / FilamentCat for cross-checking only
6. Retailers such as Amazon for current retail pricing, only through approved APIs/feeds rather than brittle scraping

---

## 1. Open Filament Database — PRIMARY DATABASE

Project: https://github.com/OpenFilamentCollective/open-filament-database
API: https://api.openfilamentdatabase.org/
Docs: https://openfilamentdatabase.org/docs
Editor: https://openfilamentdatabase.org/
License: MIT

Why PrintQuote should use it:
- Open and commercially reusable under MIT.
- Static API rebuilt daily.
- Brand → Material → Filament → Variant → Size hierarchy.
- Includes brands, material types, colors/hex values, spool sizes, stores, purchase links, density, print temperatures and slicer-related metadata.
- Bulk downloads are available as JSON, NDJSON, CSV and SQLite.
- JSON Schema endpoints are provided.
- OrcaSlicer-oriented exports/bundles are also published.

Useful API paths:
- /api/v1/brands/index.json
- /api/v1/brands/{brand}/index.json
- /api/v1/brands/{brand}/materials/{material}/index.json
- /api/v1/brands/{brand}/materials/{material}/filaments/{filament}/index.json
- /api/v1/brands/{brand}/materials/{material}/filaments/{filament}/variants/{variant}.json
- /api/v1/stores/index.json
- /api/v1/schemas/index.json
- /json/all.json
- /json/all.ndjson
- /csv/filaments.csv
- /csv/variants.csv
- /csv/sizes.csv
- /csv/purchase_links.csv
- /sqlite/filaments.db

Codex recommendation: ingest this first into PrintQuote's normalized database, retain the source IDs/paths, and overlay official manufacturer TDS data when available.

---

## 2. OpenPrintTag Material Database

Repository: https://github.com/OpenPrintTag/openprinttag-database

Useful for:
- brands
- materials
- packaging specifications
- GTIN/barcodes
- spool/container dimensions
- interoperable NFC/spool metadata

This is especially useful for PrintQuote inventory, spool scanning, AMS/ACE/IFS physical-fit rules, empty-spool weights, and barcode/NFC support.

---

# Official manufacturer databases and technical sources

## Flashforge

Filament Guide:
https://www.flashforge.com/a/docs/filament/filament-guide

PDF guide:
https://wiki.flashforge.com/resource/filament_tips/flashforge_filament_guide.pdf

Good fields:
- material family
- tensile/flexural values
- print temperatures
- material-selection guidance
- printer/material compatibility
- carbon-filled and engineering-material notes

Use official Flashforge store/product pages separately for current price, color and spool SKU information.

---

## Anycubic

Store/material product catalog:
https://store.anycubic.com/collections/3d-printing-filament

Example high-quality technical product page:
https://store.anycubic.com/products/petg-cf-filament

Anycubic product pages are particularly valuable because many expose:
- TDS
- MSDS
- REACH files
- density
- nozzle and bed temperatures
- flow rate / maximum volumetric speed
- recommended nozzle size/material
- drying temperature/time
- ACE compatibility
- physical/mechanical properties

Codex should extract technical data from manufacturer product/TDS pages, not only store descriptions.

---

## Kingroon

Main filament catalog/product pages:
https://kingroon.com/collections/filament
https://kingroon.com/products/kingroon-pla-basic
https://kingroon.com/products/10kg-petg-filament-1-75mm-3d-print-materials

Useful fields often exposed directly in page HTML:
- density
- nozzle/bed temperature
- speed
- filament length
- drying guidance
- tensile strength
- flexural properties
- impact strength
- heat distortion
- spool weight
- current retail price

Important: several Kingroon product pages appear to reuse blocks of material text, so validate suspicious data against material-specific pages/TDS before accepting it.

---

## Prusament / Prusa Research

Prusa Filament Material Guide:
https://help.prusa3d.com/filament-material-guide

HueForge TD / color database:
https://help.prusa3d.com/article/hueforge-filament-transparency-values-and-hexcodes_762314

Prusament site:
https://prusament.com/

Useful fields:
- material types
- nozzle and bed temperatures
- enclosure recommendation
- drybox requirement
- hardened-nozzle requirement
- build-surface compatibility
- heat deflection
- impact/tensile strength
- price information in material comparison
- HueForge transmission distance
- measured color hex codes

This is one of the best official material-comparison datasets.

---

## Polymaker / Fiberon

Main site:
https://polymaker.com/

Downloads:
https://polymaker.com/download/

TDS index/wiki:
https://wiki.polymaker.com/polymaker-products/more-about-our-products/documents/technical-data-sheets

Material comparison:
https://fiberon.polymaker.com/material-comparison/

Example material category:
https://polymaker.com/material/petg/

Useful fields:
- downloadable TDS/SDS/PIS
- mechanical properties
- thermal properties
- material comparisons
- application tags
- print settings/presets
- engineering-composite data
- downloadable slicer presets

Polymaker's material comparison is especially useful for normalized engineering-property comparisons.

---

## Bambu Lab

Interactive Filament Guide:
https://bambulab.com/filament-guide

Filament Guide PDF:
https://cdn1.bambulab.com/filament/Bambu-Filament-Guide-EN-1.pdf

Official store:
https://us.store.bambulab.com/collections/bambu-lab-3d-printer-filament

Example product page:
https://us.store.bambulab.com/products/asa-filament

Useful fields:
- nozzle compatibility
- build-plate compatibility
- AMS compatibility
- drying requirement
- nozzle/bed/chamber temperature
- spool dimensions
- mechanical properties
- retail price
- TDS/MSDS/RoHS links
- material comparison

Bambu is particularly valuable for automatic-material-system compatibility rules.

---

## Fillamentum

Official Data Sheets & Printing Guides:
https://fillamentum.com/pages/data-sheets-and-3d-printing-guides/

Alternate guide path:
https://fillamentum.com/learn/data-sheets-and-3d-printing-guides/

This page centralizes TDS, SDS, safety recommendations and 3D-printing guides for materials including:
- ABS Extrafill
- ASA Extrafill
- CPE
- Flexfill PEBA/TPE/TPU
- HIPS
- Nylon AF80/CF15/FX256
- PC/ABS
- PETG
- PLA
- PP
- Timberfill
- specialty materials

Excellent direct manufacturer source.

---

## colorFabb

Full filament catalog:
https://colorfabb.com/filaments

Print Support / comparison data:
https://colorfabb.com/print-support

PLA catalog:
https://colorfabb.com/filaments/materials/pla-filaments

Example XT-CF20 technical page:
https://colorfabb.com/xt-cf20

Example support/profile page:
https://support.colorfabb.com/hc/en-150/articles/14729413019921-XT-CF20-Printer-Settings

Useful fields:
- extensive product list
- material type
- spool weight
- diameter
- print settings
- drying settings
- mechanical-property comparison
- TDS/SDS links
- AMS compatibility references
- slicer profiles
- density/Tg on product pages

The Print Support page is especially attractive as a semi-structured cross-product technical table.

---

## Proto-pasta / Protoplant

Main site:
https://proto-pasta.com/

Carbon Fiber PLA technical page:
https://proto-pasta.com/pages/carbon-fiber-pla

Example product:
https://proto-pasta.com/products/light-grey-carbon-fiber-composite-htpla

Useful fields:
- print temperature
- bed temperature
- density
- abrasive-material warning
- specialty additives
- spool size and price
- TDS/SDS links
- heat-treatment behavior
- color/product variants

Proto-pasta is valuable for specialty filaments (HTPLA, CF, metal-filled, reflective, thermochromic, etc.).

---

## 3DXTech

Main site:
https://www.3dxtech.com/

Example CarbonX PA6-CF:
https://www.3dxtech.com/products/carbonx-nylon-6-cf-1

Example CarbonX PC-CF:
https://www.3dxtech.com/products/carbonx-pc-cf-1

Useful fields exposed consistently across product pages:
- extruder temperature
- bed temperature
- heated-chamber requirement
- nozzle diameter/material
- layer-height guidance
- drying temperature/time
- TDS/SDS links
- slicer print-settings downloads
- reel dimensions / automated-material-system fit

This is one of the best engineering-filament sources and should receive high priority.

---

## BASF Ultrafuse / Forward AM

Current Forward AM / Ultrafuse technical documents are commonly hosted under:
https://move.forward-am.com/

Example Ultrafuse PA TDS:
https://move.forward-am.com/hubfs/AES%20Documentation/Engineering%20Filaments/PA/TDS/Ultrafuse_PA_TDS_EN_v2.2.pdf

Example Ultrafuse ASA TDS:
https://move.forward-am.com/hubfs/AES%20Documentation/Engineering%20Filaments/ASA/TDS/Ultrafuse_ASA_TDS_EN_v2.2.pdf

Useful fields:
- diameter/tolerance
- spool weight
- spool dimensions
- nozzle/bed/chamber requirements
- drying requirements
- material density
- support compatibility
- mechanical/thermal values

These PDFs are highly structured and useful for engineering-grade data ingestion.

---

## Siraya Tech

Filament catalog:
https://siraya.tech/collections/filament

Central TDS page:
https://siraya.tech/pages/tds

Example TPU product:
https://siraya.tech/products/siraya-tech-flex-tpu-95a-filament

Useful fields:
- centralized filament TDS list
- material family and product line
- Shore hardness
- TDS/MSDS/manual links
- price
- performance/application descriptions
- engineering composites including PPA-CF, PET-CF/GF, ABS-CF/GF, ASA-GF and TPU-GF

The centralized TDS page makes this easy to ingest.

---

## CookieCAD

Filament database/store:
https://filament.cookiecad.com/filaments

PLA-filtered catalog:
https://filament.cookiecad.com/filaments?material=pla

Useful fields:
- material filters (PLA/PETG/TPU/ABS)
- product name
- color/style
- spool weight
- diameter
- current price
- many specialty color variants
- links to material data sheets

Very useful for color-rich catalog/pricing data.

---

## Hatchbox

All filament catalog:
https://www.hatchbox3d.com/collections/all-filaments

PLA catalog:
https://www.hatchbox3d.com/collections/pla-1-75mm

Example product page:
https://www.hatchbox3d.com/products/3d-pla-1kg1-75-grn

Useful fields:
- material category
- diameter
- spool weight
- colors
- price
- print-temperature range
- dimensional tolerance
- product SKU/UPC embedded in store page data

Technical data is less centralized than Overture/Polymaker/Fillamentum, so use product pages and cross-check with open databases.

---

## eSUN

Main technical/resource hub:
https://www.esun3d.com/

The site exposes Resources & Downloads including:
- Filament Guide
- Printing Parameters
- Wiki
- downloadable TDS documents

Example ePA TDS:
https://www.esun3d.com/uploads/eSUN_ePA-Filament_TDS_V4.0.pdf

Useful fields:
- density
- tensile/flexural properties
- elongation
- impact strength
- HDT
- recommended print settings
- broad product family

Codex should crawl the official resources/download structure rather than only individual shop pages.

---

## Overture

Official TDS/SDS database:
https://wiki.overture3d.com/en/Filament/TDS%26SDS

TDS interpretation guide:
https://wiki.overture3d.com/en/Filament/TDS

Official site:
https://overture3d.com/

The TDS/SDS index covers standard products such as:
- PLA
- Matte PLA
- PLA Professional
- Silk PLA
- Easy PLA
- Super PLA+
- PETG
- TPU
- High Speed TPU
- ABS
- ASA
- Easy Nylon
- PC Professional

This should be a top-priority official ingestion source.

---

## Duramic

PLA+ catalog:
https://duramic3d.com/collections/pla-plus/filament

Main site:
https://duramic3d.com/

Useful fields:
- product material and color
- spool size
- current price
- nozzle temperature guidance
- dimensional tolerance
- retail product variants

Official engineering-property/TDS availability is not as centralized as Overture or Fillamentum, so use product pages plus Open Filament Database / SpoolScout for normalization and verification.

---

## ELEGOO

Master filament page:
https://www.elegoo.com/pages/elegoo-filaments

US filament page:
https://us.elegoo.com/pages/elegoo-filaments

PETG collection:
https://www.elegoo.com/collections/petg-filaments

Example Rapid PETG:
https://us.elegoo.com/products/rapid-petg-filament-1-75mm-colored-1kg

Useful fields:
- product lines
- colors
- price
- spool/net weight
- empty spool weight on some pages
- drying instructions
- maximum print speed
- dimensional tolerance
- broad material categories including PLA/PLA+/PETG and reinforced variants

Empty-spool weight is particularly valuable for inventory weighing.

---

## Creality

Materials catalog:
https://store.creality.com/collections/materials

Official use-case/material guides:
https://www.creality.com/filament

Example functional-material guide:
https://www.creality.com/filament/use-case/functional-parts

Useful fields:
- current catalog and price
- product family
- material class
- colors/variants
- use cases
- functional-material recommendations

Use product-specific technical pages/TDS where available for exact settings.

---

## SUNLU

Engineering filament comparison:
https://store.sunlu.com/collections/engineering-filaments

Filament drying guide/wiki:
https://www.sunlu.com/wiki/44

Main site:
https://www.sunlu.com/

Example PA6-CF TDS discovered through official SUNLU hosting:
https://www.sunlu.com/public/upload/file/20260325/c0ebbebd-4693-4b58-864b-6dd3d61d992f.pdf?filename=TDS%28English%29

Useful fields:
- engineering-material comparison
- tensile/flexural/impact/HDT
- print parameters
- compatible printers
- annealing
- drying conditions
- TDS PDFs

SUNLU's engineering comparison table is highly useful for PrintQuote.

---

## Inland (Micro Center)

Primary retailer/manufacturer catalog is Micro Center:
https://www.microcenter.com/

Example Inland PLA+:
https://www.microcenter.com/product/611532/inland-175mm-pla-plus-%28pla%29-3d-printer-filament-1-kg-%2822-lbs%29-spool-black-dimensional-accuracy-005-mm

Useful fields:
- current retail price
- SKU / manufacturer part number
- material
- spool weight
- diameter/tolerance
- nozzle temperature
- bed temperature on many products

Because Inland is effectively sold through Micro Center, treat Micro Center as the official pricing/catalog source for Inland.

---

## Eryone

Main filament catalog:
https://eryone3d.com/collections/filament

PLA catalog:
https://eryone3d.com/collections/pla

TPU catalog:
https://eryone3d.com/collections/tpu

Example PLA:
https://eryone3d.com/products/pla-filament

Useful fields:
- 50+ filament products
- PLA/PETG/ABS/ASA/TPU/PA/PP families
- colors
- current prices
- nozzle/bed temperature
- printing speed
- diameter/tolerance
- some TDS links

Also well covered by SpoolScout for normalized TDS data.

---

# Important cross-brand databases

## SpoolScout

Data-sheet index:
https://www.spoolscout.com/data-sheets

What it provides:
- normalized technical data sourced from manufacturer pages/TDS
- many of the target brands
- material type/product indexes
- Amazon-derived pricing
- daily updates according to its FAQ

Use as a secondary verification/normalization source, not the canonical source, because its FAQ states some fields may involve educated guesses.

Target brands currently represented include 3DXTech, ColorFabb, Creality, Elegoo, Eryone, eSUN, Kingroon, Overture, Polymaker and SUNLU.

---

## FilamentCat

https://filamentcat.com/en

Cross-brand technical catalog with print temperatures, mechanical properties and TDS references. Useful as a secondary discovery/verification source.

---

## Filament Cheat Sheet Database

https://filamentcheatsheet.com/database/

Large cross-brand database with 2,000+ filament entries and 140+ brands. Useful as discovery/fallback data, but official manufacturer/Open Filament Database records should take precedence.

---

## FilamentColors.xyz

https://filamentcolors.xyz/

Excellent color database:
- thousands of indexed filaments
- hundreds of manufacturers
- physical swatches measured with colorimeter/spectrophotometer
- LAB
- generated hex
- color matching
- manufacturer/material filtering

PrintQuote use case: color matching and more realistic color metadata. Treat its data/licensing terms separately before bulk ingestion.

---

## HueForge / FilaScope TD data

HueForge information:
https://shop.thehueforge.com/pages/about-hueforge

Community TD list:
https://penleychan.github.io/hueforge-td/

FilaScope TD database:
https://filascope.com/hueforge/td-database

Useful for:
- Transmission Distance (TD)
- optical/color-layer calculations
- HueForge-oriented color data

Do not treat community TD values as definitive because TD varies by batch/spool.

---

# Amazon pricing

Amazon was one of the requested sources, but Codex should NOT build a brittle HTML scraper for Amazon product pages.

Recommended handling:
- Amazon Product Advertising API or approved affiliate/product feed if eligible
- store ASIN, seller, quantity, net filament weight, price, coupon state, shipping/Prime status and retrieved timestamp
- normalize to price/kg
- identify multipacks correctly
- keep Amazon pricing as a retail price source, never as technical-property authority

Manufacturer technical specifications should override marketplace listing claims.

---

# Suggested normalized PrintQuote schema

For each filament product/variant, store at least:

```text
id
brand
product_line
material_family
material_subtype
reinforcement
reinforcement_percent
color_name
color_hex
lab_color (optional)
hueforge_td (optional)
diameter_mm
diameter_tolerance_mm
net_weight_g
empty_spool_weight_g
spool_outer_diameter_mm
spool_width_mm
spool_core_diameter_mm
density_g_cm3
nozzle_min_c
nozzle_max_c
bed_min_c
bed_max_c
chamber_min_c
chamber_max_c
max_volumetric_speed_mm3_s
print_speed_min_mm_s
print_speed_max_mm_s
drying_required
drying_temp_c
drying_hours_min
drying_hours_max
print_from_drybox_recommended
hygroscopicity
abrasive
min_nozzle_diameter_mm
recommended_nozzle_material
enclosure_required_or_recommended
ventilation_note
ams_compatibility
ams_lite_compatibility
ace_pro_compatibility
ace_2_pro_compatibility
ifs_compatibility
mmu_compatibility
cfs_compatibility
external_feed_recommended
shore_hardness
hdt_c
tg_c
tensile_strength_xy_mpa
tensile_strength_z_mpa
youngs_modulus_xy_mpa
flexural_strength_mpa
flexural_modulus_mpa
impact_strength_kj_m2
elongation_percent
water_absorption_percent
sku
gtin/upc/ean
manufacturer_url
tds_url
sds_url
source_name
source_url
source_retrieved_at
source_priority
source_license
retail_prices[]
```

Retail price record:

```text
source
store
url
currency
regular_price
sale_price
shipping_cost
quantity_g
normalized_price_per_kg
retrieved_at
region
in_stock
```

---

# Codex implementation recommendation

1. Integrate the Open Filament Database first using its bulk SQLite or JSON export.
2. Keep a local cached copy so PrintQuote works offline.
3. Add a `ManufacturerDataProvider` abstraction.
4. Implement brand-specific importers only for manufacturers with strong structured technical sources (Overture, Polymaker, Fillamentum, Anycubic, Bambu, colorFabb, 3DXTech, SUNLU, Siraya Tech, Forward AM first).
5. Add source precedence and provenance to every field.
6. Never silently overwrite user overrides.
7. Price data and technical data must be separate update streams.
8. Store snapshots used in each quote so old quotes do not change when websites/prices change.
9. Do not scrape a site until terms/robots/API availability and licensing have been reviewed.
10. Keep Open Filament Database / OpenPrintTag imports separate from OrcaSlicer imports so licenses and provenance remain clear.
