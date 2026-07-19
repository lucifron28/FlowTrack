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
    int? costPrice,
    int lowStockLevel = 20,
    String barcode = 'P-001',
  }) async {
    final id = await database.createProduct(
      name: 'Test Product $barcode',
      barcode: barcode,
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: price,
      costPrice: costPrice,
      initialStock: stock,
      lowStockLevel: lowStockLevel,
    );
    return (await database.getProduct(id))!;
  }

  test('stock is deducted only after sale completion', () async {
    final product = await createProduct(stock: 5, price: 1000);
    final draft = [SaleRequestLine(productId: product.id, quantity: 2)];

    expect((await database.getProduct(product.id))!.stock, 5);

    await database.completeSale(
      lines: draft,
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
        lines: [SaleRequestLine(productId: product.id, quantity: 2)],
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
        lines: [SaleRequestLine(productId: product.id, quantity: 1)],
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
        lines: [SaleRequestLine(productId: product.id, quantity: 1)],
        paymentType: PaymentType.credit,
        saleDate: DateTime(2026, 5, 1),
        customerName: 'Mang Lito',
      );
      final customer = (await database.getActiveCustomers()).single;
      await database.completeSale(
        lines: [SaleRequestLine(productId: product.id, quantity: 2)],
        paymentType: PaymentType.credit,
        saleDate: DateTime(2026, 5, 2),
        customerId: customer.id,
      );
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
        lines: [SaleRequestLine(productId: product.id, quantity: 2)],
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

  test(
    'reports calculate profit from cost snapshots and exclude voided sales',
    () async {
      final product = await createProduct(
        stock: 5,
        price: 1000,
        costPrice: 400,
        barcode: 'P-003',
      );
      final saleId = await database.completeSale(
        lines: [SaleRequestLine(productId: product.id, quantity: 1)],
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
      expect(report.costOfGoodsSold, 400);
      expect(report.grossProfit, 600);
      expect(report.totalExpenses, 300);
      expect(report.netIncome, 300);
      expect(report.missingCostItemCount, 0);

      await database.voidSale(saleId, reason: 'Test void');

      report = await database.reportForRange(
        start: DateTime(2026, 5, 4),
        end: DateTime(2026, 5, 5),
      );
      expect(report.totalSales, 0);
      expect(report.costOfGoodsSold, 0);
      expect(report.grossProfit, 0);
      expect(report.totalExpenses, 300);
      expect(report.netIncome, -300);
      expect((await database.getProduct(product.id))!.stock, 5);
    },
  );

  test('reports flag sales with missing immutable cost snapshots', () async {
    final product = await createProduct(
      stock: 2,
      price: 1000,
      barcode: 'P-004',
    );
    await database.completeSale(
      lines: [SaleRequestLine(productId: product.id, quantity: 1)],
      paymentType: PaymentType.cash,
      saleDate: DateTime(2026, 5, 4, 10),
      amountReceived: 1000,
    );
    await database.editProduct(
      productId: product.id,
      sellingPrice: 1000,
      costPrice: 900,
      lowStockLevel: product.lowStockLevel,
    );

    final report = await database.reportForRange(
      start: DateTime(2026, 5, 4),
      end: DateTime(2026, 5, 5),
    );
    expect(report.costOfGoodsSold, 0);
    expect(report.grossProfit, 1000);
    expect(report.netIncome, 1000);
    expect(report.missingCostItemCount, 1);
    expect(report.hasIncompleteCostData, isTrue);
  });

  test('reports exclude reversed credit payments from collections', () async {
    final product = await createProduct(
      stock: 2,
      price: 1000,
      costPrice: 600,
      barcode: 'P-005',
    );
    await database.completeSale(
      lines: [SaleRequestLine(productId: product.id, quantity: 1)],
      paymentType: PaymentType.credit,
      saleDate: DateTime(2026, 5, 4, 10),
      customerName: 'Aling Tess',
    );
    final customer = (await database.getActiveCustomers()).single;
    await database.recordCreditPayment(
      customerId: customer.id,
      amount: 1000,
      paymentDate: DateTime(2026, 5, 4, 11),
    );
    final payment =
        (await database.select(database.creditPayments).get()).single;
    await database.reverseCreditPayment(
      paymentId: payment.id,
      reason: 'Entry error',
    );

    final report = await database.reportForRange(
      start: DateTime(2026, 5, 4),
      end: DateTime(2026, 5, 5),
    );
    expect(report.totalCreditGiven, 1000);
    expect(report.totalCreditCollected, 0);
  });

  test(
    'dashboard aligns stock alerts and excludes voided recent sales',
    () async {
      await createProduct(stock: 0, lowStockLevel: 4, barcode: 'P-006');
      await createProduct(stock: 2, lowStockLevel: 4, barcode: 'P-007');
      final normalStock = await createProduct(
        stock: 10,
        lowStockLevel: 4,
        barcode: 'P-008',
      );

      final completedSaleId = await database.completeSale(
        lines: [SaleRequestLine(productId: normalStock.id, quantity: 1)],
        paymentType: PaymentType.cash,
        saleDate: DateTime(2026, 5, 4, 10),
        amountReceived: 1000,
      );
      await database.voidSale(completedSaleId, reason: 'Test void');

      final dashboard = await database.dashboardSummary(DateTime(2026, 5, 4));
      final alerts = await database.lowStockProducts();
      final recent = await database.recentSales();
      expect(dashboard.stockAlertItemsCount, 2);
      expect(alerts.first.stock, 0);
      expect(alerts.map((product) => product.stock), orderedEquals([0, 2]));
      expect(recent, isEmpty);
    },
  );

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
      lines: [SaleRequestLine(productId: prod.id, quantity: 1)],
      paymentType: PaymentType.credit,
      saleDate: DateTime.now(),
      customerId: cId,
    );
    // Outstanding balance is now 1000. Deleting should throw.
    expect(() => database.deleteCustomer(cId), throwsA(isA<StateError>()));

    // Record a payment to bring balance to 0, but transaction history still exists
    await database.recordCreditPayment(
      customerId: cId,
      amount: 1000,
      paymentDate: DateTime.now(),
    );
    final jane = (await database.getCustomer(cId))!;
    expect(jane.outstandingBalance, 0);

    // Deleting should still throw because of credit history
    expect(() => database.deleteCustomer(cId), throwsA(isA<StateError>()));
  });

  test(
    'expense edits are audited and voiding preserves financial history',
    () async {
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

      await database.voidExpense(expenseId: exp.id, reason: 'Entered twice');
      final voided = (await database.getExpense(exp.id))!;
      expect(voided.isVoided, isTrue);
      expect(voided.voidReason, 'Entered twice');
      expect(voided.voidedAt, isNotNull);
      list = await database.watchExpenses().first;
      expect(list.single.isVoided, isTrue);

      final auditEntries = await database.select(database.auditLogs).get();
      expect(
        auditEntries.map((entry) => entry.action),
        contains('update_expense'),
      );
      expect(
        auditEntries.map((entry) => entry.action),
        contains('void_expense'),
      );
      expect(
        () => database.updateExpense(
          expenseId: exp.id,
          category: 'Rent',
          amount: 1500,
          expenseDate: DateTime(2026, 5, 5),
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('voiding credit sale fails if partial payments exist', () async {
    final product = await createProduct(
      stock: 5,
      price: 1000,
      barcode: 'P-999',
    );
    final saleId = await database.completeSale(
      lines: [SaleRequestLine(productId: product.id, quantity: 2)],
      paymentType: PaymentType.credit,
      saleDate: DateTime(2026, 5, 4),
      customerName: 'Aling Nena',
    );

    final customer = (await database.getActiveCustomers()).firstWhere(
      (c) => c.name == 'Aling Nena',
    );

    // Record a payment of 500 centavos against the credit
    await database.recordCreditPayment(
      customerId: customer.id,
      amount: 500,
      paymentDate: DateTime.now(),
    );

    // Attempting to void the sale should throw StateError
    expect(
      () => database.voidSale(saleId, reason: 'Test void fail'),
      throwsA(isA<StateError>()),
    );
  });
}
