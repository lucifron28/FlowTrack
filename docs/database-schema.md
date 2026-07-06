# Database Schema

The local schema is implemented in `lib/core/database/app_database.dart` and generated into `lib/core/database/app_database.g.dart` by Drift.

Money values are stored as integer centavos.

## Tables

| Table | Status | Purpose |
| --- | --- | --- |
| `products` | Implemented | Product catalog, barcode, price, cost, stock, low-stock level, active flag. |
| `stock_movements` | Implemented | Stock history for initial stock, restock, sale deduction, void restore, and manual adjustments. |
| `sales` | Implemented | Sale header, payment type, amount received, change, customer link, status, void reason. |
| `sale_items` | Implemented | Sale line items with product and price snapshots. |
| `customers` | Implemented | Customer records and outstanding balances. |
| `credit_records` | Implemented | Credit sale balances, paid amount, and status. |
| `credit_payments` | Implemented | Customer payment history. |
| `expenses` | Implemented | Expense entries used by dashboard and reports. |
| `settings` | Implemented | Key-value app settings and demo-data loaded flag. |
| `app_metadata` | Implemented | Local database metadata. |
| `sync_queue` | Placeholder | Reserved for future approved Supabase sync. |
| `audit_logs` | Partial | Currently used for void-sale audit records. |

## Key Fields

- `products.barcode` is unique.
- `products.stock` cannot become negative through implemented flows.
- `sales.status` is `completed` or `voided`.
- `sale_items.productNameSnapshot`, `barcodeSnapshot`, `unitPriceSnapshot`, and `costPriceSnapshot` preserve historical sale records.
- `credit_records.paidAmount` supports oldest-first payment allocation.
- `settings.qa_sample_data_loaded` records whether the demo dataset was loaded.

## Relationships

- `sale_items.saleId` references `sales.id`.
- `sale_items.productId` references `products.id`.
- `stock_movements.productId` references `products.id`.
- `stock_movements.relatedSaleId` may reference `sales.id`.
- `sales.customerId` may reference `customers.id`.
- `credit_records.customerId` references `customers.id`.
- `credit_records.saleId` may reference `sales.id`.
- `credit_payments.customerId` references `customers.id`.

## Implemented Rules

- Creating a product with initial stock records an initial stock movement.
- Restock and stock adjustment update product stock and create stock movements.
- Sale cart changes do not change stock.
- Complete Sale validates stock, writes sale records, writes sale item snapshots, deducts stock, and creates sale deduction movements.
- Cash sale requires amount received and stores change.
- Credit sale requires a customer and creates a credit record.
- Credit payment cannot exceed outstanding balance.
- Credit payments allocate oldest-first across unpaid and partially paid records.
- Voiding marks the sale voided, restores stock, writes void restore movements, reverses related credit, and creates an audit log.
- Reports count completed sales only and exclude voided sales.
- Demo reset clears business records and reloads sample data without changing owner login.

## Pending Schema Work

- Real migrations for schema version changes.
- Product category tables if category management is approved.
- Expense category tables if editable categories are approved.
- Backup/export metadata if local backup is approved.
- Sync metadata and cloud IDs only if Supabase sync is approved.
