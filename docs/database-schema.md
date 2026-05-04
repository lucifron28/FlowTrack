# Database Schema

The current local schema lives in `lib/core/database/app_database.dart` and is generated into `app_database.g.dart` by Drift. Money values are stored as integer centavos.

## Tables And Fields

- `products`: `id`, `name`, `barcode`, `barcodeType`, `sellingPrice`, nullable `costPrice`, `stock`, `lowStockLevel`, `isActive`, `createdAt`, `updatedAt`.
- `stock_movements`: `id`, `productId`, `movementType`, `quantity`, nullable `reason`, nullable `relatedSaleId`, nullable `notes`, `createdAt`.
- `sales`: `id`, `saleNumber`, `saleDate`, `totalAmount`, `paymentType`, nullable `amountReceived`, nullable `changeAmount`, nullable `customerId`, `status`, nullable `voidReason`, `createdAt`, `updatedAt`.
- `sale_items`: `id`, `saleId`, `productId`, `productNameSnapshot`, `barcodeSnapshot`, `unitPriceSnapshot`, nullable `costPriceSnapshot`, `quantity`, `subtotal`.
- `customers`: `id`, `name`, nullable `contactNumber`, `outstandingBalance`, `isActive`, `createdAt`, `updatedAt`.
- `credit_records`: `id`, `customerId`, nullable `saleId`, `amount`, `paidAmount`, `status`, `creditDate`, `createdAt`, `updatedAt`.
- `credit_payments`: `id`, `customerId`, `amount`, `paymentDate`, nullable `notes`, `createdAt`.
- `expenses`: `id`, `category`, nullable `description`, `amount`, `expenseDate`, `createdAt`, `updatedAt`.
- `settings`: `id`, `key`, `value`, `updatedAt`.
- `app_metadata`: `id`, `databaseVersion`, `firstRunCompleted`, `ownerAccountCreated`, `createdAt`, `updatedAt`.
- `sync_queue`: placeholder table with entity/operation/status metadata for future sync design.
- `audit_logs`: audit table currently written by void-sale operations.

## Relationships

- `sale_items.saleId` references `sales.id`.
- `sale_items.productId` references `products.id`.
- `stock_movements.productId` references `products.id`.
- `stock_movements.relatedSaleId` may reference `sales.id`.
- `sales.customerId` may reference `customers.id`.
- `credit_records.customerId` references `customers.id`.
- `credit_records.saleId` may reference `sales.id`.
- `credit_payments.customerId` references `customers.id`.

## Sale Item Snapshots

Sale items store product name, barcode, unit price, and cost price snapshots. This keeps historical sale totals stable when product prices are edited later.

## Stock Movements

Every implemented stock-changing path records a stock movement:

- Initial stock when a product is created with stock.
- Restock.
- Adjustment add/deduct.
- Sale deduction.
- Void restore.

Stock cannot become negative.

## Credit Records

Credit sales create credit records and increase customer outstanding balance. Payments reduce outstanding balance and allocate oldest-first across unpaid or partially paid credit records. Overpayment is blocked.

## Voiding Rules

Voided sales are marked `voided` instead of being physically deleted. Voiding restores inventory quantities, writes `void_restore` stock movements, reverses the related credit record if the sale was credit, and writes a void audit log. Reports exclude voided sales.
