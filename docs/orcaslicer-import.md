# Orca import boundary

`OrcaProfiles` is a separate Swift target containing OrcaProfileDTO → inheritance resolver → OrcaProfileMapper. `tools/OrcaProfileImporter` is a command-line frontend. SwiftUI consumes only QuoteDomain normalized data.

Run `tools/update-orca.sh COMMIT_SHA` to retrieve a fresh checkout, resolve its exact SHA, import the curated selection, and update bundle/schema JSON only after successful validation. No app launch performs networking. For an existing immutable checkout, use `swift run OrcaProfileImporter --profiles /path/to/resources/profiles --commit SHA --selection tools/orca-selection.json --output catalog.json`.

The included six profiles derive from OrcaSlicer commit `8500fcdccaa10b5099ac20d252af3a7c560046f1`. `tools/orca-selection.json` records selected paths. Every normalized record contains the upstream repository, source path, inherited paths, exact commit and import time. `fieldSourcePaths` identifies the file contributing each mapped upstream field. Stable IDs derive from a SHA-256 digest of the repository-relative source path (not from display name or revision).

Inheritance resolves within the vendor first; cross-vendor lookup requires an unambiguous match. Missing parents, cycles, unknown selected files and unsupported profile types are diagnostics; the CLI returns nonzero on selected-record failures. Unknown/unmapped fields are not copied wholesale. G-code and application code are excluded, as are filament_cost and other price assumptions. Technical fields are explicitly allowlisted.

Nozzle arrays and physical-extruder maps can describe variants or extrusion topology rather than physical toolheads. Unless an explicit physical toolhead count exists, the imported value is null and needs review. Adding such a profile creates a review-needed custom configuration starting at one physical tool; this is an editable placeholder, not an assertion of hardware capability. All change/purge assumptions require review.

Imported build X/Y are bounding extents, not proof that an entire rectangular volume is usable. Keep bed exclusions, physical limits and usable dimensions distinct. No slicer print temperature becomes a hardware maximum. Shop costs and measured power are user-entered; imported records do not supply those prices.

Large copied datasets and additional vendor-specific notices require licensing review before expansion. See ATTRIBUTION.md and ThirdParty/OrcaSlicer-LICENSE.txt. This curated import retains a narrow field/data boundary and does not copy upstream application source.
