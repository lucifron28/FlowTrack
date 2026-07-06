# FlowTrack

FlowTrack is the temporary name for an offline-first Flutter Android MVP based on the FRD: "Development of a Mobile-Based Cash Flow and Credit Monitoring Information System for a Sari-Sari Store."

## Temporary App Name Notice

The product name is centralized in `lib/core/config/app_config.dart` as `AppConfig.appName`. User-facing app-name references in Flutter code should read from that config. The Android launcher label currently uses `FlowTrack` in `android/app/src/main/AndroidManifest.xml` and must be updated when the final app identity is approved.

## Project Overview

FlowTrack helps one sari-sari store owner record sales, manage per-piece inventory, track customer utang, record expenses, view dashboard summaries, and generate basic reports. The app is built around local/offline operation first. Supabase is installed for future optional backup/sync/schema preparation only and must not block daily use.

## FRD-Based System Scope

In scope for the current MVP:

- Offline Android Flutter app for a single store owner.
- Dashboard, Sales, Inventory, Credits, Expenses, Reports, and Settings.
- Local Drift/SQLite transaction storage.
- Barcode scanning with manual fallback.
- Local owner setup/login.
- No required cloud synchronization.

Out of scope unless explicitly approved:

- Multi-user access, cashier accounts, customer login, online payments, delivery, e-commerce, multi-branch support, cloud-first operation, and required Supabase login/sync.

## Implementation Status Legend

- ✅ Implemented and tested
- 🟡 Implemented but needs testing/polish
- 🧩 Placeholder only
- 🔜 Planned for next milestone

## Feature Status

- ✅ Local Drift/SQLite database setup.
- ✅ App name/config foundation via `AppConfig.appName`.
- ✅ Supabase installed but not initialized or required for startup.
- ✅ Filipino sari-sari QA sample data loader with scan-ready products.
- ✅ Business-rule unit tests for product status, sale totals, cash change, stock deduction, credit balances, expenses, voiding, report exclusion, price snapshots, oldest-first allocation, and store barcode uniqueness.
- 🟡 Flutter Android project setup with Material 3 theme.
- 🟡 Five-tab bottom navigation: Dashboard, Sales, Inventory, Credits, More.
- 🟡 Offline owner setup/login using secure storage plus PBKDF2-HMAC-SHA256 password hashing; needs device/security review before production.
- 🟡 Inventory management: add product, edit price/cost/low-stock settings, restock, adjust stock, stock history. Delete/deactivate is not implemented.
- 🟡 Manufacturer barcode product flow with camera scan and manual entry.
- 🟡 Store-generated tingi/repacked barcode flow with printable PDF barcode sheet save/share support.
- 🟡 Barcode scanner with visible scan overlay and manual barcode fallback; needs physical-device QA.
- 🟡 Sales list and new sale flow.
- 🟡 Fast Selling Mode behavior: scan/search adds item, repeated scans increment quantity, and stock is not deducted until completion.
- 🟡 Cash sale completion with amount received and change.
- 🟡 Credit sale completion with existing/new customer support.
- 🟡 Customer credit balances and oldest-first payment allocation.
- 🟡 Expense recording and inclusion in dashboard/report calculations.
- 🟡 Dashboard summaries: sales today, expenses today, net income, outstanding credit, low stock count, recent sales, low stock preview.
- 🟡 Daily/weekly/monthly/custom reports from local data.
- 🟡 Void transaction: marks sale voided, restores stock, reverses related credit balance, writes a void audit log.
- 🟡 Settings screen: theme controls, app/about info, Supabase status placeholder, backup/export placeholders, logout. Theme selection is saved but not rehydrated on app startup.
- 🧩 Supabase sync.
- 🧩 Cloud backup.
- 🧩 PDF/CSV export.
- 🟡 Barcode PDF generation for tingi/repacked items. Dedicated Bluetooth/USB printer integration is not implemented.
- 🧩 Receipt printing.
- 🧩 Password reset.
- 🧩 Store profile editing.
- 🧩 Product category management.
- 🧩 Expense category management.
- 🧩 Multi-device sync.
- 🧩 Advanced analytics.
- 🔜 Android release signing, branding, final application ID, and release hardening.

