# FlowTrack

FlowTrack is an offline-first Flutter Android MVP for a sari-sari store owner. It is based on the FRD titled "Development of a Mobile-Based Cash Flow and Credit Monitoring Information System for a Sari-Sari Store."

The app is local-first. Drift/SQLite is the source of truth. There is no required cloud backend. Backups are handled with local `.flowtrack-backup` JSON files that the owner can save or share outside the phone.

## Current Project State

Foundation status:

| Area | Status | Notes |
| --- | --- | --- |
| Flutter Android app | Partial | Builds as a debug APK. Android app identity is set for FlowTrack. Release signing is prepared; final app icon is pending. |
| App name centralization | Done | `AppConfig.appName` is the central Flutter app-name source. Android launcher label uses the final FlowTrack name. |
| Material 3 theme | Done | Light/dark theme exists. Theme selection is saved and automatically rehydrated at startup. |
| Bottom navigation | Done | Dashboard, Sales, Inventory, Credits, More. |
| Local database | Done | Drift/SQLite schema and generated code are present. |
| Offline-first architecture | Done | Core app flows use local data and do not require internet or cloud services. |
| Local backup | Done | Settings can create/share `.flowtrack-backup` files and restore them with confirmation. |

Feature status:

| Feature | Status | Notes |
| --- | --- | --- |
| Owner setup/login/logout | Done | Offline local owner setup/login works with secure storage and PBKDF2-HMAC-SHA256. Theme and owner profile are rehydrated on startup. |
| Dashboard | Done | Shows sales today, expenses today, net income, outstanding credit, low-stock count, recent sales, and low-stock preview from local DB. |
| Inventory | Done | Add, edit price/cost/low-stock settings, restock, adjust stock, stock history, search, status filter. Product deactivation (archival) is fully implemented. |
| Manufacturer barcode products | Done | Camera scan and manual barcode entry are implemented. Corrected EAN-13 checksums and barcode formats. |
| Store-generated tingi barcodes | Done | Generates one barcode per product type and creates printable Code 128 PDF sheets. Dedicated Bluetooth/USB printer integration is pending. |
| Sales | Done | Sales list, new sale, scan/search cart, cash sale, credit sale, amount received, change, and void transaction are implemented. Excludes archived products from scanner and sales. |
| Fast Selling Mode | Done | Scanning or searching adds items to the cart and repeated scans increment quantity. Stock is deducted only after Complete Sale. |
| Credits / utang | Done | Customers, balances, credit records, and payments are implemented. Payments allocate oldest-first. Customer edit and delete operations (with balance/history validation) are fully implemented. |
| Expenses | Done | Expense recording, editing, deleting, and report/dashboard inclusion are implemented. |
| Reports | Done | Daily, weekly, monthly, and custom range summaries are implemented. PDF/CSV export is pending. |
| Settings | Done | Theme control, app/about info, local backup/restore, demo data tools, and logout exist. Store profile/owner editing is fully implemented. |
| Demo data | Done | Settings can sync demo data and reset/reload a clean demo dataset. Scan-ready barcode PNGs are in `demo/barcodes/`. |
| Tests | Done | Unit and widget tests pass, including database flows, domain calculations, demo data, barcode PDFs, and high-risk sales/inventory UI paths. |

## Backup and Restore

FlowTrack supports local JSON backup files with the `.flowtrack-backup` extension.

Included in backup:

- products, stock movements, sales, sale items
- customers, credit records, credit payments
- expenses, settings, app metadata, audit logs

Not included:

- owner password and secure-storage credentials
- generated barcode PDF files
- temporary cache files
- cloud sync data

Restore replaces the current local store data after confirmation. Owner login is not changed. Owners should save backup files outside the phone when possible, such as to Google Drive through Android share sheet, email, USB transfer, or another file manager destination.

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
13. Mention that no cloud service is required and backups are local files.

## Core Business Rules

- Local Drift/SQLite records are the source of truth.
- Cloud services must never block offline use.
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

Current pinned package versions are in `pubspec.yaml` and `pubspec.lock`.

## Setup

Requires Flutter stable version `3.44.5` (compatible with Dart `^3.11.5`).

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
- `audit_logs`

Money values are stored as integer centavos.

## Documentation

- `README.md`: project status, features, setup, business rules, tests, pending work, and decisions.
- `docs/backup.md`: local `.flowtrack-backup` format, owner flow, restore behavior, and limits.
- `docs/demo.md`: phone demo script, QA checklist, sample data, and scan values.
- `docs/release-checklist.md`: Android identity, release signing, demo QA, and final release blockers.
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
- Local backup JSON export/restore behavior.
- Printable barcode PDF generation.
- Password hash helper behavior.
- Product active/deactive deactivation toggles and active list filtering.
- Customer update and delete operations with balance/history constraint validation.
- Expense update and delete operations.

## Pending Work

Highest priority before the video demo:

- Physical Android QA for scanner framing, lighting, focus, permissions, and manual fallback.
- Physical Android QA for barcode PDF save/share.
- Small-screen UI pass on Inventory, Reports, Settings, Sales, and scanner screens.
- Verify the full demo flow in airplane mode.

Product gaps:

- Product category management.
- Editable expense categories.
- Report PDF/CSV export.
- Receipt printing.
- Dedicated barcode printer integration.
- CSV/PDF report export.
- Real release keystore/private signing config and final app icon.
- More widget and integration tests.

## Decisions Needed

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

## App Identity

- Final app name: FlowTrack.
- Android application ID: `com.flowtrack.app`.
- Android namespace: `com.flowtrack.app`.
- Flutter app-name references should continue to use `AppConfig.appName`.
- Android launcher label is stored in `android/app/src/main/res/values/strings.xml`.

## Troubleshooting

- If generated Drift types are missing, run `dart run build_runner build`.
- If dependencies fail, run `flutter pub get`.
- If scanning fails, use manual barcode entry.
- If Android build fails, run `flutter doctor` and verify Android SDK setup.
