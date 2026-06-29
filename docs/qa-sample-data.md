# FlowTrack QA Sample Data

Use this guide for phone testing. Open the app, log in, go to **More > Settings**, and tap **Load** under **QA sample data**.

The loader is idempotent. It loads once and then disables itself so the same app database is not duplicated.

## What Gets Loaded

Products:

| Product | Barcode To Scan | Type |
| --- | --- | --- |
| Lucky Me Pancit Canton Chilimansi | `4807770271137` | Manufacturer |
| 555 Sardines Tomato Sauce | `4800110020307` | Manufacturer |
| Nescafe Original Stick | `4800361417406` | Manufacturer |
| Great Taste White Sachet | `4800016112306` | Manufacturer |
| SkyFlakes Crackers | `4800016640706` | Manufacturer |
| C2 Green Tea Apple 230ml | `4804888801234` | Manufacturer |
| Safeguard White Bar 60g | `4800888206019` | Manufacturer |
| Piattos Cheese 40g | `4800016060218` | Manufacturer, low stock |
| Coke Sakto 200ml | `4801981111112` | Manufacturer, out of stock |
| Asukal Tingi 1/4 kilo | `FT-TINGI-ASUKAL` | Store-generated |
| Mantika Tingi 100ml | `FT-TINGI-MANTIKA` | Store-generated |
| Bigas Tingi 1 kilo | `FT-TINGI-BIGAS` | Store-generated |

Also loaded:

- Customers: Aling Nena, Mang Lito, Ate Joy.
- Completed cash sale for today's dashboard.
- Two credit sales for utang testing.
- Partial credit payment for Mang Lito.
- Expenses for restocking, utilities, and transportation.

## Things To Scan

Open [qa-barcode-sheet.svg](qa-barcode-sheet.svg) on a laptop/tablet or print it. These are Code 39 barcodes. If the camera has trouble with screen glare, use the manual barcode input field with the values above.

## QA Pass Checklist

1. Dashboard shows non-zero sales, expenses, net income, outstanding credit, and low stock count.
2. Inventory search finds `Piattos` and shows it as low stock.
3. Inventory search finds `Coke Sakto` and shows it as out of stock.
4. Sales > New Sale > scan `4807770271137`; item is added.
5. Scan the same item again; quantity increments.
6. Scan `4801981111112`; app blocks selling because stock is zero.
7. Complete a cash sale and confirm dashboard/reports update.
8. Complete a credit sale for Ate Joy and confirm Credits updates.
9. Record a partial payment for Aling Nena or Mang Lito.
10. Void a completed sale and confirm stock is restored.
11. Add a manual expense and confirm reports net income changes.
12. Put the phone in airplane mode and repeat a sale, expense, and report check.

## Known Scanner Notes

- Screen glare can make camera scanning unreliable. Increase brightness on the display showing the scan sheet.
- Hold the phone steady and keep the barcode inside the scanner frame.
- Use manual input to test damaged-label and denied-permission fallback behavior.
