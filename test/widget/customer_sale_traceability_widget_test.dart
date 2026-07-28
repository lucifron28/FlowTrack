import 'package:flowtrack/core/constants/app_routes.dart';
import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/features/credits/screens/credits_screen.dart';
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

  // ─── Test 1 ───────────────────────────────────────────────────────────────
  // Mounts SaleDetailsScreen (FutureBuilder only, no Drift streams) to verify
  // no layout overflow at 2.0× text scale on 320×640.
  // Customer name correctness is verified by unit tests in
  // test/unit/customer_sale_traceability_test.dart.
  testWidgets(
    'SaleDetailsScreen renders sale header without overflow under 2.0 text scale on 320×640',
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
        saleDate: DateTime(2026, 7, 28, 14, 30),
        customerId: c1,
      );

      // GoRouter needed for context.pushNamed inside the Customer card onTap.
      final router = GoRouter(
        initialLocation: '/sales/$saleId',
        routes: [
          GoRoute(
            path: '/sales/:saleId',
            name: AppRoutes.saleDetailsName,
            builder: (context, state) => SaleDetailsScreen(
              saleId: state.pathParameters['saleId']!,
            ),
          ),
          GoRoute(
            path: '/credits/:customerId',
            name: AppRoutes.customerDetailsName,
            builder: (context, state) => CustomerDetailsScreen(
              customerId: state.pathParameters['customerId']!,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      // First pump: widget builds with ConnectionState.waiting.
      await tester.pump();

      // runAsync lets the real SQLite Future complete in wall-clock time.
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });

      // Second pump: FutureBuilder.builder fires with completed snapshot.
      await tester.pump();

      expect(find.text('Sale Details'), findsOneWidget);
      // 'Date' row is in the header card — visible even on 320px.
      expect(find.text('Date'), findsOneWidget);

      // No layout overflow exception during rendering.
      expect(tester.takeException(), isNull);

      // Unmount widget tree so Drift streams unsubscribe before tearDown.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ─── Test 2 ───────────────────────────────────────────────────────────────
  // Full GoRouter navigation: SalesScreen → tap sale tile → SaleDetailsScreen.
  // 360×800 gives enough space for the sale tile to be visible without scroll.
  testWidgets(
    'Sales list shows customer name and tapping navigates to Sale Details without overflow under 2.0 text scale on 360×800',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final p1 = await database.createProduct(
        name: 'Coffee Mix',
        barcode: 'P-888',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 1200,
        initialStock: 30,
        lowStockLevel: 5,
      );
      final c1 = await database.createCustomer(name: 'Mang Juan');
      await database.completeSale(
        lines: [SaleRequestLine(productId: p1, quantity: 1)],
        paymentType: PaymentType.credit,
        saleDate: DateTime(2026, 7, 28, 10, 0),
        customerId: c1,
      );

      final router = GoRouter(
        initialLocation: '/sales',
        routes: [
          GoRoute(
            path: '/sales',
            builder: (context, state) => const SalesScreen(),
          ),
          GoRoute(
            path: '/sales/:saleId',
            name: AppRoutes.saleDetailsName,
            builder: (context, state) => SaleDetailsScreen(
              saleId: state.pathParameters['saleId']!,
            ),
          ),
          GoRoute(
            path: '/credits/:customerId',
            name: AppRoutes.customerDetailsName,
            builder: (context, state) => CustomerDetailsScreen(
              customerId: state.pathParameters['customerId']!,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      // Allow the Drift stream to emit the first sale list result.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sales'), findsOneWidget);
      // Sale tile subtitle shows customer name on credit sales.
      expect(find.text('Mang Juan'), findsWidgets);

      // Tap the first occurrence of the customer name (the sale tile subtitle).
      await tester.tap(find.text('Mang Juan').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // SaleDetailsScreen is now on top.
      expect(find.text('Sale Details'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Unmount widget tree so Drift streams unsubscribe before tearDown.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ─── Test 3 ───────────────────────────────────────────────────────────────
  // GoRouter navigation: Customer Details → tap linked credit record →
  // SaleDetailsScreen. 320×640 at 2.0× text scale, verifying no overflow.
  testWidgets(
    'Customer Details credit record navigates to Sale Details without overflow under 2.0 text scale on 320×640',
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
        name: 'Rice 1kg',
        barcode: 'P-777',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 5500,
        initialStock: 20,
        lowStockLevel: 5,
      );
      final c1 = await database.createCustomer(
        name: 'Aling Rosa',
        contactNumber: '09281234567',
      );
      final saleId = await database.completeSale(
        lines: [SaleRequestLine(productId: p1, quantity: 1)],
        paymentType: PaymentType.credit,
        saleDate: DateTime(2026, 7, 28, 9, 0),
        customerId: c1,
      );
      final sale = await database.getSale(saleId);

      final router = GoRouter(
        initialLocation: '/credits/$c1',
        routes: [
          GoRoute(
            path: '/credits/:customerId',
            name: AppRoutes.customerDetailsName,
            builder: (context, state) => CustomerDetailsScreen(
              customerId: state.pathParameters['customerId']!,
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
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      // Allow Drift streams to emit (outer customer + inner credit records).
      await tester.pump();
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      // Customer Details is on screen with the customer name.
      expect(find.text('Aling Rosa'), findsOneWidget);
      expect(find.text('Credit Records'), findsOneWidget);
      expect(sale!.saleNumber, isNotEmpty);

      // At 320×640 with 2.0× text scale the credit records are below the
      // viewport. Scroll down so the lazy ListView builds them.
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      // The credit record subtitle includes the sale number.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.data?.contains(sale!.saleNumber) == true,
        ),
        findsOneWidget,
      );

      // Tap the credit record row.
      await tester.tap(
        find.ancestor(
          of: find.textContaining(sale.saleNumber),
          matching: find.byType(ListTile),
        ),
      );
      // Allow the SaleDetailsScreen FutureBuilder to settle.
      await tester.pump();
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      // Sale Details is now on top with the sale number visible.
      expect(find.text('Sale Details'), findsOneWidget);
      expect(find.text(sale.saleNumber), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Unmount widget tree so Drift streams unsubscribe before tearDown.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