## FRD Compliance Checklist

| FRD Requirement | Status | Notes |
| --- | --- | --- |
| Mobile-based Android application | 🟡 | Flutter Android project builds, but release identity/signing are not finalized. |
| Offline-capable operation | 🟡 | Core flows use local Drift/SQLite. Needs device QA without internet. |
| Single-device deployment | ✅ | No multi-device sync is implemented. |
| Owner login required | 🟡 | Local owner setup/login implemented; needs device QA. |
| Password authentication | 🟡 | PBKDF2-HMAC-SHA256 plus secure storage implemented; needs production security review. |
| Logout function | 🟡 | Implemented in Settings; not covered by widget/integration tests yet. |
| Single active user only | 🟡 | Local owner account only; no account switching UI. |
| Dashboard module | 🟡 | Summary cards and previews implemented from local DB. |
| Sales module | 🟡 | Cash, credit, complete sale, sales history, and void dialog implemented. |
| Inventory module | 🟡 | Per-piece stock management implemented; deactivate/delete is not implemented. |
| Credits module | 🟡 | Customer balances, records, and payments implemented. |
| Expenses module | 🟡 | Expense recording and dashboard/report inclusion implemented. |
| Reports module | 🟡 | Daily, weekly, monthly, custom summaries implemented; export placeholders only. |
| Settings module | 🟡 | Settings screen implemented; several settings are placeholders. |
| Bottom navigation | 🟡 | Five-tab layout implemented. |
| Manufacturer barcode support | 🟡 | Camera scan and manual fallback implemented; needs physical-device scanner QA. |
| Store-generated barcode for tingi/repacked items | 🟡 | One generated barcode per product type implemented with printable PDF sheet save/share support. |
| Stock deduction only after Complete Sale | ✅ | Implemented and covered by unit tests. |
| Void transaction restores stock | ✅ | Implemented and covered by unit tests. |
| Credit sale increases outstanding balance | ✅ | Implemented and covered by unit tests. |
| Credit payment reduces outstanding balance | ✅ | Implemented and covered by unit tests. |
| Local transaction storage | ✅ | Drift/SQLite tables and generated code are present. |
| Offline operation | 🟡 | Supabase is not required; still needs device-level offline QA. |
| Cloud sync excluded from core scope | ✅ | Supabase is optional/future-facing only. |
| Multi-user access excluded | ✅ | Out of FRD scope and not implemented. |
| Online payment excluded | ✅ | Out of FRD scope and not implemented. |

## Core Business Rules

- Stock is deducted only after `Complete Sale` is pressed.
- Adding an item to the current sale does not deduct stock yet.
- Product price changes apply only to future transactions.
- Sale items must store product name, barcode, unit price, and cost price snapshots.
- Historical sale totals must not change when product prices are edited.
- Voided sales should be marked as voided instead of physically deleted.
- Voiding a sale restores inventory quantities.
- Voiding a credit sale reverses the related customer credit balance.
- Credit sales increase customer outstanding balance.
- Credit payments reduce customer outstanding balance.
- Credit payments are allocated oldest-first unless changed later.
- Reports must exclude voided sales.
- Reports must include completed cash and credit sales according to the report rules.
- Expenses reduce net income.
- Stock cannot become negative unless explicitly approved.
- Payment amount cannot exceed outstanding balance unless explicitly approved.
- Local database records are the source of truth.
- Supabase must never block offline usage.
- Supabase service role keys must never be exposed in Flutter code.
- The temporary app name must stay centralized in `AppConfig.appName`.

## Development Rules for Codex

- Do not replace the offline-first architecture with a cloud-first design.
- Do not initialize Supabase as a required dependency for app startup.
- Do not add multi-user, cashier, customer login, online payment, delivery, e-commerce, or cloud sync unless approved.
- Do not physically delete completed sales; mark them voided unless approved.
- Do not allow stock to become negative unless approved.
- Do not allow payment over outstanding balance unless approved.
- Do not use raw SHA-256 alone for password storage.
- Do not hardcode the app name outside `AppConfig.appName`.
- Do not expose Supabase service role keys in Flutter code.
- Do not change accounting, inventory, or credit rules silently.
- Ask for clarification before changing business rules.
- If something is missing, add a placeholder and document it.
- If README and implementation disagree, update the README or fix the implementation, whichever is safer and more accurate.

