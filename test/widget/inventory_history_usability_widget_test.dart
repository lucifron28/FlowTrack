import 'package:flowtrack/core/constants/app_routes.dart';
import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/features/inventory/screens/inventory_screen.dart';
import 'package:flowtrack/features/sales/screens/sales_screen.dart';
import 'package:flowtrack/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets(
    'At 320x640 and 200% text, tapping a sale-linked stock movement opens the correct Sale Details screen without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final productId = await database.createProduct(
        name: 'Super Long Product Name For Usability Testing',
        barcode: 'BAR-999',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 3500,
        initialStock: 100,
        lowStockLevel: 10,
      );

      final customerId = await database.createCustomer(
        name: 'Juan Dela Cruz Super Long Name',
      );

      final saleId = await database.completeSale(
        lines: [SaleRequestLine(productId: productId, quantity: 5)],
        paymentType: PaymentType.credit,
        saleDate: DateTime(2026, 7, 28, 14, 0),
        customerId: customerId,
      );

      final sale = await database.getSale(saleId);
      expect(sale, isNotNull);

      final router = GoRouter(
        initialLocation: '/inventory/$productId/history',
        routes: [
          GoRoute(
            path: '/inventory/:productId/history',
            name: AppRoutes.stockHistoryName,
            builder: (context, state) => StockHistoryScreen(
              productId: state.pathParameters['productId']!,
            ),
          ),
          GoRoute(
            path: '/sales/:saleId',
            name: AppRoutes.saleDetailsName,
            builder: (context, state) => SaleDetailsScreen(
              saleId: state.pathParameters['saleId']!,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      // Initial pump for StockHistoryScreen build.
      await tester.pump();

      // runAsync lets SQLite getStockHistoryPage future complete.
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await tester.pump();

      // Verify Stock History rendered sale link.
      final saleLinkFinder = find.textContaining('Sale #');
      expect(saleLinkFinder, findsOneWidget);

      // Tap sale link to navigate to SaleDetailsScreen.
      await tester.tap(saleLinkFinder);
      await tester.pump();

      // Allow SaleDetailsScreen FutureBuilder to resolve.
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await tester.pump();

      // Verify navigation reached SaleDetailsScreen without layout overflow.
      expect(find.text('Sale Details'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Unmount widget tree before tearDown database close.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
