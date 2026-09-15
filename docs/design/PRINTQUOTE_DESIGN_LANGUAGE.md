# PrintQuote Design Language · PQ Design 1.0

Research date: 15 September 2026. Implementation baseline: PrintQuote 0.4.0, SwiftUI (macOS 14 / iOS 17 minimum), Compose Material 3 on Android and Compose Desktop on Windows. Preserve these minimum versions.

## Formula

**PQ Design = Apple clarity + selective Liquid Glass depth + Material adaptive structure + Fluent desktop efficiency + precise manufacturing data.**

Our interpretation is a graphite/porcelain workspace, royal-blue actions, aligned technical values, fine separators and a distinct tool layer. This is engineering/business software: restrained, readable and familiar across platforms. No decorative neon, full-screen gradients or glass tables.

## Identity and hierarchy

Content is the anchor. Workspace backgrounds use level 0; continuous data panels level 1; selected/raised groups level 2. Navigation and tools occupy level 3. Sheets and command search occupy level 4. Rounded shapes communicate interactivity, not arbitrary grouping. Prefer section dividers over a card around every field.

A screen starts with identity, a concise description and a primary action. Collections follow with search/filter tools, counts and bounded results. Details use identity/actions, overview, technical sections, pricing, sources and overrides. Saved values, unknown specifications and source provenance must remain distinguishable.

## Glass

PQ Glass is a semantic material, not a common blur shader. Apple uses native `glassEffect` for selected custom tool surfaces on OS 26+, native navigation and system sheets, with standard-material fallbacks on supported older OS versions. Reduce Transparency or increased contrast uses opaque surfaces. Do not stack custom glass inside native glass toolbars. Quote price data remains opaque; only inspector tools may use glass.

Android uses Material tonal surfaces and native interaction states. Windows uses restrained layered opaque/tonal surfaces inspired by Mica, with translucent overlays only when supported. The existing Compose Desktop renderer is not WinUI: never label a painted surface native Mica or Acrylic. Neither implementation imitates Apple's refraction.

## Color, typography, space and shape

Use semantic tokens from `SharedSchemas/pq-design-tokens.json`. Light is porcelain with graphite text; dark is graphite with off-white text. Blue denotes action/selection. Status colors always accompany words or icons. Body copy uses native system typography; numbers use tabular figures, right alignment in comparisons and explicit units. Spacing follows 2/4/8/12/16/20/24/32/40/48/64. Controls use small corners, panels medium, overlays large. See the companion specifications.

## Adaptation and density

Measure available window space, not device model. Compact <600, Medium 600–839, Expanded 840–1199, Wide >=1200 logical units. Height and text size can require a single pane even at a wide width. Phone navigation exposes a few primary destinations and a More/menu path; all desktop destinations remain reachable. Desktop uses a sidebar, local search, tables and optional detail panes. More room adds simultaneous information instead of oversized controls. User table preferences survive this migration.

## Motion and accessibility

Motion is brief and functional. Retain native focus rings, menu behavior, sheet semantics and keyboard activation. Respect Reduce Motion and Reduce Transparency; never hide information behind an animation. Provide in-app accessibility overrides where a desktop renderer cannot reliably observe an OS setting. Opaque high-contrast content is always available. Target 4.5:1 body-text contrast, 3:1 large text/control boundaries, 44 pt Apple touch and 48 dp Android touch targets. Dynamic Type/font scaling must cause wrapping/reflow, not tiny scaled text.

## Migration and acceptance

Implement in reviewable stages: tokens/components and previews; navigation/dashboard; quote workspace; libraries/details/settings; verification. Keep pricing/import/storage code outside this UI migration. A successful build is not evidence of pointer, screen-reader or visual acceptance. Record actual checks in `verification.md`.

## Official research and decisions

- [Apple Design Resources](https://developer.apple.com/design/resources/): reviewed the current iOS/iPadOS 27 and macOS 27 resources. Use system fonts/symbols and native controls, not exported UI artwork.
- [Liquid Glass overview](https://developer.apple.com/documentation/technologyoverviews/liquid-glass) and [custom SwiftUI views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views): standard navigation/controls adopt the material; custom effects should be limited and grouped efficiently. Availability-gate new APIs.
- [HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials): glass belongs to controls/navigation, distinct from content. Prefer regular glass for legibility. The visible revision history lists September 9, 2025 for the Liquid Glass guidance. Apple documentation's first-party JSON representation was read when the HTML required JavaScript.
- [Android UI](https://developer.android.com/design/ui) and [Material 3 in Compose](https://developer.android.com/develop/ui/compose/designsystems/material3): map semantic color/type/shape roles into MaterialTheme, preserve built-in interaction semantics. Current guidance also covers M3 Expressive; PQ uses its adaptive/component principles with restrained styling.
- [Adaptive apps](https://developer.android.com/develop/ui/compose/layouts/adaptive/get-started-with-adaptive-apps) and [window size classes](https://developer.android.com/develop/ui/compose/layouts/adaptive/use-window-size-classes): adapt to changing available dimensions, including height and fold/window changes. The size-class page reports August 4, 2026. PQ combines large/extra-large into Wide, retaining the 600/840/1200 transitions.
- [Windows app design](https://learn.microsoft.com/en-us/windows/apps/design/), [Mica](https://learn.microsoft.com/en-us/windows/apps/design/style/mica), [Acrylic](https://learn.microsoft.com/en-us/windows/apps/design/style/acrylic): persistent backgrounds and transient overlays have different material roles. Avoid repeated translucent layers; prioritize solid fallbacks and desktop density.
- [Windows keyboard](https://learn.microsoft.com/en-us/windows/apps/design/input/keyboard-interactions) and [accessibility](https://learn.microsoft.com/en-us/windows/apps/design/accessibility/accessibility-overview): keyboard operation and visible focus are primary interaction requirements. Native widget behavior is preferred to custom painted clickable text.

Documentation without an explicit version is identified by the access date above; these pages do not define a single cross-platform version number. This design formula is our synthesis, not an endorsement or copied vendor design system.
