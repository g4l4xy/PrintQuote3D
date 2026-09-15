# Import backend hardening

Strengthen the existing native inspection backend without changing saved quotes or introducing a network dependency. Apple and shared Android/Windows implementations enforce the same limits and failure behavior.

- Bound the combined report's UTF-8 strings to 16 MiB, including repeated keys/source paths; per-field limits alone allowed excessive expansion.
- Cap XML/config/JSON metadata entries at 16 MiB; mesh/G-code and opaque entries retain the 128 MiB limit.
- Verify expanded size and CRC for every file in the ZIP, streaming opaque assets without keeping their payloads in memory.
- Bound ZIP inventory growth while enumerating and STL reads while reading, not just from initial filesystem size.
- Enforce cancellation before opening/reading, during processing, and before returning; use a cooperative two-minute processing budget. This is not a hard process timeout during a library call.
- Escape literal JSON key punctuation so flattened paths do not collide; Apple report rows no longer assume metadata paths are unique IDs.
- Include the archive entry path in processing errors. Failed imports never return a partial success report.
- Handle UTF-8 byte-order marks and reject control characters or empty interior path segments in archive names.

Regression fixtures are shared, synthetic and mirrored in the Apple fixture bundle. Include corrupted opaque entries, report expansion, BOM input, invalid model content and mid-read cancellation. No app/simulator launches are part of this backend change.

Validation — September 15, 2026, implementation commit `9672157`:

- Local `./pq check`: Apple and Android PASS. Swift: 38 tests passed; macOS and iOS Simulator native application builds passed. Android: 24 tests passed, APK assembled, lint passed. The local-model test was explicitly enabled; the private sample remains outside the repository.
- Windows 11, JDK 21: 31 tests passed and one opt-in local-model test skipped. Shared logic and desktop compiled; MSI/EXE packaging passed. The same Kotlin importer source is compiled into Android and Windows.
- Six added regression tests per implementation exercise eleven new synthetic files. Shared and Apple fixture copies match byte-for-byte.
- App/simulator interaction checks and MSI installation were not repeated, respecting the existing request to leave running the application to the user.
- Initial local dependency fetching stalled, then completed. The ZIPFoundation 0.9.20 revision is recorded in `Package.resolved`. No dependency version upgrade was introduced.

No quote persistence or pricing behavior changed. Import failure still produces no partial report. The budgets constrain inspection, not every allocation inside a ZIP/XML/JSON library; the two-minute budget is cooperative rather than a forcibly interrupted library call.
