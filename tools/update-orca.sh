#!/bin/bash
set -euo pipefail
# The pinned upstream reference used for the bundled full printer collection.
UPSTREAM_SHA="${1:-8500fcdccaa10b5099ac20d252af3a7c560046f1}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
[[ "$UPSTREAM_SHA" =~ ^[0-9a-fA-F]{40}$ ]] || { echo 'Pass a full commit SHA'; exit 1; }
git -C "$TEMP_DIR" init -q
git -C "$TEMP_DIR" remote add origin https://github.com/OrcaSlicer/OrcaSlicer.git
git -C "$TEMP_DIR" fetch --depth=1 origin "$UPSTREAM_SHA"
git -C "$TEMP_DIR" checkout --detach FETCH_HEAD
ACTUAL_SHA="$(git -C "$TEMP_DIR" rev-parse HEAD)"
swift run --package-path "$PROJECT_DIR" OrcaProfileImporter --profiles "$TEMP_DIR/resources/profiles" --commit "$ACTUAL_SHA" --all-printers --selection "$PROJECT_DIR/tools/orca-selection.json" --output "$TEMP_DIR/catalog.json"
cp "$TEMP_DIR/catalog.json" "$PROJECT_DIR/SharedSchemas/orca_profiles_v2.json"
cp "$TEMP_DIR/catalog.json" "$PROJECT_DIR/Sources/QuoteData/SeedData/orca_profiles_v2.json"
