import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/features/inventory/screens/inventory_screen.dart';
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

  testWidgets('Product name can be edited and saved', (tester) async {
    final productId = await database.createProduct(
      name: 'Original Product',
      barcode: 'NAME-001',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 1000,
      initialStock: 4,
      lowStockLevel: 2,
    );
    final product = (await database.getProduct(productId))!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: EditProductScreen(product: product)),
      ),
    );

    final nameField = find.byType(TextFormField).first;
    expect(
      tester.widget<TextFormField>(nameField).controller!.text,
      'Original Product',
    );

    await tester.enterText(nameField, '   ');
    await tester.tap(find.text('Save Changes'));
    await tester.pump();

    expect(find.text('Product name is required.'), findsOneWidget);
    expect((await database.getProduct(productId))!.name, 'Original Product');

    await tester.enterText(nameField, '  Updated Product  ');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect((await database.getProduct(productId))!.name, 'Updated Product');
    expect(tester.takeException(), isNull);
  });
}
