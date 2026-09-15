# PQ Design verification — September 15, 2026

**Implementation is available; native visual, accessibility and performance acceptance remains open.** This record distinguishes compiled behavior and automated checks from human interaction testing. The host desktop is locked, so Mac/Windows visual testing could not be completed. Xcode and the iPhone simulator were not opened.

## Delivered implementation

- A shared semantic token contract, contrast validator, eleven design reference documents, platform adaptation matrix and seven-screen interactive HTML concept preview.
- Apple: System/Light/Dark appearance; native Liquid Glass on supported OS 26+ tools/search/header surfaces, native material fallback on older supported OS versions, opaque fallback for Reduce Transparency, increased contrast or the app's reduced-effects setting. Minimum macOS 14 / iOS 17 remains unchanged.
- Android: Material 3 theme, semantic type/shape/color, bottom navigation below 600 dp, navigation rail at medium widths, permanent navigation at expanded widths. Appearance preferences persist; explicit themes also update system-bar icon contrast.
- Windows: themed desktop navigation, opaque tonal command surfaces, retained context menus and tables, visible field focus, Ctrl+K command palette and Ctrl+F local search. Selected record editing uses an optional right pane at wide window sizes and a dialog otherwise. Closing an edited inspector requests discard confirmation. Quote toolbar actions wrap in narrow layouts on all three implementations.
- Dashboard quick actions and workshop metrics; quote forms with leading price summaries and optional source/equipment panes; collapsed library filters; printer advanced sections; appearance settings on all platforms. Existing pricing, source parsing and persistence algorithms are retained.

## Automated and prototype evidence

| Check | Evidence / scope |
|---|---|
| Incremental stages | Tokens/themes, navigation/dashboard, and quote/library/detail stages each passed Apple, Android and Windows host checks before their commits |
| Token contrast | Text, secondary text and accent meet 4.5:1 against all three content surfaces in both themes; touch-target and breakpoint token assertions pass |
| Swift | 68 existing domain tests; macOS and iOS Simulator builds |
| Android | Build, lint and 32 JVM tests (31 pass; one optional local-file test skipped) |
| Windows host | Desktop compile plus 40 shared/domain/database tests (39 pass; one optional local-file test skipped) |
| Android instrumentation source | Updated tests compile; not executed on emulator/device |
| Workflow tooling | Six temporary-repository tests pass |
| Windows MSI | 0.5.0 packaged in Windows 11; installer exit 0, existing database unchanged, installed process stays running. Installed classpath/jar hashes match package |
| Seven-screen HTML concept | Dashboard, quote builder, both libraries, both detail screens and settings visually inspected; light/dark, compact 390 px, medium 840 px and desktop previews exercised; larger text and high contrast exercised |
| Native SwiftUI previews | Seven representative previews compile, including accessibility-size and opaque-fallback fixtures; not rendered in Xcode |

The HTML is a **design concept with illustrative data**, not a screenshot or functional substitute for the native applications. Its screen/theme/text/contrast controls work; business action buttons are illustrative. The opaque SwiftUI preview uses a custom environment override, not an OS accessibility-setting simulation.

## Remaining acceptance work

- Visually exercise actual Mac, iPhone, iPad, Android and Windows builds in both themes, narrow/short/medium/wide windows, keyboard and pointer workflows.
- Run VoiceOver, TalkBack and Windows screen-reader checks for labels, focus order, selection announcements and error recovery. Verify system text-size, contrast, Reduce Motion and Reduce Transparency behavior on target OS releases.
- Profile scrolling/search against the full catalog, rapid resizing, inspector transitions and layered materials. Token checks do not establish runtime performance or actual rendered contrast over glass.
- Rerun Android instrumentation on a device/emulator; updated test source is not an interaction pass. Prior-release instrumentation results do not qualify this redesign.
- Review detailed platform fit and the final appearance with the user before declaring the redesign accepted.

## Explicit limits and follow-up scope

- Windows uses Compose Desktop tonal surfaces; it does **not** install native DWM Mica/Acrylic. Android also uses opaque tonal surfaces. Neither imitates Apple's shader.
- System appearance is read at Windows theme initialization; live OS-setting changes and OS high-contrast propagation remain unverified. Android offers explicit contrast/reduced-effects controls; automated OS contrast synchronization is not claimed.
- Standard native/Material control motion is retained. PQMotion defines future transition timing; no new decorative animations or custom 3D camera transitions are introduced.
- Model tools currently inspect STL/3MF geometry and metadata. There is no interactive 3D renderer, so Fit/Measure/Supports camera controls have not been invented. Source inspection remains functional and accessible from quote tools.
- Existing unimplemented job/inventory/analytics destinations on Windows are not made functional by this UI migration. Dashboard states make disconnected monitoring/job tracking explicit.
- Semantic tokens are used in migrated surfaces. Legacy detailed editors still contain some local dimensions; a claim of zero remaining literal dimensions would be inaccurate.