## Tech Stack

- Flutter stable, Dart, Material 3.
- Android-first mobile app.
- Riverpod 3 using `Notifier`/`AsyncNotifier` provider patterns.
- `go_router` for routing foundation.
- Drift with SQLite for local persistence.
- `mobile_scanner` for barcode scanning with manual fallback.
- `flutter_secure_storage` for secure local credential storage. Password handling should use a salted, slow password hashing approach rather than raw SHA-256.
- Supabase Flutter installed for future cloud backup/sync/schema preparation only.

## Documentation Reviewed

Official/current docs reviewed before this update:

- Flutter Android setup: `https://docs.flutter.dev/platform-integration/android/setup`
- Flutter Material 3 defaults: `https://docs.flutter.dev/release/breaking-changes/material-3-default`
- Dart Effective Dart: `https://dart.dev/effective-dart`
- Drift docs and migrations: `https://drift.simonbinder.eu/`
- Riverpod `(Async)NotifierProvider`: `https://docs-v2.riverpod.dev/docs/providers/notifier_provider`
- go_router package docs: `https://pub.dev/packages/go_router`
- mobile_scanner package docs: `https://pub.dev/packages/mobile_scanner`
- Supabase Flutter initialization: `https://supabase.com/docs/reference/dart/initializing`
- build_runner docs: `https://pub.dev/packages/build_runner`

## Why Flutter Was Chosen

Flutter fits this Android-first MVP because it provides Material 3 UI, camera plugin support, local database integration, and a path to future iOS if the owner asks for it later.

## Why Local-First/Offline-First

The FRD requires offline operation. The local Drift database is the source of truth for inventory, sales, credits, expenses, dashboard, and reports. The app must still open, log in, and complete core workflows without internet.

## Supabase Status

Supabase is installed for future cloud backup/sync/schema preparation only. It is not required for the offline MVP and must not block local app usage. The current code does not call `Supabase.initialize`, does not require Supabase credentials, and does not include a service role key in Flutter client code.

## Folder Structure

```text
lib/
  main.dart
  app.dart
  core/
    config/
    constants/
    database/
    domain/
    services/
    theme/
    utils/
  features/
    auth/
    dashboard/
    inventory/
    sales/
    credits/
    expenses/
    reports/
    settings/
  shared/
    providers/
    widgets/
docs/
supabase/
test/
```

## Setup Instructions

1. Install Flutter stable and Android tooling.
2. Confirm an emulator or physical Android device is available.
3. Run `flutter pub get`.
4. Run Drift/build_runner generation with `dart run build_runner build`.
5. Run `flutter run`.

## Android Setup Notes

The app uses the current Flutter Android embedding. Camera permission is configured in `android/app/src/main/AndroidManifest.xml`:

- `android.permission.CAMERA`
- `android.hardware.camera` with `required=false`

The camera feature is optional at install time so manual barcode entry remains available.

## Package Installation Notes

Current key packages in `pubspec.yaml`:

- `flutter_riverpod 3.3.1`
- `go_router 17.2.3`
- `drift 2.33.0`
- `drift_flutter 0.3.0`
- `drift_dev ^2.33.0`
- `mobile_scanner 7.2.0`
- `supabase_flutter 2.12.4`
- `flutter_secure_storage 10.0.0`
- `crypto 3.0.7`
- `intl 0.20.2`
- `uuid 4.5.3`
- `barcode 2.2.9`
- `pdf 3.12.0`

Drift is preferred over direct SQLite access because it gives typed queries, migrations, streams, transactions, and testable local database logic.

## Local Database Notes

The local database is implemented in `lib/core/database/app_database.dart`. Money values are stored as integer centavos to avoid floating-point rounding errors.

