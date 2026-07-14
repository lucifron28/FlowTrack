import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide Column;

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  Future<Product> createProduct({
    int stock = 5,
    int price = 1000,
    String barcode = 'P-001',
    bool isActive = true,
  }) async {
    final id = await database.createProduct(
      name: 'Test Product $barcode',
      barcode: barcode,
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: price,
      initialStock: stock,
      lowStockLevel: 20,
    );
    if (!isActive) {
      await database.updateProductActive(productId: id, isActive: false);
    }
    return (await database.getProduct(id))!;
  }

  test('duplicate lines within available stock', () async {
    final product = await createProduct(stock: 5, price: 1000);
    final saleId = await database.completeSale(
      lines: [
        SaleRequestLine(productId: product.id, quantity: 2),
        SaleRequestLine(productId: product.id, quantity: 3),
      ],
      paymentType: PaymentType.cash,
      saleDate: DateTime.now(),
      amountReceived: 5000,
    );

    final sale = await database.getSale(saleId);
    final items = await database.getSaleItems(saleId);
    final movements = await database.watchStockMovements(product.id).first;

    expect(sale!.totalAmount, 5000);
    expect(items.length, 1);
    expect(items.single.quantity, 5);
    expect(items.single.subtotal, 5000);
    expect((await database.getProduct(product.id))!.stock, 0);

    final saleDeductions = movements.where(
      (m) => m.movementType == StockMovementType.saleDeduction.dbValue,
    );
    expect(saleDeductions.length, 1);
    expect(saleDeductions.single.quantity, 5);
  });

  test('duplicate lines exceeding stock fails and rolls back', () async {
    final product = await createProduct(stock: 5, price: 1000);

    expect(
      () => database.completeSale(
        lines: [
          SaleRequestLine(productId: product.id, quantity: 3),
          SaleRequestLine(productId: product.id, quantity: 3),
        ],
        paymentType: PaymentType.cash,
        saleDate: DateTime.now(),
        amountReceived: 6000,
      ),
      throwsA(isA<StateError>()),
    );

    // Verify stock remains unchanged and no sale items were written
    expect((await database.getProduct(product.id))!.stock, 5);
    final salesList = await database.watchSales().first;
    expect(salesList, isEmpty);
    final saleItemsList = await database.select(database.saleItems).get();
    expect(saleItemsList, isEmpty);
    final movements = await database.watchStockMovements(product.id).first;
    expect(
      movements.where(
        (m) => m.movementType == StockMovementType.saleDeduction.dbValue,
      ),
      isEmpty,
    );
  });

  test('current database price wins over stale prices', () async {
    final product = await createProduct(stock: 5, price: 1000);

    // Simulate price change in database
    await database.editProduct(
      productId: product.id,
      sellingPrice: 1250,
      lowStockLevel: product.lowStockLevel,
    );

    final saleId = await database.completeSale(
      lines: [SaleRequestLine(productId: product.id, quantity: 2)],
      paymentType: PaymentType.cash,
      saleDate: DateTime.now(),
      amountReceived: 2500,
    );

    final item = (await database.getSaleItems(saleId)).single;
    final sale = await database.getSale(saleId);

    expect(item.unitPriceSnapshot, 1250);
    expect(item.subtotal, 2500);
    expect(sale!.totalAmount, 2500);
  });

  test('stale cash amount is rejected', () async {
    final product = await createProduct(stock: 5, price: 1000);

    // Database price changes
    await database.editProduct(
      productId: product.id,
      sellingPrice: 1250,
      lowStockLevel: product.lowStockLevel,
    );

    // Underpay by passing stale price sum (1000 centavos)
    expect(
      () => database.completeSale(
        lines: [SaleRequestLine(productId: product.id, quantity: 1)],
        paymentType: PaymentType.cash,
        saleDate: DateTime.now(),
        amountReceived: 1000,
      ),
      throwsA(isA<StateError>()),
    );

    expect((await database.getProduct(product.id))!.stock, 5);
    expect(await database.watchSales().first, isEmpty);
    final saleItemsList = await database.select(database.saleItems).get();
    expect(saleItemsList, isEmpty);
    final movements = await database.watchStockMovements(product.id).first;
    expect(
      movements.where(
        (m) => m.movementType == StockMovementType.saleDeduction.dbValue,
      ),
      isEmpty,
    );
  });

  test('failed credit sale rollback', () async {
    final product = await createProduct(stock: 5, price: 1000);
    final customerId = await database.createCustomer(name: 'Ate Joy');
    await (database.update(database.customers)
          ..where((tbl) => tbl.id.equals(customerId)))
        .write(CustomersCompanion(isActive: const Value(false)));

    expect(
      () => database.completeSale(
        lines: [SaleRequestLine(productId: product.id, quantity: 2)],
        paymentType: PaymentType.credit,
        saleDate: DateTime.now(),
        customerId: customerId,
      ),
      throwsA(isA<StateError>()),
    );

    // Verify stock remains unchanged, customer balance remains unchanged
    expect((await database.getProduct(product.id))!.stock, 5);
    final customer = await database.getCustomer(customerId);
    expect(customer!.outstandingBalance, 0);

    // Verify database tables are empty of new sales records
    final salesList = await database.watchSales().first;
    expect(salesList, isEmpty);
    final saleItemsList = await database.select(database.saleItems).get();
    expect(saleItemsList, isEmpty);
    final movements = await database.watchStockMovements(product.id).first;
    expect(
      movements.where(
        (m) => m.movementType == StockMovementType.saleDeduction.dbValue,
      ),
      isEmpty,
    );
    final creditRecords = await database.watchCreditRecords(customerId).first;
    expect(creditRecords, isEmpty);
  });

  test('header and item consistency', () async {
    final p1 = await createProduct(stock: 5, price: 1000, barcode: 'P-101');
    final p2 = await createProduct(stock: 5, price: 2000, barcode: 'P-102');

    final saleId = await database.completeSale(
      lines: [
        SaleRequestLine(productId: p1.id, quantity: 2),
        SaleRequestLine(productId: p2.id, quantity: 1),
      ],
      paymentType: PaymentType.cash,
      saleDate: DateTime.now(),
      amountReceived: 4000,
    );

    final sale = await database.getSale(saleId);
    final items = await database.getSaleItems(saleId);

    final itemsSum = items.fold<int>(0, (sum, item) => sum + item.subtotal);
    expect(sale!.totalAmount, itemsSum);
    expect(sale.totalAmount, 4000);
  });

  test('credit consistency', () async {
    final product = await createProduct(stock: 5, price: 1000);
    final customerId = await database.createCustomer(name: 'Ate Joy');

    final saleId = await database.completeSale(
      lines: [SaleRequestLine(productId: product.id, quantity: 2)],
      paymentType: PaymentType.credit,
      saleDate: DateTime.now(),
      customerId: customerId,
    );

    final sale = await database.getSale(saleId);
    final creditRecords = await database.watchCreditRecords(customerId).first;
    final customer = await database.getCustomer(customerId);

    expect(sale!.totalAmount, 2000);
    expect(creditRecords.single.amount, 2000);
    expect(customer!.outstandingBalance, 2000);
  });

  test('other negative paths fail', () async {
    final product = await createProduct(stock: 5, price: 1000, isActive: true);
    final inactiveProduct = await createProduct(
      stock: 5,
      price: 1000,
      barcode: 'P-998',
      isActive: false,
    );

    // 1. Empty request
    expect(
      () => database.completeSale(
        lines: [],
        paymentType: PaymentType.cash,
        saleDate: DateTime.now(),
        amountReceived: 1000,
      ),
      throwsA(isA<StateError>()),
    );

    // 2. Missing product
    expect(
      () => database.completeSale(
        lines: [SaleRequestLine(productId: 'missing-id', quantity: 1)],
        paymentType: PaymentType.cash,
        saleDate: DateTime.now(),
        amountReceived: 1000,
      ),
      throwsA(isA<StateError>()),
    );

    // 3. Inactive product
    expect(
      () => database.completeSale(
        lines: [SaleRequestLine(productId: inactiveProduct.id, quantity: 1)],
        paymentType: PaymentType.cash,
        saleDate: DateTime.now(),
        amountReceived: 1000,
      ),
      throwsA(isA<StateError>()),
    );

    // 4. Zero quantity
    expect(
      () => database.completeSale(
        lines: [SaleRequestLine(productId: product.id, quantity: 0)],
        paymentType: PaymentType.cash,
        saleDate: DateTime.now(),
        amountReceived: 1000,
      ),
      throwsA(isA<StateError>()),
    );

    // 5. Negative quantity
    expect(
      () => database.completeSale(
        lines: [SaleRequestLine(productId: product.id, quantity: -2)],
        paymentType: PaymentType.cash,
        saleDate: DateTime.now(),
        amountReceived: 1000,
      ),
      throwsA(isA<StateError>()),
    );

    // 6. Insufficient stock
    expect(
      () => database.completeSale(
        lines: [SaleRequestLine(productId: product.id, quantity: 10)],
        paymentType: PaymentType.cash,
        saleDate: DateTime.now(),
        amountReceived: 10000,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
