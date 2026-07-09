import 'dart:convert';

import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/core/services/backup_service.dart';
import 'package:flowtrack/core/services/sample_data_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await SampleDataService(source).syncDemoData();

    final json = await BackupService(
      source,
    ).createBackupJson(createdAt: DateTime.utc(2026, 7, 9, 1, 2, 3));
    final decoded = jsonDecode(json) as Map<String, Object?>;
    final metadata = decoded['metadata'] as Map<String, Object?>;
    final data = decoded['data'] as Map<String, Object?>;

    expect(metadata['appName'], 'FlowTrack');
    expect(metadata['backupVersion'], BackupService.backupVersion);
    expect(metadata['databaseVersion'], source.schemaVersion);
    expect(metadata['createdAt'], '2026-07-09T01:02:03.000Z');
    expect(data.containsKey('syncQueue'), isFalse);
    expect(data['products'], isA<List<Object?>>());
    expect(data['sales'], isA<List<Object?>>());
    expect(data['creditPayments'], isA<List<Object?>>());
    expect(data['auditLogs'], isA<List<Object?>>());
  });

  test('restores products, sales, credits, expenses, and settings', () async {
    await SampleDataService(source).syncDemoData();
    await source.updateStoreName('Ron Sari-Sari Store');
    final backup = await BackupService(source).createBackupJson();

    await target.createProduct(
      name: 'Stale Product',
      barcode: 'STALE-001',
      barcodeType: BarcodeType.storeGenerated,
      sellingPrice: 100,
      initialStock: 1,
      lowStockLevel: 1,
    );

    await BackupService(target).restoreFromJsonString(backup);

    final products = await target.select(target.products).get();
    final customers = await target.select(target.customers).get();
    final sales = await target.select(target.sales).get();
    final saleItems = await target.select(target.saleItems).get();
    final creditRecords = await target.select(target.creditRecords).get();
    final creditPayments = await target.select(target.creditPayments).get();
    final expenses = await target.select(target.expenses).get();
    final movements = await target.select(target.stockMovements).get();

    expect(products, hasLength(12));
    expect(products.any((product) => product.barcode == 'STALE-001'), isFalse);
    expect(customers, hasLength(3));
    expect(sales, hasLength(3));
    expect(saleItems, hasLength(9));
    expect(creditRecords, hasLength(2));
    expect(creditPayments, hasLength(1));
    expect(expenses, hasLength(3));
    expect(movements, hasLength(20));
    expect(await target.getSetting('store_name'), 'Ron Sari-Sari Store');

    final alingNena = customers.singleWhere(
      (customer) => customer.name == 'Aling Nena',
    );
    expect(alingNena.outstandingBalance, 8500);

    final restoredReport = await target.reportForRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now().add(const Duration(days: 1)),
    );
    expect(restoredReport.totalSales, 26000);
    expect(restoredReport.totalExpenses, 238000);
    expect(restoredReport.totalCreditGiven, 19000);
    expect(restoredReport.totalCreditCollected, 5000);
  });

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
        items: [
          SaleCartLine(
            productId: product!.id,
            productName: product.name,
            barcode: product.barcode,
            unitPrice: product.sellingPrice,
            costPrice: product.costPrice,
            quantity: 1,
          ),
        ],
        paymentType: PaymentType.cash,
        saleDate: DateTime.now(),
        amountReceived: 2000,
      );

      final backup = await BackupService(source).createBackupJson();
      await BackupService(target).restoreFromJsonString(backup);
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
    final service = BackupService(target);

    await expectLater(
      () => service.restoreFromJsonString('[]'),
      throwsA(isA<BackupException>()),
    );
    await expectLater(
      () => service.restoreFromJsonString(
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
      () => service.restoreFromJsonString(
        jsonEncode({
          'metadata': {'appName': 'FlowTrack', 'backupVersion': 999},
          'data': <String, Object?>{},
        }),
      ),
      throwsA(isA<BackupException>()),
    );
  });
}
