# Architecture

Swift package targets separate QuoteDomain (Codable models/calculations), QuoteData (SwiftData repositories and bundle data), and PrintQuoteApp (SwiftUI/application state). The public repository excludes binary builds, local database files, credentials and customer data.

Tool-system fields are optional additive extensions on existing v1 printer profiles and pricing inputs. Missing tool systems represent legacy/unknown configuration, never inferred from a multi-material system name or feeder slot count. The UI supplies a single-tool review-needed starting point until the user explicitly configures the hardware. Existing library and quote JSON continues decoding with identical aggregate price results.

Toolhead records have stable IDs and indices; count edits preserve surviving records and create review-needed defaults for additions. Domain validation checks count, identity, architecture and assignment constraints. UI routes all storage mutations through application state and repository protocols.

## Apple platforms

`PrintQuote3D.xcodeproj` contains a multiplatform application target for native macOS, iPhone and iPad. It links QuoteDomain and QuoteData from the local package. SwiftData persists a local snapshot on each device. AdaptiveLibrary switches between two-pane and single-pane layouts based on available width; QuoteEditor uses Details/Price tabs in narrow layouts. Platform-specific window sizing is guarded with `#if os(macOS)`. No cloud synchronization is implied.
