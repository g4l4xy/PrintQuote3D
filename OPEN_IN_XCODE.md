# Open PrintQuote 3D in Xcode

1. Keep the complete extracted **PrintQuote3D** folder together.
2. Open **PrintQuote3D.xcodeproj** (not just an individual Swift file).
3. Choose the **PrintQuote3D** scheme.
4. Pick **My Mac**, an iPhone simulator, an iPad simulator, or your connected iPhone/iPad.
5. Press **Command-R**.

Requires Xcode 16 or newer for Swift 6; verified using Xcode 26.6 / Swift 6.3.3. Deployment targets are macOS 14, iOS 17 and iPadOS 17. The app target supports iPhone and iPad natively, plus native macOS (not Catalyst).

## Physical iPhone or iPad

Under the PrintQuote3D app target → **Signing & Capabilities**, select your Apple development team. Change the bundle identifier to a unique identifier for your team if needed. Xcode manages the development profile. No account, signing certificate or team identifier is bundled with this source.

If a simulator destination is missing, install its runtime in Xcode → Settings → Components. Physical-device builds were verified with signing disabled; installation onto your own hardware requires your signing team.

## Included files

- A ready-to-open Xcode project with a shared scheme and unit-test target.
- One shared SwiftUI app for Mac, iPhone and iPad.
- Local SwiftData persistence per device, Decimal pricing logic and 1–12 tool configuration.
- 1,004 real printer profiles, plus three legacy demos; searchable directly in Printers and estimates.
- Offline filament catalog and source directory, with licensing and provenance.
- Portable JSON schemas, import scripts, tests and documentation.

All data is included locally. No remote Swift-package dependencies or server setup are required. Data is saved separately on each device; iCloud synchronization is not implemented.

## Screen behavior

Wide windows show library/detail and estimate/cost panes side by side. Phones and narrow iPad windows show a single library page at a time, with an All printers/All filaments/All materials back button. Narrow estimates have **Details** and **Price breakdown** tabs. Sheets use the available device size.

## Verification for this delivery

- 24 unit tests pass with Swift Package Manager and the Xcode macOS scheme.
- Native macOS app builds, launches, searches the printer catalog, and selects a manufacturer-sourced printer for an estimate.
- iOS simulator SDK and physical iOS-device SDK builds succeed for arm64, with device families 1 and 2 (iPhone/iPad).
- iPhone/iPad interaction and physical installation remain unverified. The simulator runtime was not installed on this Mac; its slow download was cancelled. This is a build-verified mobile port, with actual device QA still to perform.

To run tests in Xcode, press **Command-U**. For CLI checks, run `swift test`. If the system blocks an Xcode test runner reading Documents, use Xcode's normal Derived Data location or `/tmp/PrintQuote3DValidation` instead of putting Derived Data inside Documents.

The checked-in project is ready to use. `project.yml` allows regeneration with XcodeGen 2.46.0 (`xcodegen generate`), but XcodeGen is not required to open or build it.

## Current feature scope

Quotes use manual print inputs; Jobs, Inventory and Analytics remain future screens. There is no STL/3MF parsing, live pricing, PDF export or cloud sync yet. See README for the complete implemented scope and source coverage.
