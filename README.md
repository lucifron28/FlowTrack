# FlowTrack

FlowTrack is the temporary name for an offline-first Flutter Android MVP for a sari-sari store owner. It is based on the FRD titled "Development of a Mobile-Based Cash Flow and Credit Monitoring Information System for a Sari-Sari Store."

The app is local-first. Drift/SQLite is the source of truth. Supabase is installed only for future backup, schema preparation, or optional sync work after approval. Supabase is not initialized during startup and is not required for daily use.

## Current Project State

Foundation status:

| Area | Status | Notes |
| --- | --- | --- |
| Flutter Android app | Partial | Builds as a debug APK. Release identity, signing, and final branding are pending. |
| App name centralization | Done | `AppConfig.appName` is the central Flutter app-name source. Android launcher label still needs final identity cleanup later. |
| Material 3 theme | Partial | Light/dark theme exists. Theme selection is saved but not rehydrated before startup yet. |
| Bottom navigation | Done | Dashboard, Sales, Inventory, Credits, More. |
| Local database | Done | Drift/SQLite schema and generated code are present. |
| Offline-first architecture | Done | Core app flows use local data and do not require Supabase. |
| Supabase | Pending | Package installed only. No startup initialization, credentials, service role key, or sync logic. |

Feature status:

| Feature | Status | Notes |
| --- | --- | --- |
| Owner setup/login/logout | Partial | Offline local owner setup/login works with secure storage and PBKDF2-HMAC-SHA256. Needs production security review and more widget tests. |
| Dashboard | Partial | Shows sales today, expenses today, net income, outstanding credit, low-stock count, recent sales, and low-stock preview from local DB. Needs phone QA. |
| Inventory | Partial | Add, edit price/cost/low-stock settings, restock, adjust stock, stock history, search, status filter. Product deactivate/delete is not implemented. |
| Manufacturer barcode products | Partial | Camera scan and manual barcode entry are implemented. Needs physical-device scanner QA. |
| Store-generated tingi barcodes | Partial | Generates one barcode per product type and creates printable Code 128 PDF sheets. Dedicated Bluetooth/USB printer integration is pending. |
| Sales | Partial | Sales list, new sale, scan/search cart, cash sale, credit sale, amount received, change, and void transaction are implemented. Needs phone QA. |
| Fast Selling Mode | Partial | Scanning or searching adds items to the cart and repeated scans increment quantity. Stock is deducted only after Complete Sale. |
| Credits / utang | Partial | Customers, balances, credit records, and payments are implemented. Payments allocate oldest-first. Needs phone QA. |
| Expenses | Partial | Expense recording and report/dashboard inclusion are implemented. Category management is pending. |
| Reports | Partial | Daily, weekly, monthly, and custom range summaries are implemented. PDF/CSV export is pending. |
| Settings | Partial | Theme control, app/about info, Supabase placeholder, backup placeholder, demo data tools, and logout exist. Store profile editing is pending. |
| Demo data | Done | Settings can sync demo data and reset/reload a clean demo dataset. Scan-ready barcode PNGs are in `demo/barcodes/`. |
| Tests | Partial | Core unit tests pass. More widget/integration tests and physical-device QA are still needed. |

## Demo Data

Use this before phone QA or video recording:

1. Install and open the app.
2. Log in or create the local owner account.
3. Go to More, then Settings.
4. Open the Demo data card.
5. Tap Sync demo data to load or repair the sample dataset.
6. Tap Reset demo data when you need a clean recording state. This clears local products, sales, credits, expenses, and stock history, then reloads the demo dataset. Owner login is not changed.

Demo barcode files:

- `docs/demo.md` lists all sample products, test cases, and the recording flow.
- `demo/qa-barcode-sheet.svg` is a printable scan sheet.
- `demo/barcodes/` contains individual PNG barcode files.

## Recommended Video Demo Flow

1. Start on Dashboard and show the local summaries.
2. Open Settings and tap Sync demo data or Reset demo data.
3. Open Inventory and show Filipino sari-sari products, low-stock status, and out-of-stock status.
4. Open a store-generated tingi item and show Print Barcode Sheet.
5. Save or share the barcode PDF.
6. Open Sales, start a new sale, scan a barcode, scan it again to show quantity increment, and show that stock is not deducted yet.
7. Complete a cash sale and show amount received plus change.
8. Complete a credit sale for a customer.
9. Open Credits, record a partial payment, and show outstanding balance update.
10. Add an expense.
11. Open Reports and show daily/weekly/monthly/custom summaries.
12. Void a completed sale and show that inventory and reports update.
13. Mention that Supabase is optional and not required for offline use.

