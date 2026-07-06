# Barcode Flow

Barcode support covers inventory entry, fast selling, manual fallback, and printable sheets for store-generated tingi products.

## Manufacturer Barcode Product

Current status: Partial. Camera scan and manual entry exist; physical-device QA is still needed.

Flow:

1. Open Inventory.
2. Tap Add Item.
3. Keep Manufacturer selected.
4. Scan the package barcode or enter it manually.
5. Enter product name, selling price, optional cost price, initial stock, and low-stock level.
6. Save the product.

If the barcode already exists, the app offers to add stock instead.

## Store-Generated Tingi Product

Current status: Partial. Barcode generation and PDF sheet output exist; dedicated printer integration is pending.

Flow:

1. Open Inventory.
2. Tap Add Item.
3. Select Tingi.
4. Generate a store barcode.
5. Enter product details.
6. Save the product.
7. The app opens the printable barcode sheet screen.
8. Save or share the PDF sheet.

Generated format:

```text
FT-{millisecondsSinceEpoch}-{randomShortCode}
```

Rule: one barcode per product type, not per piece and not per batch.

## Printable Barcode Sheet

The app generates a Code 128 PDF sheet for store-generated products.

Each label contains:

- Product name.
- Selling price.
- Barcode bars.
- Human-readable barcode value.

The PDF can be saved to Android Downloads or shared through Android's share sheet. Bluetooth and USB printer support is not implemented because the printer model and label size are not approved.

## Sales Scanner Behavior

During a sale:

1. Scan a known barcode.
2. App adds the product to the current cart with quantity 1.
3. Scan the same barcode again.
4. Quantity increments if stock is sufficient.
5. Stock is deducted only after Complete Sale.

If a product is out of stock or quantity would exceed stock, the app blocks the cart change.

## Manual Fallback

Manual barcode input is required and implemented because:

- Camera permission can be denied.
- Device camera quality varies.
- Screen glare can affect QA barcode sheets.
- Product barcodes can be damaged.
- The app must remain usable offline and without camera scanning.

## Demo Barcode Assets

- `docs/qa-barcode-sheet.svg` contains a printable scan sheet.
- `docs/qa-barcodes/` contains individual PNG barcode cards.
- `docs/qa-sample-data.md` lists every demo barcode value.

## Known Scanner Risks

- Scanner framing needs more physical-device QA.
- Lighting and focus still need testing on the demo phone.
- The scanner detects barcodes in the camera image; the visual frame is a guide and not a hard crop unless the scanner configuration is further refined.
