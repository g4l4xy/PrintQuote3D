# Windows behavioral port

Port QuoteDomain Codable schemas and Decimal formulas to Kotlin/kotlinx.serialization and BigDecimal. Build Compose Desktop UI separately. Do not port SwiftUI or SwiftData annotations.

Catalog JSON and shared fixtures are platform-neutral. UUID strings are stable IDs. Legacy quote dates use seconds since 2001-01-01 UTC; OFD metadata dates are ISO 8601 strings as declared by their schema. Preserve decimal arithmetic and half-up rounding. Toolhead indices start at 1. Treat optional v2 fields as absent in v1 records, preserving aggregate-cost behavior.

Source import tools run separately from the application. Kotlin consumes their normalized outputs. Preserve per-field source paths, revision metadata, local overrides and quote snapshots. Do not derive physical toolheads from color, input or feeder counts.
