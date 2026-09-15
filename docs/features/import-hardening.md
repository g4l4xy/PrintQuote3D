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

Validation: pending.
