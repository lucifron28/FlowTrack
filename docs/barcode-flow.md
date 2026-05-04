# Barcode Flow

## Manufacturer Barcode Item Flow

1. Owner opens Inventory.
2. Owner taps Add Item.
3. Owner keeps Manufacturer selected.
4. Owner scans the package barcode or enters it manually.
5. Owner enters product name, selling price, optional cost price, initial stock, and low stock level.
6. Product is saved with a unique barcode.

If the barcode already exists, the app offers to add stock instead.

## Store-Generated Tingi/Repacked Item Flow

1. Owner opens Inventory.
2. Owner taps Add Item.
3. Owner selects Tingi.
4. Owner generates a store barcode.
5. Owner enters product details.
6. Product is saved with the generated barcode.

Generated barcode format:

```text
FT-{millisecondsSinceEpoch}-{randomShortCode}
```

This is one barcode per product type. It is not per piece and not per batch.

## Manual Barcode Fallback

Manual input is available on the scanner screen because camera permission can be denied, hardware can fail, and labels can be damaged.

## Camera Scanner Limitations

`mobile_scanner` is implemented with a visible scan overlay and automatic detection. It still needs physical Android device QA for camera permission prompts, lighting, focus, and real packaging barcodes.

## Fast Selling Mode

During a sale, scanning a known barcode adds the product with quantity 1. Scanning the same barcode increments the quantity if stock is sufficient. Stock is deducted only after `Complete Sale`.
