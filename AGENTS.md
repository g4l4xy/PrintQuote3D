# PrintQuote development

For user-facing feature requests, treat Apple (macOS/iOS/iPadOS) and Android as one product unless the user scopes the change to a platform.

- Start from a shared outcome in `docs/features/<slug>.md`; `./pq feature <slug> "Title"` scaffolds it when beginning from a clean checkout.
- Keep common data contracts, source provenance and expected calculation examples in `SharedSchemas/`. Do not duplicate catalogs into platform source trees.
- Implement Swift/SwiftUI and Kotlin/Compose equivalents on the same feature branch. Changes to shared JSON alone do not implement native UI behavior.
- Test the same expected results and error cases on both platforms. Keep existing saved quotes and user overrides compatible.
- Run `./pq check` before publishing a feature. This builds macOS, iOS Simulator and Android, runs domain tests and Android lint. Record interaction tests separately; builds do not establish device interaction coverage.
- Update the feature acceptance/evidence and documentation honestly. Do not mark unfinished or unverified items complete.
- Platform-specific bug fixes and repository tooling/docs changes do not require artificial edits to the other platform; document why.

Sync through normal Git branches. Use fast-forward pull and normal push. Do not force push, reset, discard user edits or automatically stage unrelated IDE files. `./pq push -m "Message" -- <paths>` publishes selected paths; `--all` explicitly includes all non-ignored edits.
