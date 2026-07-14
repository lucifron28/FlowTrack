import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  test('product creation stores the normalized barcode', () async {
    final id = await database.createProduct(
      name: 'Spaced Product',
      barcode: ' 123  456 ',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 100,
      initialStock: 10,
      lowStockLevel: 2,
    );

    final product = await database.getProduct(id);
    expect(product!.barcode, '123456');
  });

  test('lookup with spaced input finds that product', () async {
    await database.createProduct(
      name: 'Test Product',
      barcode: '123456',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 100,
      initialStock: 10,
      lowStockLevel: 2,
    );

    final product = await database.findProductByBarcode(' 123  456 ');
    expect(product, isNotNull);
    expect(product!.name, 'Test Product');
  });

  test('differently spaced variants are detected as duplicates', () async {
    await database.createProduct(
      name: 'Product A',
      barcode: ' 12 34 56 ',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 100,
      initialStock: 10,
      lowStockLevel: 2,
    );

    expect(
      () => database.createProduct(
        name: 'Product B',
        barcode: '1234  56',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 150,
        initialStock: 5,
        lowStockLevel: 1,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('UPC-A lookup finds an equivalent leading-zero EAN-13 record', () async {
    // EAN-13 stored with leading zero (length 13)
    await database.createProduct(
      name: 'EAN-13 Product',
      barcode: '0036000291452',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 100,
      initialStock: 10,
      lowStockLevel: 2,
    );

    // Look up using UPC-A representation '036000291452' (length 12)
    final product = await database.findProductByBarcode('036000291452');
    expect(product, isNotNull);
    expect(product!.name, 'EAN-13 Product');
  });

  test('EAN-13 lookup finds an equivalent UPC-A record', () async {
    // UPC-A stored (length 12)
    await database.createProduct(
      name: 'UPC-A Product',
      barcode: '036000291452', // UPC-A valid
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 100,
      initialStock: 10,
      lowStockLevel: 2,
    );

    // Look up using EAN-13 representation '0036000291452' (length 13)
    final product = await database.findProductByBarcode('0036000291452');
    expect(product, isNotNull);
    expect(product!.name, 'UPC-A Product');
  });

  test('invalid manufacturer checksum is rejected', () async {
    expect(
      () => database.createProduct(
        name: 'Invalid Checksum',
        barcode: '4006381333932', // EAN-13 ending in 2 instead of 1
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 100,
        initialStock: 10,
        lowStockLevel: 2,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('valid EAN-8, UPC-A and EAN-13 creation succeeds', () async {
    // EAN-8
    final id8 = await database.createProduct(
      name: 'EAN-8 Product',
      barcode: '96385074',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 100,
      initialStock: 10,
      lowStockLevel: 2,
    );
    expect(id8, isNotEmpty);

    // UPC-A
    final id12 = await database.createProduct(
      name: 'UPC-A Product',
      barcode: '036000291452',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 100,
      initialStock: 10,
      lowStockLevel: 2,
    );
    expect(id12, isNotEmpty);

    // EAN-13
    final id13 = await database.createProduct(
      name: 'EAN-13 Product',
      barcode: '4006381333931',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 100,
      initialStock: 10,
      lowStockLevel: 2,
    );
    expect(id13, isNotEmpty);
  });

  test('store-generated FT-* barcodes remain accepted', () async {
    final id = await database.createProduct(
      name: 'Store Generated Product',
      barcode: 'FT-123-456',
      barcodeType: BarcodeType.storeGenerated,
      sellingPrice: 100,
      initialStock: 10,
      lowStockLevel: 2,
    );

    final product = await database.getProduct(id);
    expect(product, isNotNull);
    expect(product!.barcode, 'FT-123-456');
  });
}
