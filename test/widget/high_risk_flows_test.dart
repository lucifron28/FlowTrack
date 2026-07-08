import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/features/inventory/screens/inventory_screen.dart';
import 'package:flowtrack/features/sales/screens/sales_screen.dart';
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

  testWidgets('new sale flow calculates change and deducts stock on complete', (
    tester,
  ) async {
    await database.createProduct(
      name: 'Lucky Test Noodles',
      barcode: '4807770271137',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 1700,
      costPrice: 1200,
      initialStock: 3,
      lowStockLevel: 1,
    );

    await _pumpWithDatabase(tester, database, const NewSaleScreen());

    await tester.tap(find.text('Search Product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lucky Test Noodles'));
    await tester.pumpAndSettle();

    expect(find.text('Lucky Test Noodles'), findsOneWidget);
    expect((await database.findProductByBarcode('4807770271137'))!.stock, 3);

    await tester.enterText(_textFieldByLabel('Amount received'), '20.00');
    await tester.pumpAndSettle();

    expect(find.text('₱3.00'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete Sale'));
    await tester.pumpAndSettle();

    final product = await database.findProductByBarcode('4807770271137');
    final sales = await database.recentSales();

    expect(product!.stock, 2);
    expect(sales, hasLength(1));
    expect(sales.single.totalAmount, 1700);
    expect(sales.single.amountReceived, 2000);
    expect(sales.single.changeAmount, 300);
  });

  testWidgets('add stock screen updates inventory quantity', (tester) async {
    final productId = await database.createProduct(
      name: 'Piattos Test Cheese',
      barcode: '4800016060218',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 1800,
      costPrice: 1400,
      initialStock: 2,
      lowStockLevel: 5,
    );

    await _pumpWithDatabase(
      tester,
      database,
      AddStockScreen(productId: productId),
    );

    await tester.enterText(_textFieldByLabel('Quantity'), '5');
    await tester.tap(find.text('Save Stock'));
    await tester.pumpAndSettle();

    final product = await database.getProduct(productId);
    expect(product!.stock, 7);
  });
}

Future<void> _pumpWithDatabase(
  WidgetTester tester,
  AppDatabase database,
  Widget child,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _textFieldByLabel(String label) {
  return find.byWidgetPredicate((widget) {
    return widget is TextField && widget.decoration?.labelText == label;
  });
}
