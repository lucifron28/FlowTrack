import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/features/credits/screens/credits_screen.dart';
import 'package:flowtrack/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets(
    'credit record links to sale details and CustomerDetailsScreen layout does not overflow at 2.0 text scale on 320x640',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final p1 = await database.createProduct(
        name: 'Super Noodle Package Extra Long Name',
        barcode: 'P-999',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 2500,
        initialStock: 50,
        lowStockLevel: 10,
      );
      final c1 = await database.createCustomer(
        name: 'Aling Nena Super Long Name Customer',
        contactNumber: '09171112233',
      );
      final saleId = await database.completeSale(
        lines: [SaleRequestLine(productId: p1, quantity: 2)],
        paymentType: PaymentType.credit,
        saleDate: DateTime.now(),
        customerId: c1,
      );

      final sale = await database.getSale(saleId);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
          ],
          child: MaterialApp(
            home: CustomerDetailsScreen(customerId: c1),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Aling Nena'), findsOneWidget);
      expect(find.textContaining(sale!.saleNumber), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
