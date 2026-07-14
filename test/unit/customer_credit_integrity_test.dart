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

  test('customer identity: separate by same name, reject duplicate contact', () async {
    // 1. Two customers with the same name and different contacts are created separately
    final id1 = await database.createCustomer(name: 'Ate Joy', contactNumber: '09171112233');
    final id2 = await database.createCustomer(name: 'Ate Joy', contactNumber: '09174445566');
    expect(id1, isNot(id2));

    // 2. Two customers with the same name and no contact are created separately
    final id3 = await database.createCustomer(name: 'Ate Joy', contactNumber: null);
    final id4 = await database.createCustomer(name: 'Ate Joy', contactNumber: null);
    expect(id3, isNot(id4));

    // 3. A differently formatted duplicate contact is rejected
    expect(
      () => database.createCustomer(name: 'Joy', contactNumber: '(0917) 111-2233'),
      throwsA(isA<StateError>()),
    );
  });

  test('payment reversal: soft reversal, rebuild customer balance, void credit sale', () async {
    // Create product, customer, credit sale, and payment
    final productId = await database.createProduct(
      name: 'Noodles',
      barcode: 'P-001',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 1000,
      initialStock: 10,
      lowStockLevel: 2,
    );
    final customerId = await database.createCustomer(name: 'Ate Joy');

    final saleId = await database.completeSale(
      lines: [SaleRequestLine(productId: productId, quantity: 1)],
      paymentType: PaymentType.credit,
      saleDate: DateTime.now(),
      customerId: customerId,
    );

    // Verify before payment
    var customer = await database.getCustomer(customerId);
    expect(customer!.outstandingBalance, 1000);

    // Record payment
    final paymentDate = DateTime.now();
    await database.recordCreditPayment(
      customerId: customerId,
      amount: 400,
      paymentDate: paymentDate,
    );

    // Verify after payment
    customer = await database.getCustomer(customerId);
    expect(customer!.outstandingBalance, 600);

    final creditRecords = await database.watchCreditRecords(customerId).first;
    expect(creditRecords.single.status, CreditStatus.partiallyPaid.dbValue);
    expect(creditRecords.single.paidAmount, 400);

    final payments = await database.watchCreditPayments(customerId).first;
    expect(payments.single.isReversed, isFalse);
    expect(payments.single.amount, 400);

    // Reversing the sale should fail now because there is an active payment
    expect(
      () => database.voidSale(saleId, reason: 'Void test'),
      throwsA(isA<StateError>()),
    );

    // Reverse the payment
    final paymentId = payments.single.id;
    await database.reverseCreditPayment(
      paymentId: paymentId,
      reason: 'Wrong amount entered',
    );

    // Verify after reversal
    final updatedPayments = await database.watchCreditPayments(customerId).first;
    expect(updatedPayments.single.isReversed, isTrue);
    expect(updatedPayments.single.reversalReason, 'Wrong amount entered');
    expect(updatedPayments.single.reversedAt, isNotNull);

    final updatedRecords = await database.watchCreditRecords(customerId).first;
    expect(updatedRecords.single.status, CreditStatus.unpaid.dbValue);
    expect(updatedRecords.single.paidAmount, 0);

    customer = await database.getCustomer(customerId);
    expect(customer!.outstandingBalance, 1000);

    // Verify audit log exists
    final logs = await database.select(database.auditLogs).get();
    final log = logs.firstWhere((l) => l.action == 'reverse_credit_payment');
    expect(log.entityType, 'credit_payment');
    expect(log.entityId, paymentId);
    expect(log.notes, 'Wrong amount entered');

    // Credit sale can now be voided successfully
    await database.voidSale(saleId, reason: 'Customer returned item');
    customer = await database.getCustomer(customerId);
    expect(customer!.outstandingBalance, 0);

    // Verify a second reversal attempt fails
    expect(
      () => database.reverseCreditPayment(paymentId: paymentId, reason: 'Duplicate reversal'),
      throwsA(isA<StateError>()),
    );
  });

  test('migration: upgrade database from version 3 to 4', () async {
    // 1. Setup version 3 schema by dropping and creating credit_payments table without columns
    await database.customStatement('PRAGMA foreign_keys = OFF;');
    await database.customStatement('DROP TABLE IF EXISTS credit_payments;');
    await database.customStatement('''
      CREATE TABLE credit_payments (
        id TEXT NOT NULL PRIMARY KEY,
        customer_id TEXT NOT NULL REFERENCES customers (id),
        amount INTEGER NOT NULL,
        payment_date INTEGER NOT NULL,
        notes TEXT,
        created_at INTEGER NOT NULL
      );
    ''');
    await database.customStatement('PRAGMA foreign_keys = ON;');

    // 2. Insert rows into version 3 database
    await database.customStatement('''
      INSERT INTO customers (id, name, outstanding_balance, is_active, created_at, updated_at)
      VALUES ('cust-1', 'Ate Joy', 1000, 1, 1715000000000, 1715000000000);
    ''');
    await database.customStatement('''
      INSERT INTO credit_payments (id, customer_id, amount, payment_date, created_at)
      VALUES ('pay-1', 'cust-1', 400, 1715000000000, 1715000000000);
    ''');

    // 3. Run migration from 3 to 4
    final migrator = database.createMigrator();
    await database.migration.onUpgrade(migrator, 3, 4);

    // 4. Verify version 4 columns exist and default properly
    final payments = await database.select(database.creditPayments).get();
    expect(payments, hasLength(1));
    expect(payments.single.id, 'pay-1');
    expect(payments.single.amount, 400);
    expect(payments.single.isReversed, isFalse);
    expect(payments.single.reversedAt, isNull);
    expect(payments.single.reversalReason, isNull);

    // 5. Verify database schema version is 4
    expect(database.schemaVersion, 4);
  });
}
