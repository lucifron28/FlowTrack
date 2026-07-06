import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/services/sample_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SampleDataService service;

  setUp(() {
    database = AppDatabase.inMemory();
    service = SampleDataService(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('loads sari-sari QA data once with scan-ready products', () async {
    expect(await service.isLoaded(), isFalse);

    await service.load();

    expect(await service.isLoaded(), isTrue);
    expect(
      (await database.getActiveProducts()).length,
      greaterThanOrEqualTo(12),
    );
    expect(await database.findProductByBarcode('4807770271137'), isNotNull);
    expect(await database.findProductByBarcode('FT-TINGI-ASUKAL'), isNotNull);
    expect(
      (await database.getActiveCustomers()).length,
      greaterThanOrEqualTo(3),
    );
    expect(await database.recentSales(), isNotEmpty);
    expect(await database.watchExpenses().first, isNotEmpty);

    expect(service.load(), throwsA(isA<StateError>()));
  });

  test('sync demo data is idempotent after initial load', () async {
    await service.syncDemoData();
    final firstProductCount = (await database.getActiveProducts()).length;
    final firstCustomerCount = (await database.getActiveCustomers()).length;
    final firstSaleCount = (await database.watchSales().first).length;
    final firstExpenseCount = (await database.watchExpenses().first).length;

    await service.syncDemoData();

    expect((await database.getActiveProducts()).length, firstProductCount);
    expect((await database.getActiveCustomers()).length, firstCustomerCount);
    expect((await database.watchSales().first).length, firstSaleCount);
    expect((await database.watchExpenses().first).length, firstExpenseCount);
  });

  test(
    'reset demo data clears business records and reloads clean data',
    () async {
      await service.syncDemoData();
      final firstProductCount = (await database.getActiveProducts()).length;

      final product = await database.findProductByBarcode('4807770271137');
      await database.addStock(productId: product!.id, quantity: 99);

      await service.resetDemoData();

      final resetProduct = await database.findProductByBarcode('4807770271137');
      expect(await service.isLoaded(), isTrue);
      expect((await database.getActiveProducts()).length, firstProductCount);
      expect(resetProduct, isNotNull);
      expect(resetProduct!.stock, 33);
    },
  );
}
