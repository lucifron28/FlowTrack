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

  Future<Product> createProduct({
    int stock = 5,
    int price = 1000,
    String barcode = 'P-001',
  }) async {
    final id = await database.createProduct(
      name: 'Test Product $barcode',
      barcode: barcode,
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: price,
      initialStock: stock,
      lowStockLevel: 20,
    );
    return (await database.getProduct(id))!;
  }

  test('stock is deducted only after sale completion', () async {
    final product = await createProduct(stock: 5, price: 1000);
    final draft = [
      SaleCartLine(
        productId: product.id,
        productName: product.name,
        barcode: product.barcode,
        unitPrice: product.sellingPrice,
        quantity: 2,
      ),
    ];

    expect((await database.getProduct(product.id))!.stock, 5);

    await database.completeSale(
      items: draft,
      paymentType: PaymentType.cash,
      saleDate: DateTime(2026, 5, 4),
      amountReceived: 2000,
    );

    expect((await database.getProduct(product.id))!.stock, 3);
  });

  test(
    'cash sale stores amount received, change, and price snapshots',
    () async {
      final product = await createProduct(
        stock: 5,
        price: 1000,
        barcode: 'P-010',
      );
      final saleId = await database.completeSale(
        items: [
          SaleCartLine(
            productId: product.id,
            productName: product.name,
            barcode: product.barcode,
            unitPrice: product.sellingPrice,
            costPrice: product.costPrice,
            quantity: 2,
          ),
        ],
        paymentType: PaymentType.cash,
        saleDate: DateTime(2026, 5, 4),
        amountReceived: 2500,
      );

      await database.editProduct(
        productId: product.id,
        sellingPrice: 1500,
        lowStockLevel: product.lowStockLevel,
      );

      final sale = await database.getSale(saleId);
      final item = (await database.getSaleItems(saleId)).single;
      expect(sale!.amountReceived, 2500);
      expect(sale.changeAmount, 500);
      expect(item.unitPriceSnapshot, 1000);
      expect(item.subtotal, 2000);
    },
  );

  test(
    'credit sale increases balance and payment decreases it oldest-first',
    () async {
      final product = await createProduct(
        stock: 5,
        price: 1000,
        barcode: 'P-002',
      );
      await database.completeSale(
        items: [
          SaleCartLine(
            productId: product.id,
            productName: product.name,
            barcode: product.barcode,
            unitPrice: product.sellingPrice,
            quantity: 1,
          ),
        ],
        paymentType: PaymentType.credit,
        saleDate: DateTime(2026, 5, 4),
        customerName: 'Aling Nena',
      );

      final customer = (await database.getActiveCustomers()).single;
      expect(customer.outstandingBalance, 1000);

      await database.recordCreditPayment(
        customerId: customer.id,
        amount: 400,
        paymentDate: DateTime(2026, 5, 4),
      );

      final updated = await database.getCustomer(customer.id);
      expect(updated!.outstandingBalance, 600);
      final records = await database.watchCreditRecords(customer.id).first;
      expect(records.single.status, CreditStatus.partiallyPaid.dbValue);
      expect(records.single.paidAmount, 400);
    },
  );

  test(
    'credit payment allocates oldest-first across multiple records',
    () async {
      final product = await createProduct(
        stock: 5,
        price: 1000,
        barcode: 'P-011',
      );
      await database.completeSale(
        items: [
          SaleCartLine(
            productId: product.id,
            productName: product.name,
            barcode: product.barcode,
            unitPrice: product.sellingPrice,
            quantity: 1,
          ),
        ],
        paymentType: PaymentType.credit,
        saleDate: DateTime(2026, 5, 1),
        customerName: 'Mang Lito',
      );
      await database.completeSale(
        items: [
          SaleCartLine(
            productId: product.id,
            productName: product.name,
            barcode: product.barcode,
            unitPrice: product.sellingPrice,
            quantity: 2,
          ),
        ],
        paymentType: PaymentType.credit,
        saleDate: DateTime(2026, 5, 2),
        customerName: 'Mang Lito',
      );

      final customer = (await database.getActiveCustomers()).single;
      await database.recordCreditPayment(
        customerId: customer.id,
        amount: 1500,
        paymentDate: DateTime(2026, 5, 3),
      );

      final records = [...await database.watchCreditRecords(customer.id).first]
        ..sort((left, right) => left.creditDate.compareTo(right.creditDate));
      expect(records.first.status, CreditStatus.paid.dbValue);
      expect(records.first.paidAmount, 1000);
      expect(records.last.status, CreditStatus.partiallyPaid.dbValue);
      expect(records.last.paidAmount, 500);
      expect(
        (await database.getCustomer(customer.id))!.outstandingBalance,
        1500,
      );
    },
  );

  test(
    'voided credit sale restores inventory and reverses customer balance',
    () async {
      final product = await createProduct(
        stock: 5,
        price: 1000,
        barcode: 'P-012',
      );
      final saleId = await database.completeSale(
        items: [
          SaleCartLine(
            productId: product.id,
            productName: product.name,
            barcode: product.barcode,
            unitPrice: product.sellingPrice,
            quantity: 2,
          ),
        ],
        paymentType: PaymentType.credit,
        saleDate: DateTime(2026, 5, 4),
        customerName: 'Aling Rosa',
      );

      final customer = (await database.getActiveCustomers()).single;
      expect(customer.outstandingBalance, 2000);
      expect((await database.getProduct(product.id))!.stock, 3);

      await database.voidSale(saleId, reason: 'Wrong item');

      expect((await database.getProduct(product.id))!.stock, 5);
      expect((await database.getCustomer(customer.id))!.outstandingBalance, 0);
      final record =
          (await database.watchCreditRecords(customer.id).first).single;
      expect(record.status, CreditStatus.voided.dbValue);
    },
  );

  test('expense affects net income and reports ignore voided sales', () async {
    final product = await createProduct(
      stock: 5,
      price: 1000,
      barcode: 'P-003',
    );
    final saleId = await database.completeSale(
      items: [
        SaleCartLine(
          productId: product.id,
          productName: product.name,
          barcode: product.barcode,
          unitPrice: product.sellingPrice,
          quantity: 1,
        ),
      ],
      paymentType: PaymentType.cash,
      saleDate: DateTime(2026, 5, 4, 10),
      amountReceived: 1000,
    );
    await database.createExpense(
      category: 'Utilities',
      amount: 300,
      expenseDate: DateTime(2026, 5, 4, 12),
    );

    var report = await database.reportForRange(
      start: DateTime(2026, 5, 4),
      end: DateTime(2026, 5, 5),
    );
    expect(report.totalSales, 1000);
    expect(report.totalExpenses, 300);
    expect(report.netIncome, 700);

    await database.voidSale(saleId, reason: 'Test void');

    report = await database.reportForRange(
      start: DateTime(2026, 5, 4),
      end: DateTime(2026, 5, 5),
    );
    expect(report.totalSales, 0);
    expect(report.totalExpenses, 300);
    expect((await database.getProduct(product.id))!.stock, 5);
  });

  test('product can be deactivated and filtered from active list', () async {
    final product = await createProduct(barcode: 'P-100');
    expect(product.isActive, isTrue);

    var activeList = await database.getActiveProducts();
    expect(activeList.map((e) => e.id), contains(product.id));

    await database.updateProductActive(productId: product.id, isActive: false);

    final updated = (await database.getProduct(product.id))!;
    expect(updated.isActive, isFalse);

    activeList = await database.getActiveProducts();
    expect(activeList.map((e) => e.id), isNot(contains(product.id)));

    await database.updateProductActive(productId: product.id, isActive: true);

    activeList = await database.getActiveProducts();
    expect(activeList.map((e) => e.id), contains(product.id));
  });

  test('customer CRUD operations work with constraint checks', () async {
    final customerId = await database.createCustomer(
      name: 'John Doe',
      contactNumber: '12345',
    );
    var customer = (await database.getCustomer(customerId))!;
    expect(customer.name, 'John Doe');
    expect(customer.contactNumber, '12345');

    // Update details
    await database.updateCustomer(
      customerId: customerId,
      name: 'John Smith',
      contactNumber: '67890',
    );
    customer = (await database.getCustomer(customerId))!;
    expect(customer.name, 'John Smith');
    expect(customer.contactNumber, '67890');

    // Safe delete when no history and no balance
    await database.deleteCustomer(customerId);
    expect(await database.getCustomer(customerId), isNull);

    // Re-create and test constraints
    final cId = await database.createCustomer(name: 'Jane Doe');
    
    // 1. Balance constraint
    final prod = await createProduct(stock: 5, price: 1000, barcode: 'P-101');
    await database.completeSale(
      items: [
        SaleCartLine(
          productId: prod.id,
          productName: prod.name,
          barcode: prod.barcode,
          unitPrice: prod.sellingPrice,
          quantity: 1,
        ),
      ],
      paymentType: PaymentType.credit,
      saleDate: DateTime.now(),
      customerId: cId,
    );
    // Outstanding balance is now 1000. Deleting should throw.
    expect(
      () => database.deleteCustomer(cId),
      throwsA(isA<StateError>()),
    );

    // Record a payment to bring balance to 0, but transaction history still exists
    await database.recordCreditPayment(
      customerId: cId,
      amount: 1000,
      paymentDate: DateTime.now(),
    );
    final Jane = (await database.getCustomer(cId))!;
    expect(Jane.outstandingBalance, 0);

    // Deleting should still throw because of credit history
    expect(
      () => database.deleteCustomer(cId),
      throwsA(isA<StateError>()),
    );
  });

  test('expense CRUD operations work', () async {
    // Create
    await database.createExpense(
      category: 'Utilities',
      description: 'Water bill',
      amount: 500,
      expenseDate: DateTime(2026, 5, 4),
    );
    var list = await database.watchExpenses().first;
    expect(list.length, 1);
    var exp = list.first;
    expect(exp.category, 'Utilities');
    expect(exp.description, 'Water bill');
    expect(exp.amount, 500);

    // Update
    await database.updateExpense(
      expenseId: exp.id,
      category: 'Rent',
      description: 'Office rent',
      amount: 1500,
      expenseDate: DateTime(2026, 5, 5),
    );

    final updated = (await database.getExpense(exp.id))!;
    expect(updated.category, 'Rent');
    expect(updated.description, 'Office rent');
    expect(updated.amount, 1500);

    // Delete
    await database.deleteExpense(exp.id);
    expect(await database.getExpense(exp.id), isNull);
    list = await database.watchExpenses().first;
    expect(list, isEmpty);
  });
}
