# Video Demo Script

This script is for a short phone-recorded demo of the current offline MVP.

## Before Recording

1. Build and install the latest debug APK.
2. Open the app and log in.
3. Go to More, then Settings.
4. Tap Reset demo data.
5. Confirm the reset.
6. Open `docs/qa-barcode-sheet.svg` or individual PNGs from `docs/qa-barcodes/` on another screen.
7. Turn on airplane mode for the offline portion if you want to show local-first behavior.

## Suggested Recording Flow

### 1. Dashboard

Show:

- Total sales today.
- Total expenses today.
- Net income today.
- Outstanding credit.
- Low-stock item count.
- Recent sales and low-stock preview.

Say:

FlowTrack works from local phone storage. The dashboard is generated from the local Drift/SQLite database.

### 2. Inventory

Show:

- Product list.
- Search for Piattos.
- Search for Coke Sakto.
- Open a store-generated tingi item.

Point out:

- Piattos is low stock.
- Coke Sakto is out of stock.
- Store-generated tingi products use one barcode per product type.

### 3. Tingi Barcode PDF

Open a store-generated product and tap Print Barcode Sheet.

Show:

- Barcode value.
- Save PDF button.
- Share PDF button.

Say:

The app can generate a Code 128 PDF sheet for store-generated tingi items. Dedicated printer hardware support is still pending.

### 4. Fast Selling Mode

Open Sales, then New Sale.

Scan:

- `4807770271137`
- `4807770271137` again

Show:

- Product added to cart.
- Quantity increments on repeated scan.
- Stock has not been deducted yet.

Then scan:

- `4801981111112`

Show:

- App blocks selling because stock is zero.

### 5. Cash Sale

Continue with a valid cart.

Show:

- Total.
- Amount received.
- Change.
- Complete Sale.

After completion:

- Open sale details or Dashboard.
- Confirm totals updated.

### 6. Credit Sale

Start another sale.

Choose Credit.

Select or create a customer, such as Ate Joy.

Complete the sale.

Show:

- Credits tab.
- Customer outstanding balance increased.

### 7. Credit Payment

Open a customer with balance.

Record a payment.

Show:

- Outstanding balance decreases.
- Payment is stored locally.

### 8. Expense

Go to More, then Expenses.

Add an expense.

Show:

- Expense list.
- Dashboard or Reports net income changes.

### 9. Reports

Go to Reports.

Show:

- Daily.
- Weekly.
- Monthly.
- Custom range.

Mention:

Reports are generated from local records and exclude voided sales.

### 10. Void Sale

Open a completed sale.

Void it with a reason.

Show:

- Sale is marked voided.
- Inventory stock is restored.
- Credit balance is reversed for credit sales.

## Demo Safety Notes

- Use Reset demo data before each take to avoid inconsistent totals.
- Use manual barcode entry if camera glare makes scanning unreliable.
- Keep Supabase discussion short: it is installed for future optional backup/sync only and is not required for the demo.
- Do not demo unfinished areas as completed features.

## Current Demo Risks

- Camera scanner behavior still needs physical-device QA.
- Theme choice is saved but not restored before startup.
- Report export, receipt printing, dedicated barcode printer support, cloud backup, and Supabase sync are not implemented.