Tables:

- `products`
- `stock_movements`
- `sales`
- `sale_items`
- `customers`
- `credit_records`
- `credit_payments`
- `expenses`
- `settings`
- `app_metadata`
- `sync_queue`
- `audit_logs`

`credit_records` includes `paidAmount` so payments can be allocated oldest-first and credit records can become unpaid, partially paid, paid, or voided.

## Barcode Scanner Notes

`mobile_scanner` is used for camera scanning. The scanner screen has a visible scan overlay, scan line, guidance text, and manual barcode input for damaged barcodes, denied permissions, unsupported devices, or camera failure.

Store-generated barcode format:

```text
FT-{millisecondsSinceEpoch}-{randomShortCode}
```

This is one barcode per product type for tingi/repacked items, not per piece and not per batch.

Printable barcode sheets are available for store-generated tingi/repacked products. The app generates a Code 128 PDF sheet with repeated labels, product name, price, and barcode value. The sheet can be saved to Downloads or shared as a PDF. Dedicated Bluetooth/USB thermal-printer workflows are not implemented yet because the target printer hardware and label format are not approved.

## User Flows

- First launch: setup owner account, then enter dashboard.
- Login: offline password login.
- Add manufacturer product: scan or manually enter barcode, fill product details, save.
- Add tingi product: generate store barcode, fill details, save, then save or share the barcode PDF sheet.
- Cash sale: scan/search products, enter amount received, complete sale, deduct stock.
- Credit sale: scan/search products, select or create customer, complete sale, increase outstanding balance.
- Record payment: select customer, enter amount, save, update credit status.
- Add expense: choose category, amount, date, save.
- Void sale: mark voided, restore stock, reverse related credit.

## Placeholder Implementations

### Supabase Sync

Status: 🧩 Placeholder only  
Reason: The FRD excludes cloud synchronization and the app is single-device/offline-first.  
Decision needed: Decide whether sync should ever be enabled and what conflict rules apply.  
Future implementation: Use `sync_queue`, device IDs, RLS-protected Supabase tables, and an approved conflict strategy.

### Cloud Backup

Status: 🧩 Placeholder only  
Reason: Backup destination and restore behavior are not approved.  
Decision needed: Choose local file backup, Supabase backup, or both.  
Future implementation: Add encrypted local export and/or Supabase backup after owner approval.

### Export PDF/CSV

Status: 🧩 Placeholder only  
Reason: Export formats and report layout are not approved.  
Decision needed: Choose PDF, CSV, or both.  
Future implementation: Add report exporters from local report queries.

### Barcode Printing

Status: 🟡 PDF barcode sheet implemented; dedicated printer integration is not implemented.
Reason: The app can generate a Code 128 PDF sheet and use Android's save/share flow, but no specific Bluetooth/USB thermal printer has been approved.
Decision needed: Choose target printer model and label size, or confirm PDF/share output is enough.
Future implementation: Add hardware-specific Bluetooth or USB printing depending on the approved printer.

### Receipt Printing

Status: 🧩 Placeholder only  
Reason: Receipt hardware and layout are not approved.  
Decision needed: Confirm whether receipts are required and choose printer model.  
Future implementation: Add receipt view/export and printer integration.

### Password Reset

Status: 🧩 Placeholder only  
Reason: Offline password recovery can weaken local security or require data reset.  
Decision needed: Choose recovery policy.  
Future implementation: Add owner-approved reset flow, recovery phrase, or documented database reset process.

### Store Profile

Status: 🧩 Placeholder only  
Reason: Store profile fields are not finalized.  
Decision needed: Confirm store name, owner display, address/contact fields.  
Future implementation: Persist editable profile settings in the local `settings` table.

### Product Category Management

Status: 🧩 Placeholder only  
Reason: The FRD does not require product categories.  
Decision needed: Confirm whether categories are needed for filtering/reports.  
Future implementation: Add categories table and product relationship.

### Expense Category Management

Status: 🧩 Placeholder only  
Reason: Current categories are fixed in UI.  
Decision needed: Confirm whether owner-editable expense categories are needed.  
Future implementation: Add expense categories table and management screen.

