import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flowtrack/core/config/app_config.dart';
import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';

Future<void> setupBackupTestFixtures(AppDatabase db) async {
  final p1 = await db.createProduct(
    name: 'Noodles',
    barcode: '4807770271137',
    barcodeType: BarcodeType.manufacturer,
    sellingPrice: 1500,
    costPrice: 1200,
    initialStock: 100,
    lowStockLevel: 20,
  );
  final p2 = await db.createProduct(
    name: 'Coffee',
    barcode: '4804888801232',
    barcodeType: BarcodeType.manufacturer,
    sellingPrice: 700,
    costPrice: 500,
    initialStock: 200,
    lowStockLevel: 50,
  );

  final c1 = await db.createCustomer(
    name: 'Aling Nena',
    contactNumber: '0917 111 2233',
  );

  // Add delays between completeSale to guarantee unique sale numbers
  await db.completeSale(
    lines: [SaleRequestLine(productId: p1, quantity: 2)],
    paymentType: PaymentType.cash,
    saleDate: DateTime.now(),
    amountReceived: 3000,
  );
  await Future.delayed(const Duration(milliseconds: 10));

  await db.completeSale(
    lines: [SaleRequestLine(productId: p2, quantity: 1)],
    paymentType: PaymentType.credit,
    saleDate: DateTime.now().subtract(const Duration(days: 1)),
    customerId: c1,
  );
  await Future.delayed(const Duration(milliseconds: 10));

  await db.recordCreditPayment(
    customerId: c1,
    amount: 700,
    paymentDate: DateTime.now(),
    notes: 'Partial payment',
  );

  await db.createExpense(
    category: 'Restocking',
    description: 'Restock inventory',
    amount: 10000,
    expenseDate: DateTime.now(),
  );

  await db.setSetting('store_name', 'Default Store');
}

Future<String> createUnencryptedBackupJsonForTest(
  AppDatabase db, {
  DateTime? createdAt,
  int backupVersion = 1,
}) async {
  final created = createdAt ?? DateTime.now();
  final backup = {
    'metadata': {
      'appName': AppConfig.appName,
      'appVersion': AppConfig.appVersion,
      'backupVersion': backupVersion,
      'databaseVersion': db.schemaVersion,
      'createdAt': created.toUtc().toIso8601String(),
    },
    'data': {
      'products': (await db.select(db.products).get())
          .map((e) => e.toJson(serializer: const ValueSerializer.defaults()))
          .toList(),
      'stockMovements': (await db.select(db.stockMovements).get())
          .map((e) => e.toJson(serializer: const ValueSerializer.defaults()))
          .toList(),
      'sales': (await db.select(db.sales).get())
          .map((e) => e.toJson(serializer: const ValueSerializer.defaults()))
          .toList(),
      'saleItems': (await db.select(db.saleItems).get())
          .map((e) => e.toJson(serializer: const ValueSerializer.defaults()))
          .toList(),
      'customers': (await db.select(db.customers).get())
          .map((e) => e.toJson(serializer: const ValueSerializer.defaults()))
          .toList(),
      'creditRecords': (await db.select(db.creditRecords).get())
          .map((e) => e.toJson(serializer: const ValueSerializer.defaults()))
          .toList(),
      'creditPayments': (await db.select(db.creditPayments).get())
          .map((e) => e.toJson(serializer: const ValueSerializer.defaults()))
          .toList(),
      'expenses': (await db.select(db.expenses).get())
          .map((e) => e.toJson(serializer: const ValueSerializer.defaults()))
          .toList(),
      'settings': (await db.select(db.settings).get())
          .map((e) => e.toJson(serializer: const ValueSerializer.defaults()))
          .toList(),
      'appMetadata': (await db.select(db.appMetadata).get())
          .map((e) => e.toJson(serializer: const ValueSerializer.defaults()))
          .toList(),
      'auditLogs': (await db.select(db.auditLogs).get())
          .map((e) => e.toJson(serializer: const ValueSerializer.defaults()))
          .toList(),
    },
  };
  return const JsonEncoder.withIndent('  ').convert(backup);
}
