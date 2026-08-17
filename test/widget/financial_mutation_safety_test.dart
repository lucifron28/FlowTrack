import 'dart:async';

import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/features/credits/data/credits_repository.dart';
import 'package:flowtrack/features/credits/screens/credits_screen.dart';
import 'package:flowtrack/features/expenses/data/expenses_repository.dart';
import 'package:flowtrack/features/expenses/screens/expenses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class BlockingCreditsRepository extends DriftCreditsRepository {
  BlockingCreditsRepository(super.db);

  final gate = Completer<void>();
  var recordCalls = 0;

  @override
  Future<void> recordCreditPayment({
    required String customerId,
    required int amount,
    required DateTime paymentDate,
    String? notes,
  }) async {
    recordCalls++;
    await gate.future;
    await super.recordCreditPayment(
      customerId: customerId,
      amount: amount,
      paymentDate: paymentDate,
      notes: notes,
    );
  }
}

class BlockingExpensesRepository extends DriftExpensesRepository {
  BlockingExpensesRepository(super.db);

  final gate = Completer<void>();
  var createCalls = 0;

  @override
  Future<void> createExpense({
    required String category,
    String? description,
    required int amount,
    required DateTime expenseDate,
  }) async {
    createCalls++;
    await gate.future;
    await super.createExpense(
      category: category,
      description: description,
      amount: amount,
      expenseDate: expenseDate,
    );
  }
}

class RetryingCreditsRepository implements CreditsRepository {
  var shouldFail = true;
  var watchCalls = 0;

  @override
  Stream<List<Customer>> watchCustomers() {
    watchCalls++;
    return shouldFail
        ? Stream<List<Customer>>.error(StateError('database unavailable'))
        : Stream.value(const <Customer>[]);
  }

  @override
  Stream<Customer?> watchCustomer(String customerId) => Stream.value(null);

  @override
  Stream<List<CreditRecordListEntry>> watchCreditRecordsWithSale(
    String customerId,
  ) => Stream.value(const <CreditRecordListEntry>[]);

  @override
  Stream<List<CreditPayment>> watchCreditPayments(String customerId) =>
      Stream.value(const <CreditPayment>[]);

  @override
  Future<String> createCustomer({
    required String name,
    String? contactNumber,
  }) => Future.value('customer-id');

  @override
  Future<void> updateCustomer({
    required String customerId,
    required String name,
    String? contactNumber,
  }) async {}

  @override
  Future<void> deleteCustomer(String customerId) async {}

  @override
  Future<void> recordCreditPayment({
    required String customerId,
    required int amount,
    required DateTime paymentDate,
    String? notes,
  }) async {}

  @override
  Future<void> reverseCreditPayment({
    required String paymentId,
    required String reason,
  }) async {}
}

Future<String> _createCreditForCustomer(AppDatabase db) async {
  final productId = await db.createProduct(
    name: 'Noodles',
    barcode: '4807770271137',
    barcodeType: BarcodeType.manufacturer,
    sellingPrice: 1500,
    initialStock: 10,
    lowStockLevel: 2,
  );
  final customerId = await db.createCustomer(name: 'Aling Nena');
  await db.completeSale(
    lines: [SaleRequestLine(productId: productId, quantity: 1)],
    paymentType: PaymentType.credit,
    saleDate: DateTime.now(),
    customerId: customerId,
  );
  return customerId;
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.inMemory();
  });

  tearDown(() => db.close());

  testWidgets('credits load failure exposes a retry action', (tester) async {
    final repository = RetryingCreditsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [creditsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: CreditsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Could not load data'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    repository.shouldFail = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('No customers yet'), findsOneWidget);
    expect(repository.watchCalls, 2);
  });

  testWidgets('repeated payment taps submit once', (tester) async {
    final customerId = await _createCreditForCustomer(db);
    final customer = await (db.select(
      db.customers,
    )..where((table) => table.id.equals(customerId))).getSingle();
    final repository = BlockingCreditsRepository(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [creditsRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(home: RecordPaymentScreen(customer: customer)),
      ),
    );
    await tester.enterText(find.byType(TextField).first, '1.00');

    final saveButton = find.byType(FilledButton);
    await tester.tap(saveButton);
    await tester.pump();
    expect(repository.recordCalls, 1);
    expect(find.text('Saving…'), findsOneWidget);

    await tester.tap(saveButton);
    await tester.pump();
    expect(repository.recordCalls, 1);

    repository.gate.complete();
    await tester.pumpAndSettle();

    expect(await db.select(db.creditPayments).get(), hasLength(1));
  });

  testWidgets('repeated expense taps submit once', (tester) async {
    final repository = BlockingExpensesRepository(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expensesRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AddExpenseScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField).at(1), '1.00');

    final saveButton = find.byType(FilledButton);
    await tester.tap(saveButton);
    await tester.pump();
    expect(repository.createCalls, 1);
    expect(find.text('Saving…'), findsOneWidget);

    await tester.tap(saveButton);
    await tester.pump();
    expect(repository.createCalls, 1);

    repository.gate.complete();
    await tester.pumpAndSettle();

    expect(await db.select(db.expenses).get(), hasLength(1));
  });
}
