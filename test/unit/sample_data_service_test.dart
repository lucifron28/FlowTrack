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
}
