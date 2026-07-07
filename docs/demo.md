# FlowTrack Demo Guide

Use this file for phone QA and video recording. The main project status, features, setup, and pending work live in `README.md`.

## Before Recording

1. Build and install the latest debug APK.
2. Open FlowTrack and log in with the local owner account.
3. Go to More, then Settings.
4. Tap Reset demo data.
5. Confirm the reset.
6. Open `demo/qa-barcode-sheet.svg` or one of the PNG files in `demo/barcodes/` on another screen.
7. Use manual barcode entry if screen glare makes camera scanning unreliable.

The full barcode asset manifest is in `demo/README.md`.

## Demo Data Controls

Settings includes two demo data actions:

- Sync demo data: loads or repairs Filipino sari-sari demo products and customers without duplicating completed sample transactions.
- Reset demo data: clears local products, sales, credits, expenses, and stock history, then reloads the baseline demo dataset. Owner login is not changed.

## Products To Scan

| Product | Barcode | Type | Demo note |
| --- | --- | --- | --- |
| Lucky Me Pancit Canton Chilimansi | `4807770271137` | Manufacturer | Good for repeated scan and cash sale. |
| 555 Sardines Tomato Sauce | `4800110020303` | Manufacturer | Used in credit-sale sample data. |
| Nescafe Original Stick | `4800361417402` | Manufacturer | Good for multi-quantity sale. |
| Great Taste White Sachet | `4800016112300` | Manufacturer | Used in credit-sale sample data. |
| SkyFlakes Crackers | `4800016640704` | Manufacturer | Good for basic sale. |
| C2 Green Tea Apple 230ml | `4804888801232` | Manufacturer | Good for cash sale demo. |
| Safeguard White Bar 60g | `4800888206015` | Manufacturer | Normal stock item. |
| Piattos Cheese 40g | `4800016060212` | Manufacturer | Low-stock item. |
| Coke Sakto 200ml | `4801981111114` | Manufacturer | Out-of-stock item. |
| Asukal Tingi 1/4 kilo | `FT-TINGI-ASUKAL` | Store-generated | Good for tingi barcode demo. |
| Mantika Tingi 100ml | `FT-TINGI-MANTIKA` | Store-generated | Good for tingi barcode demo. |
| Bigas Tingi 1 kilo | `FT-TINGI-BIGAS` | Store-generated | Good for tingi barcode demo. |

Other records loaded:

- Customers: Aling Nena, Mang Lito, Ate Joy.
- One completed cash sale for today's dashboard.
- Two credit sales for utang testing.
- One partial credit payment for Mang Lito.
- Expenses for restocking, utilities, and transportation.

## Recording Flow

1. Dashboard: show sales today, expenses today, net income, outstanding credit, low-stock count, recent sales, and low-stock preview.
2. Settings: show Reset demo data and Sync demo data.
3. Inventory: search Piattos for low stock, search Coke Sakto for out of stock, then open a store-generated tingi item.
4. Tingi barcode: tap Print Barcode Sheet and show Save PDF / Share PDF.
5. Sales: start a new sale, scan `4807770271137`, scan it again, and show quantity increment.
6. Sales stock rule: scan `4801981111114` and show that out-of-stock sale is blocked.
7. Cash sale: enter amount received, show change, and complete the sale.
8. Credit sale: complete a sale for an existing or new customer.
9. Credits: record a payment and show outstanding balance decrease.
10. Expenses: add an expense and show report/dashboard impact.
11. Reports: show daily, weekly, monthly, and custom summaries.
12. Void sale: void a completed sale and show that stock is restored.
13. Offline point: mention that Supabase is optional and not required for these flows.

## Current Demo Risks

- Camera scanner framing and focus still need physical-device QA.
- The visual scanner frame is a guide; detection can still happen elsewhere in the camera image until scanner crop behavior is refined.
- Theme choice is saved but not restored before startup.
- Report export, receipt printing, dedicated barcode printer support, cloud backup, and Supabase sync are not implemented.
