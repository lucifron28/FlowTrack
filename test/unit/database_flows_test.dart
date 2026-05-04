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
}
