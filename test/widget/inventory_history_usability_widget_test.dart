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
    'Repeated Adjust Stock submissions create one movement',
    (WidgetTester tester) async {
      final productId = await database.createProduct(
        name: 'Test Product',
        barcode: 'BAR-001',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 1000,
        initialStock: 10,
        lowStockLevel: 2,
      );
      final product = (await database.getProduct(productId))!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            home: AdjustStockScreen(product: product),
          ),
        ),
      );

      // Select Deduct segment
      await tester.tap(find.text('Deduct').first);
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.pump();

      // Tap "Save Adjustment" twice rapidly before pumping
      await tester.tap(find.text('Save Adjustment'));
      await tester.tap(find.text('Save Adjustment'), warnIfMissed: false);
      await tester.pump();

      // Verify only one confirmation dialog appeared
      expect(find.text('Confirm deduction'), findsOneWidget);

      // Confirm once
      await tester.tap(find.text('Deduct').last);
      await tester.pump();

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      final movements = await database.getStockHistoryPage(
        productId,
        limit: 50,
        offset: 0,
      );
      // Initial stock movement + exactly 1 deduction adjustment = 2 total
      expect(movements, hasLength(2));
      expect(movements.first.movement.movementType, 'adjustment_deduct');
      expect(movements.first.movement.quantity, 5);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'Inventory and Product Details render at 320x640, 200% text without overflow',
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
        name: 'Super Extra Long Product Name That Wraps Multiple Lines',
        barcode: 'BAR-444555666777',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 12500,
        initialStock: 50,
        lowStockLevel: 5,
      );

      await database.updateProductActive(
        productId: productId,
        isActive: false,
      );

      // 1. Check InventoryScreen rendering
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: InventoryScreen()),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Lifecycle'), findsOneWidget);
      expect(find.text('Stock status'), findsOneWidget);
      expect(find.text('Archived'), findsWidgets);
      expect(tester.takeException(), isNull);

      // 2. Check ProductDetailsScreen rendering
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            home: ProductDetailsScreen(productId: productId),
          ),
        ),
      );
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Product Details'), findsOneWidget);

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      await tester.dragUntilVisible(
        find.text('Stock History'),
        find.byType(ListView),
        const Offset(0, -100),
      );
      await tester.pump();

      expect(find.text('Stock History'), findsOneWidget);
      expect(find.text('View full history'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

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
