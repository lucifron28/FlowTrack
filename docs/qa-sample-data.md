# Demo And QA Sample Data

Use this dataset for phone testing and video demos.

## Load Or Reset Data

1. Open FlowTrack.
2. Log in with the local owner account.
3. Go to More, then Settings.
4. In the Demo data card, tap Sync demo data.
5. For a clean recording state, tap Reset demo data and confirm.

Sync demo data loads or repairs the sample products and customers without duplicating completed sample transactions. Reset demo data clears local business records and reloads the baseline dataset. Owner login is not changed.

## Products To Scan

| Product | Barcode | Type | Demo note |
| --- | --- | --- | --- |
| Lucky Me Pancit Canton Chilimansi | `4807770271137` | Manufacturer | Good for repeated scan and cash sale. |
| 555 Sardines Tomato Sauce | `4800110020307` | Manufacturer | Used in credit-sale sample data. |
| Nescafe Original Stick | `4800361417406` | Manufacturer | Good for multi-quantity sale. |
| Great Taste White Sachet | `4800016112306` | Manufacturer | Used in credit-sale sample data. |
| SkyFlakes Crackers | `4800016640706` | Manufacturer | Good for basic sale. |
| C2 Green Tea Apple 230ml | `4804888801234` | Manufacturer | Good for cash sale demo. |
| Safeguard White Bar 60g | `4800888206019` | Manufacturer | Normal stock item. |
| Piattos Cheese 40g | `4800016060218` | Manufacturer | Low-stock item. |
| Coke Sakto 200ml | `4801981111112` | Manufacturer | Out-of-stock item. |
| Asukal Tingi 1/4 kilo | `FT-TINGI-ASUKAL` | Store-generated | Good for tingi barcode demo. |
| Mantika Tingi 100ml | `FT-TINGI-MANTIKA` | Store-generated | Good for tingi barcode demo. |
| Bigas Tingi 1 kilo | `FT-TINGI-BIGAS` | Store-generated | Good for tingi barcode demo. |

## Other Records Loaded

- Customers: Aling Nena, Mang Lito, Ate Joy.
- One completed cash sale for today's dashboard.
- Two credit sales for utang testing.
- One partial credit payment for Mang Lito.
- Expenses for restocking, utilities, and transportation.

## Barcode Assets

- `docs/qa-barcode-sheet.svg`: printable scan sheet.
- `docs/qa-barcodes/`: individual PNG files for each sample product.

If camera scanning has trouble with glare, open one PNG at a time on another device or use the manual barcode field.

## QA Checklist

1. Dashboard shows non-zero sales, expenses, net income, outstanding credit, and low-stock count.
2. Inventory search finds Piattos and shows low stock.
3. Inventory search finds Coke Sakto and shows out of stock.
4. Sales New Sale scans `4807770271137`.
5. Scanning the same barcode again increments quantity.
6. Scanning `4801981111112` blocks sale because stock is zero.
7. Cash sale calculates change.
8. Credit sale increases the selected customer's outstanding balance.
9. Credit payment reduces outstanding balance.
10. Expense entry changes dashboard/report net income.
11. Voiding a sale restores inventory.
12. Reports exclude voided sales.
13. Airplane mode still allows sale, expense, credit, dashboard, and report checks.
