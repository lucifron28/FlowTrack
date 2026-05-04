# Offline-First Architecture

FlowTrack is local-first because the FRD requires an Android app that works without internet and does not require cloud synchronization.

## Local Database As Source Of Truth

The Drift/SQLite database in `lib/core/database/app_database.dart` is the source of truth for products, stock movements, sales, sale items, customers, credit records, credit payments, expenses, settings, metadata, placeholder sync queue rows, and audit logs.

Core flows must read and write local data first:

- Owner setup/login.
- Inventory add/edit/restock/adjust.
- Barcode scan/manual lookup.
- Cash and credit sale completion.
- Customer credit payment.
- Expense recording.
- Dashboard summaries.
- Reports.
- Sale voiding.

## Behavior Without Internet

The app should still open, authenticate locally, record transactions, update inventory, show dashboard metrics, and generate reports without network access. Supabase is not initialized in the current app startup path and missing Supabase configuration must not break local usage.

## Why Supabase Is Optional

Supabase is installed only for future backup, cloud schema preparation, or optional sync after explicit approval. The FRD currently says single-device deployment and no cloud synchronization, so Supabase cannot be required for daily operation.

## Future Sync Requirements

Any future sync design needs owner approval and must define:

- Whether the FRD scope expands beyond single-device use.
- Device identity.
- Conflict handling.
- Deleted/voided record behavior.
- RLS policies.
- How local records remain usable while offline.
- How service role keys stay out of Flutter client code.
