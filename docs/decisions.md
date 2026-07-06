# Decisions

This file records decisions that should stay stable unless the owner explicitly changes them.

## Confirmed Decisions

- Flutter Android-first MVP.
- Single store owner.
- Single-device daily operation.
- Local Drift/SQLite database is the source of truth.
- Supabase is optional and future-facing only.
- Bottom navigation uses five tabs: Dashboard, Sales, Inventory, Credits, More.
- More contains Expenses, Reports, and Settings.
- Barcode scanning uses `mobile_scanner` with manual barcode fallback.
- Store-generated tingi barcodes use one barcode per product type.
- Store-generated barcode sheets use Code 128 PDF output.
- Completed sales are marked `voided` instead of physically deleted.
- Stock is deducted only after Complete Sale.
- Reports use gross completed sales and show credit given/collected separately.
- Credit payments allocate oldest-first.
- Offline owner login uses secure storage and PBKDF2-HMAC-SHA256 password hashing.

## Rules That Must Not Change Silently

- Do not replace local-first architecture with cloud-first architecture.
- Do not require Supabase for app startup or daily use.
- Do not make Supabase Auth required for offline login.
- Do not add multi-user, cashier, customer login, online payment, delivery, e-commerce, multi-branch, or cloud sync behavior without approval.
- Do not physically delete completed sales unless approved.
- Do not allow negative stock unless approved.
- Do not allow cash underpayment unless approved.
- Do not allow payment over outstanding balance unless approved.
- Do not change report accounting rules silently.
- Do not expose Supabase service role keys in Flutter code.
- Do not hardcode the app name outside `AppConfig.appName`.

## Open Decisions

- Final product name.
- Final Android application ID.
- Whether Supabase sync should ever be enabled.
- Whether backup should be local file, Supabase cloud backup, or both.
- Whether report export should be PDF, CSV, or both.
- Whether receipt printing is required.
- Whether PDF barcode sheets are enough or dedicated barcode printer support is required.
- Target printer model and label size if printing is required.
- Offline password recovery/reset policy.
- Whether partial credit payment during a sale is allowed.
- Whether credit overpayment is ever allowed.
- Whether negative stock is ever allowed.
- Whether cost price should drive profit reports.
- Whether iOS support is needed later.

## Current Gaps

- Scanner crop/framing needs more physical-device work.
- Theme mode is saved but not rehydrated before startup.
- Store profile editing is not implemented.
- Product deactivate/reactivate is not implemented.
- Product and expense category management are not implemented.
- Report export is not implemented.
- Receipt printing is not implemented.
- Dedicated barcode printer integration is not implemented.
- Local backup/export is not implemented.
- Supabase schema/sync work is not implemented.
- Android release signing, final package ID, app icon, and final branding are not done.

## Demo Data Decision

Settings includes demo data tools for QA and video recording:

- Sync demo data loads or repairs the Filipino sari-sari sample dataset.
- Reset demo data clears local business records and reloads the sample dataset.
- Owner login is not reset by demo-data reset.
- Demo data is for development and video demos, not production store data.
