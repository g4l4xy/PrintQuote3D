# Reliability and quality-of-life upgrade

## Shared outcome

Implement the supplied reliability/QOL request in controlled groups across Apple, Android and Windows. Preserve historical quote inputs, user overrides, offline startup and deterministic pricing. The previously excluded provider remains excluded. A checked item below means implemented and verified, not merely planned.

## First group: Windows SQLite safety

This group repairs Windows-specific database opening and backup behavior; Apple uses SwiftData and Android uses atomic JSON storage, so these SQL changes do not alter their storage implementations.

- Read `user_version` before changing it; reject newer databases rather than downgrading them.
- Check SQLite integrity before enabling WAL or attempting migration.
- Initialize new databases transactionally. The only supported legacy migration is an unversioned workspace table to version 1; validate its document and create a backup before migration.
- Keep schema creation and version changes in the same transaction.
- Enable foreign keys, a bounded lock timeout and FULL synchronization on every application connection. The current single-document table has no relational foreign keys; this enables enforcement for future relational tables, not JSON references.
- Before replacing a saved workspace, validate its existing envelope and create a consistent SQLite backup, including committed WAL pages.
- Publish backups only after integrity verification and atomic rename. Keep three routine recovery snapshots; migration snapshots are independent and retained.
- Refuse a save/migration if its backup cannot complete. A failed SQL transaction rolls back the entire document.
- Preserve unknown JSON fields, precise decimal values, quote snapshots and user overrides.
- Provide an Export Backup action in Windows settings that refuses to overwrite an existing destination, plus an Open Recovery Folder action in settings and on startup failure. Restore and broader safe-mode controls remain pending.

Backups are local private workshop data, stored beside the database under `database/backups`. They contain quote/customer information and must never be included in a support bundle by default.

SQLite references: [consistent live backups](https://www.sqlite.org/lang_vacuum.html#vacuum_with_an_into_clause), [integrity, version and connection pragmas](https://www.sqlite.org/pragma.html).

## Acceptance evidence

Verified on 2026-09-14:

- Windows: 21 passing tests: eight new database failure/recovery tests, three existing SQLite/catalog tests, ten shared Kotlin pricing/parity tests.
- Tests cover future database versions, corrupt-file byte preservation and handle release, version-0 migration backups, blocked-backup failure, transaction rollback, rolling retention, exports including committed WAL pages, and unsupported document schemas.
- `./pq check`: Apple and Android passed, including Swift/shared pricing tests, macOS/iOS Simulator builds and Android tests/build/lint.
- MSI 0.3.7 installed with exit 0 and launched in Parallels Windows 11. Parsed workspace before/after upgrade matched exactly (1,007 profiles, three saved materials, no quotes).
- Export Backup exercised through the installed GUI at 200% scaling. Exported SQLite integrity passed and the complete document matched the pre-upgrade workspace exactly. An unwritable destination surfaced an error without altering the workspace; retrying to a writable user folder succeeded. The chooser uses the app icon and returns to the intact settings screen.

## Remaining requested work

The overall pass is not complete. Subsequent groups must implement and verify:

1. Debounced autosave and draft recovery with explicit save states across native apps; undo/redo; central errors and rotated structured logging.
2. Backup/export/restore UI, safe mode, Apple/Android recovery and tested migrations appropriate to their stores.
3. Validated, quarantined, incremental source updates; caching, hashes, freshness, health, retries/cancellation and circuit breaking; field-level overlays and conflict review.
4. Global background search, favorites/recents, duplication, Quick/Advanced Quote, inline warnings, Explain Price and evidence-based confidence.
5. Cancellable background jobs, bounded STL/3MF parsing and partial recovery, performance measurements.
6. Privacy-safe support bundles, feature flags, revisions/audit history, price guardrails, production feedback, reservations, maintenance, comparisons and scheduling warnings.

Do not count existing placeholders or repository-only primitives as completed user-facing features.
