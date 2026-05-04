# Decisions

## Confirmed Architecture Decisions

- Flutter Android-first MVP.
- Local-first Drift/SQLite source of truth.
- Supabase installed only for future optional backup/sync/schema preparation.
- Five bottom tabs: Dashboard, Sales, Inventory, Credits, More.
- More contains Expenses, Reports, and Settings.
- Use `mobile_scanner` plus manual barcode fallback.
- Mark sales `voided` instead of physically deleting completed sales.
- Low stock formula follows the confirmed FRD-literal rule: `stock > 0 && stock <= lowStockLevel * 0.25`.
- Reports use gross completed sales and show credit given/collected separately.
- Offline owner login uses secure storage and PBKDF2-HMAC-SHA256 password hashing.

## Business Rules That Must Not Change Silently

- Stock is deducted only after `Complete Sale`.
- Adding to the cart does not deduct stock.
- Sale items keep product/price snapshots.
- Voided sales restore inventory and are excluded from reports.
- Voiding a credit sale reverses the related customer credit balance.
- Credit payments allocate oldest-first.
- No negative stock.
- No cash underpayment.
- No credit overpayment.
- Local database records remain the source of truth.
- Supabase must never block offline use.
- Service role keys must never be exposed in Flutter code.
- App name references should use `AppConfig.appName`.

## Open Decisions

- Final product name.
- Final Android application ID.
- Whether Supabase sync should ever be enabled.
- Local backup, Supabase backup, or both.
- PDF export, CSV export, or both.
- Whether receipt printing is required.
- Whether barcode printing is required.
- Target printer model.
- Offline password recovery/reset policy.
- Whether partial credit payments during sale are allowed.
- Whether overpayment is ever allowed.
- Whether negative stock is ever allowed.
- Whether cost price should drive profit reports.
- Whether iOS should be supported later.

## Current Known Gaps

- Theme mode is saved but not rehydrated before startup.
- Barcode scanner needs device QA.
- Store profile, category management, exports, printing, cloud backup, and sync are placeholders.
- Android release signing and branding are not finalized.
