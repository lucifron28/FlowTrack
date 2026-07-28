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

  testWidgets(
    'credit record tap navigates to Sale Details screen via GoRouter and renders without overflow under 2.0 text scale',
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
          GoRoute(
            path: '/sales',
            builder: (context, state) => const SalesScreen(),
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

      await tester.pumpAndSettle();

      expect(find.textContaining('Aling Nena'), findsOneWidget);
      expect(find.textContaining(sale!.saleNumber), findsOneWidget);

      await tester.tap(find.textContaining(sale.saleNumber));
      await tester.pumpAndSettle();

      expect(find.text('Sale Details'), findsOneWidget);
      expect(find.text(sale.saleNumber), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.textContaining('Jul 28, 2026'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Aling Nena Super Long Name Customer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sales list and Sale Details render without overflow under 2.0 text scale on 360x800',
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
      final c1 = await database.createCustomer(
        name: 'Mang Juan',
      );
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
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sales'), findsOneWidget);
      expect(find.text('Mang Juan'), findsOneWidget);

      await tester.tap(find.text('Mang Juan'));
      await tester.pumpAndSettle();

      expect(find.text('Sale Details'), findsOneWidget);
      expect(find.text('Mang Juan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
