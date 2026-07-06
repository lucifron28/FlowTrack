# Offline-First Architecture

FlowTrack is built local-first because the FRD requires an Android app that works without internet and does not require cloud synchronization.

## Source Of Truth

The local Drift/SQLite database in `lib/core/database/app_database.dart` is the source of truth for:

- Products.
- Stock movements.
- Sales and sale items.
- Customers.
- Credit records and credit payments.
- Expenses.
- Settings.
- App metadata.
- Audit logs.

The `sync_queue` table exists only as a placeholder for a future approved sync design.

## Offline Behavior

These flows must work without internet:

- Owner setup and login.
- Inventory add/edit/restock/adjust.
- Barcode scan or manual barcode entry.
- Cash sale.
- Credit sale.
- Customer credit payment.
- Expense recording.
- Dashboard summaries.
- Reports.
- Sale voiding.
- Demo data sync/reset from local sample definitions.

Supabase is not initialized during app startup. Missing Supabase credentials must not break local use.

## Supabase Boundary

Supabase is installed only for future optional backup, schema preparation, or sync work. It must not become required for:

- App startup.
- Owner login.
- Inventory.
- Sales.
- Credits.
- Expenses.
- Dashboard.
- Reports.
- Settings.

Service role keys must never be placed in Flutter client code.

## Future Sync Requirements

A future sync design needs approval before implementation. Required decisions:

- Whether the FRD scope expands beyond single-device use.
- Device identity strategy.
- Conflict handling.
- Deleted and voided record behavior.
- Sync queue processing.
- Row-level security policies.
- Backup and restore behavior.
- Offline behavior while sync is unavailable.
