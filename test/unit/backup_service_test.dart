import 'dart:convert';

import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/core/services/backup_service.dart';
import 'package:flowtrack/core/services/backup_crypto_service.dart';
import 'package:flowtrack/core/services/backup_validator.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'backup_test_utils.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase source;
  late AppDatabase target;

  setUp(() {
    source = AppDatabase.inMemory();
    target = AppDatabase.inMemory();
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('creates versioned JSON backup without sync queue', () async {
    await setupBackupTestFixtures(source);

    final json = await createUnencryptedBackupJsonForTest(
      source,
      createdAt: DateTime.utc(2026, 7, 9, 1, 2, 3),
    );
    final decoded = jsonDecode(json) as Map<String, Object?>;
    final metadata = decoded['metadata'] as Map<String, Object?>;
    final data = decoded['data'] as Map<String, Object?>;

    expect(metadata['appName'], 'FlowTrack');
    expect(metadata['backupVersion'], 1);
    expect(metadata['databaseVersion'], source.schemaVersion);
    expect(metadata['createdAt'], '2026-07-09T01:02:03.000Z');
    expect(data.containsKey('syncQueue'), isFalse);
    expect(data['products'], isA<List<Object?>>());
    expect(data['sales'], isA<List<Object?>>());
    expect(data['creditPayments'], isA<List<Object?>>());
    expect(data['auditLogs'], isA<List<Object?>>());
  });

  test('restores products, sales, credits, expenses, and settings', () async {
    await setupBackupTestFixtures(source);
    await source.updateStoreName('Ron Sari-Sari Store');
    final backup = await createUnencryptedBackupJsonForTest(source);

    await target.createProduct(
      name: 'Stale Product',
      barcode: 'STALE-001',
      barcodeType: BarcodeType.storeGenerated,
      sellingPrice: 100,
      initialStock: 1,
      lowStockLevel: 1,
    );

    final targetService = BackupService(
      target,
      const BackupCryptoService(),
      const BackupValidator(),
    );
    final payload = await targetService.validateBackupString(backup);
    await targetService.restoreValidatedBackup(payload);

    final products = await target.select(target.products).get();
    final customers = await target.select(target.customers).get();
    final sales = await target.select(target.sales).get();
    final saleItems = await target.select(target.saleItems).get();
    final creditRecords = await target.select(target.creditRecords).get();
    final creditPayments = await target.select(target.creditPayments).get();
    final expenses = await target.select(target.expenses).get();
    final movements = await target.select(target.stockMovements).get();

    expect(products, hasLength(2)); // 2 explicit
    expect(products.any((product) => product.barcode == 'STALE-001'), isFalse);
    expect(customers, hasLength(1));
    expect(sales, hasLength(2));
    expect(saleItems, hasLength(2));
    expect(creditRecords, hasLength(1));
    expect(creditPayments, hasLength(1));
    expect(expenses, hasLength(1));
    expect(movements, hasLength(4)); // 2 initial + 2 sales
    expect(await target.getSetting('store_name'), 'Ron Sari-Sari Store');

    final alingNena = customers.singleWhere(
      (customer) => customer.name == 'Aling Nena',
    );
    expect(alingNena.outstandingBalance, 0); // 700 credit - 700 paid = 0

    final restoredReport = await target.reportForRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now().add(const Duration(days: 1)),
    );
    expect(restoredReport.totalSales, 3700);
    expect(restoredReport.totalExpenses, 10000);
    expect(restoredReport.totalCreditGiven, 700);
    expect(restoredReport.totalCreditCollected, 700);
  });

  test(
    'restores legacy expenses as active and preserves voided metadata',
    () async {
      await setupBackupTestFixtures(source);
      final backup = await createUnencryptedBackupJsonForTest(source);
      final decoded = jsonDecode(backup) as Map<String, dynamic>;
      final expenses =
          (decoded['data'] as Map<String, dynamic>)['expenses']
              as List<dynamic>;

      expenses.first
        ..remove('isVoided')
        ..remove('voidedAt')
        ..remove('voidReason');

      final targetService = BackupService(
        target,
        const BackupCryptoService(),
        const BackupValidator(),
      );
      final validated = await targetService.validateBackupString(
        jsonEncode(decoded),
      );
      await targetService.restoreValidatedBackup(validated);

      final restored = (await target.select(target.expenses).get()).single;
      expect(restored.isVoided, isFalse);
      expect(restored.voidedAt, isNull);
      expect(restored.voidReason, isNull);
    },
  );

  test(
    'keeps sale item snapshots when product price changes after restore',
    () async {
      final productId = await source.createProduct(
        name: 'Snapshot Noodles',
        barcode: 'SNAP-001',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 1700,
        costPrice: 1200,
        initialStock: 5,
        lowStockLevel: 2,
      );
      final product = await source.getProduct(productId);
      await source.completeSale(
        lines: [SaleRequestLine(productId: product!.id, quantity: 1)],
        paymentType: PaymentType.cash,
        saleDate: DateTime.now(),
        amountReceived: 2000,
      );

      final backup = await createUnencryptedBackupJsonForTest(source);
      final targetService = BackupService(
        target,
        const BackupCryptoService(),
        const BackupValidator(),
      );
      final payload = await targetService.validateBackupString(backup);
      await targetService.restoreValidatedBackup(payload);
      await target.editProduct(
        productId: productId,
        sellingPrice: 2500,
        costPrice: 1800,
        lowStockLevel: 2,
      );

      final sale = (await target.select(target.sales).get()).single;
      final item = (await target.getSaleItems(sale.id)).single;
      expect(item.productNameSnapshot, 'Snapshot Noodles');
      expect(item.unitPriceSnapshot, 1700);
      expect(item.costPriceSnapshot, 1200);
      expect(item.subtotal, 1700);
    },
  );

  test('rejects invalid and unsupported backup files', () async {
    final service = BackupService(
      target,
      const BackupCryptoService(),
      const BackupValidator(),
    );

    await expectLater(
      () => service.validateBackupString('[]'),
      throwsA(isA<BackupException>()),
    );
    await expectLater(
      () => service.validateBackupString(
        jsonEncode({
          'metadata': {
            'appName': 'OtherApp',
            'backupVersion': BackupService.backupVersion,
          },
          'data': <String, Object?>{},
        }),
      ),
      throwsA(isA<BackupException>()),
    );
    await expectLater(
      () => service.validateBackupString(
        jsonEncode({
          'metadata': {'appName': 'FlowTrack', 'backupVersion': 999},
          'data': <String, Object?>{},
        }),
      ),
      throwsA(isA<BackupException>()),
    );
  });
}
