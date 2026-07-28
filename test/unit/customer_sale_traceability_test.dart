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

  test('new credit sale stores customerNameSnapshot for existing and new checkout customers, null for cash', () async {
    final p1 = await database.createProduct(
      name: 'Noodles',
      barcode: 'P-101',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 1500,
      initialStock: 20,
      lowStockLevel: 5,
    );
    final c1 = await database.createCustomer(
      name: 'Existing Customer',
      contactNumber: '09171112233',
    );

    // 1. Credit sale with existing customer
    final saleId1 = await database.completeSale(
      lines: [SaleRequestLine(productId: p1, quantity: 1)],
      paymentType: PaymentType.credit,
      saleDate: DateTime.now(),
      customerId: c1,
    );

    // 2. Credit sale with new customer created at checkout
    final saleId2 = await database.completeSale(
      lines: [SaleRequestLine(productId: p1, quantity: 1)],
      paymentType: PaymentType.credit,
      saleDate: DateTime.now(),
      customerName: 'Checkout Customer',
    );

    // 3. Cash sale
    final saleId3 = await database.completeSale(
      lines: [SaleRequestLine(productId: p1, quantity: 1)],
      paymentType: PaymentType.cash,
      saleDate: DateTime.now(),
      amountReceived: 2000,
    );

    final sale1 = await database.getSale(saleId1);
    final sale2 = await database.getSale(saleId2);
    final sale3 = await database.getSale(saleId3);

    expect(sale1!.customerId, c1);
    expect(sale1.customerNameSnapshot, 'Existing Customer');

    expect(sale2!.customerId, isNotNull);
    expect(sale2.customerNameSnapshot, 'Checkout Customer');

    expect(sale3!.customerId, isNull);
    expect(sale3.customerNameSnapshot, isNull);
  });

  test('renaming a customer does not alter historical snapshot on completed sale', () async {
    final p1 = await database.createProduct(
      name: 'Bread',
      barcode: 'P-102',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 500,
      initialStock: 10,
      lowStockLevel: 2,
    );
    final c1 = await database.createCustomer(name: 'Original Name');

    final saleId = await database.completeSale(
      lines: [SaleRequestLine(productId: p1, quantity: 1)],
      paymentType: PaymentType.credit,
      saleDate: DateTime.now(),
      customerId: c1,
    );

    await database.updateCustomer(
      customerId: c1,
      name: 'Renamed Customer',
    );

    final sale = await database.getSale(saleId);
    expect(sale!.customerNameSnapshot, 'Original Name');

    final entry = await database.getSaleWithCustomer(saleId);
    expect(entry!.customerName, 'Original Name');
  });

  test('migration v5 -> v6 backfills existing credit sales and leaves cash sales null', () async {
    final rawDb = AppDatabase.inMemory();
    // Drop sales table and recreate without customer_name_snapshot column (schema v5 definition)
    await rawDb.customStatement('DROP TABLE sales;');
    await rawDb.customStatement('''
      CREATE TABLE sales (
        id TEXT NOT NULL PRIMARY KEY,
        sale_number TEXT NOT NULL UNIQUE,
        sale_date INTEGER NOT NULL,
        total_amount INTEGER NOT NULL,
        payment_type TEXT NOT NULL,
        amount_received INTEGER,
        change_amount INTEGER,
        customer_id TEXT REFERENCES customers(id),
        status TEXT NOT NULL,
        void_reason TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    await rawDb.customStatement('''
      INSERT INTO customers (id, name, contact_number, outstanding_balance, is_active, created_at, updated_at)
      VALUES ('cust_1', 'Legacy Customer', '09180000000', 1000, 1, 1750000000, 1750000000);

      INSERT INTO sales (id, sale_number, sale_date, total_amount, payment_type, amount_received, change_amount, customer_id, status, void_reason, created_at, updated_at)
      VALUES ('sale_cash', 'SAL-V5-001', 1750000000, 500, 'cash', 500, 0, NULL, 'completed', NULL, 1750000000, 1750000000);

      INSERT INTO sales (id, sale_number, sale_date, total_amount, payment_type, amount_received, change_amount, customer_id, status, void_reason, created_at, updated_at)
      VALUES ('sale_credit', 'SAL-V5-002', 1750000000, 1000, 'credit', NULL, NULL, 'cust_1', 'completed', NULL, 1750000000, 1750000000);
    ''');

    final migrator = rawDb.createMigrator();
    await rawDb.migration.onUpgrade(migrator, 5, 6);

    final cashSale = await rawDb.getSale('sale_cash');
    final creditSale = await rawDb.getSale('sale_credit');

    expect(cashSale!.customerNameSnapshot, isNull);
    expect(creditSale!.customerNameSnapshot, 'Legacy Customer');

    await rawDb.close();
  });
}