### Multi-Device Sync

Status: 🧩 Placeholder only  
Reason: Multi-device support conflicts with single-device FRD scope.  
Decision needed: Approve scope expansion and conflict handling.  
Future implementation: Add device identity, sync metadata, conflict resolution, and cloud policies.

### Advanced Analytics

Status: 🧩 Placeholder only  
Reason: Current reports are basic FRD summaries.  
Decision needed: Confirm which analytics matter, such as profit, best sellers, or stock velocity.  
Future implementation: Add query-backed analytics after cost/profit rules are approved.

### Android Release Signing And Branding

Status: 🔜 Planned for next milestone  
Reason: Final app name, package ID, icons, and signing keys are not approved.  
Decision needed: Finalize app identity and release process.  
Future implementation: Update application ID, launcher assets, signing config, and release build documentation.

## Testing

Run:

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

For phone QA, open **More > Settings > QA sample data** and tap **Load**. Then use:

- [QA sample data guide](docs/qa-sample-data.md)
- [Printable barcode scan sheet](docs/qa-barcode-sheet.svg)

Implemented tests cover:

- Product status calculation.
- Sale total calculation.
- Cash change calculation.
- Stock is not deducted before sale completion.
- Stock is deducted after sale completion.
- Credit sale increases outstanding balance.
- Credit payment decreases outstanding balance.
- Oldest-first credit payment allocation.
- Expense affects net income.
- Voided sale restores inventory.
- Voided credit sale reverses customer balance.
- Reports exclude voided sales.
- Product price snapshots stay unchanged after price edit.
- Store-generated barcode uniqueness.
- QA sample data loads once and includes scan-ready products.
- Password hash helper behavior.

Testing still needed:

- Physical-device camera scanner QA.
- Widget/integration tests for owner setup/login/logout.
- Widget/integration tests for full inventory, sales, credits, expenses, reports, and settings flows.
- Offline device QA with airplane mode.

## Known Limitations

- Theme mode writes to local settings but is not rehydrated before app startup yet.
- Barcode scanner needs physical Android device QA.
- Inventory deactivate/delete is not implemented.
- Receipt printing, report PDF/CSV export, cloud backup, and Supabase sync are placeholders only. Barcode PDF sheet generation is implemented for store-generated tingi/repacked products, but dedicated printer hardware integration is still pending.
- Reports are basic summaries and do not yet include profit/cost analytics.
- Local password hashing now uses PBKDF2-HMAC-SHA256 and upgrades legacy salted SHA-256 hashes after successful login, but production defense still needs security review.
- Android release signing, final application ID, app icon, and branding are not finalized.

## Decisions Needed From Owner

- Final product name.
- Final Android application ID.
- Whether Supabase sync should ever be enabled.
- Whether backup should be local file, Supabase cloud backup, or both.
- Whether exports should be PDF, CSV, or both.
- Whether receipt printing is required.
- Whether barcode printing is required.
- Target printer model if printing is required.
- Password recovery policy for offline-only app.
- Whether partial credit payments during sale are allowed.
- Whether overpayment is allowed.
- Whether negative stock is ever allowed.
- Whether profit reports should use cost price.
- Whether iOS support is needed later.

## Future Improvements

- Theme rehydration at startup.
- Full scanner/device QA and scan-window tuning.
- Product deactivate/reactivate.
- Supabase backup/sync after approval.
- Export reports and receipts.
- Barcode print/export.
- Store profile editing.
- Category management.
- Android release signing and branding.

## How To Rename FlowTrack Later

1. Update `AppConfig.appName`.
2. Update Android launcher label in `AndroidManifest.xml`.
3. Search docs and UI text for remaining literal `FlowTrack` references.
4. Update package/application ID only if release identity requires it.

## Troubleshooting

- If generated Drift types are missing, run `dart run build_runner build`.
- If camera scanning fails, use the manual barcode field.
- If dependencies fail to resolve, run `flutter pub get`.
- If Android build fails, run `flutter doctor` and confirm Android SDK setup.
