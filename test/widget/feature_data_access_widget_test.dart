import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/features/inventory/data/inventory_repository.dart';
import 'package:flowtrack/features/inventory/screens/inventory_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeInventoryRepository implements InventoryRepository {
  final List<Product> _products = [
    Product(
      id: 'fake-prod-1',
      name: 'Fake Repository Item',
      barcode: 'BAR-FAKE-123',
      barcodeType: BarcodeType.manufacturer.dbValue,
      sellingPrice: 1500,
      stock: 25,
      lowStockLevel: 5,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Stream<List<Product>> watchAllProducts() => Stream.value(_products);

  @override
  Stream<Product?> watchProduct(String productId) {
    return Stream.value(_products.firstWhere((p) => p.id == productId));
  }

  @override
  Future<Product?> getProduct(String productId) async {
    return _products.firstWhere((p) => p.id == productId);
  }

  @override
  Future<Product?> findProductByBarcode(String barcode) async {
    return _products.firstWhere((p) => p.barcode == barcode);
  }

  @override
  Future<String> createProduct({
    required String name,
    required String barcode,
    required BarcodeType barcodeType,
    required int sellingPrice,
    int? costPrice,
    required int initialStock,
    required int lowStockLevel,
  }) async {
    return 'fake-prod-id';
  }

  @override
  Future<void> editProduct({
    required String productId,
    required int sellingPrice,
    int? costPrice,
    required int lowStockLevel,
  }) async {}

  @override
  Future<void> updateProductActive({
    required String productId,
    required bool isActive,
  }) async {}

  @override
  Future<void> addStock({
    required String productId,
    required int quantity,
    String? notes,
  }) async {}

  @override
  Future<void> adjustStock({
    required String productId,
    required int quantity,
    required bool add,
    required String reason,
    String? notes,
  }) async {}

  @override
  Stream<List<StockHistoryEntry>> watchStockHistoryPreview(
    String productId, {
    int limit = 5,
  }) =>
      Stream.value([]);

  @override
  Future<List<StockHistoryEntry>> getStockHistoryPage(
    String productId, {
    required int limit,
    required int offset,
  }) async =>
      [];
}

void main() {
  testWidgets(
    'InventoryScreen renders cleanly when overriding inventoryRepositoryProvider with a fake (no AppDatabase required)',
    (WidgetTester tester) async {
      final fakeRepo = FakeInventoryRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: InventoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Fake Repository Item'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