## Core Business Rules

- Local Drift/SQLite records are the source of truth.
- Supabase must never block offline use.
- Stock is deducted only after Complete Sale.
- Adding an item to the sale cart does not deduct stock.
- Stock cannot become negative.
- Sale items store product name, barcode, unit price, and cost price snapshots.
- Product price edits affect only future sales.
- Completed sales are marked voided instead of physically deleted.
- Voiding a sale restores inventory.
- Voiding a credit sale reverses the related customer credit balance.
- Credit sales increase outstanding balance.
- Credit payments reduce outstanding balance.
- Credit payments allocate oldest-first.
- Credit overpayment is blocked.
- Reports exclude voided sales.
- Expenses reduce net income.
- Store-generated tingi barcodes are one barcode per product type, not per piece or batch.
- Supabase service role keys must never be placed in Flutter client code.
- App-name references should use `AppConfig.appName`.

## Tech Stack

- Flutter and Dart
- Material 3
- Android-first mobile target
- Riverpod 3
- go_router
- Drift and SQLite
- mobile_scanner
- flutter_secure_storage
- barcode and pdf packages for printable tingi barcode sheets
- Supabase Flutter package installed for future optional work only

Current pinned package versions are in `pubspec.yaml` and `pubspec.lock`.

## Setup

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is generated at:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Camera scanning uses Android camera permission. Manual barcode entry is required and remains available when camera scanning fails.

## Local Database

The schema lives in `lib/core/database/app_database.dart`.

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

Money values are stored as integer centavos.

## Documentation

- `README.md`: project status, features, setup, business rules, tests, pending work, and decisions.
- `docs/demo.md`: phone demo script, QA checklist, sample data, and scan values.
- `demo/README.md`: barcode asset manifest aligned with Sync demo data.
- `demo/qa-barcode-sheet.svg`: printable scan sheet.
- `demo/barcodes/`: individual PNG barcode cards for phone testing.

## Implemented Tests

Current tests cover:

- Product status calculation.
- Sale total and cash change calculation.
- Stock is not deducted before sale completion.
- Stock is deducted after sale completion.
- Credit sale increases outstanding balance.
- Credit payment decreases outstanding balance.
- Oldest-first credit payment allocation.
- Expense impact on net income.
- Voided sale inventory restoration.
- Voided credit sale credit reversal.
- Reports exclude voided sales.
- Product price snapshots remain stable after price edits.
- Store-generated barcode uniqueness.
- Demo data load/sync/reset behavior.
- Printable barcode PDF generation.
- Password hash helper behavior.

## Pending Work

Highest priority before the video demo:

- Physical Android QA for scanner framing, lighting, focus, permissions, and manual fallback.
- Physical Android QA for barcode PDF save/share.
- Small-screen UI pass on Inventory, Reports, Settings, Sales, and scanner screens.
- Verify the full demo flow in airplane mode.

Product gaps:

- Theme rehydration at app startup.
- Store profile editing.
- Product deactivate/reactivate.
- Product category management.
- Editable expense categories.
- Report PDF/CSV export.
- Receipt printing.
- Dedicated barcode printer integration.
- Local backup/export.
- Supabase backup/sync after approval.
- Android release signing, final app icon, final application ID, and final app name.
- More widget and integration tests.

## Decisions Needed

- Final product name.
- Final Android application ID.
- Whether Supabase sync should ever be enabled.
- Whether backup should be local file, Supabase cloud backup, or both.
- Whether exports should be PDF, CSV, or both.
- Whether receipt printing is required.
- Whether barcode PDF output is enough or dedicated printer support is required.
- Target printer model and label size if printing is required.
- Offline password recovery policy.
- Whether partial credit payment during a sale is allowed.
- Whether overpayment is ever allowed.
- Whether negative stock is ever allowed.
- Whether profit reports should use cost price.
- Whether iOS support is needed later.

## Rename FlowTrack Later

1. Update `AppConfig.appName`.
2. Update Android launcher label in `android/app/src/main/AndroidManifest.xml`.
3. Search docs and UI text for remaining literal `FlowTrack` references.
4. Update Android package/application ID only after the final release identity is approved.

## Troubleshooting

- If generated Drift types are missing, run `dart run build_runner build`.
- If dependencies fail, run `flutter pub get`.
- If scanning fails, use manual barcode entry.
- If Android build fails, run `flutter doctor` and verify Android SDK setup.
