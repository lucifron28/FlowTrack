import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/features/inventory/controllers/inventory_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryListController', () {
    final controller = InventoryListController();
    final products = [
      _product(
        id: 'p-1',
        name: 'Lucky Me Pancit Canton Chilimansi',
        barcode: '4807770271137',
        stock: 20,
        lowStockLevel: 5,
      ),
      _product(
        id: 'p-2',
        name: 'Tingi Sugar 1/4 kilo',
        barcode: 'FT-1700000000-SUGAR',
        stock: 2,
        lowStockLevel: 5,
      ),
      _product(
        id: 'p-3',
        name: 'Argentina Corned Beef',
        barcode: '748485100001',
        stock: 0,
        lowStockLevel: 4,
      ),
    ];

    test('returns products with computed statuses', () {
      final result = controller.filterProducts(products: products);

      expect(result.map((item) => item.product.id), ['p-1', 'p-2', 'p-3']);
      expect(result.map((item) => item.status), [
        ProductStatus.normal,
        ProductStatus.lowStock,
        ProductStatus.outOfStock,
      ]);
    });

    test('filters by product name case-insensitively', () {
      final result = controller.filterProducts(
        products: products,
        query: '  PANCIT  ',
      );

      expect(result.map((item) => item.product.id), ['p-1']);
    });

    test('filters by barcode text', () {
      final result = controller.filterProducts(
        products: products,
        query: 'sugar',
      );

      expect(result.map((item) => item.product.id), ['p-2']);
    });

    test('filters by status', () {
      final result = controller.filterProducts(
        products: products,
        statusFilter: ProductStatus.outOfStock,
      );

      expect(result.map((item) => item.product.id), ['p-3']);
    });

    test('combines query and status filters', () {
      final result = controller.filterProducts(
        products: products,
        query: 'tingi',
        statusFilter: ProductStatus.lowStock,
      );

      expect(result.map((item) => item.product.id), ['p-2']);
    });

    test('returns empty list when query and status do not both match', () {
      final result = controller.filterProducts(
        products: products,
        query: 'corned',
        statusFilter: ProductStatus.normal,
      );

      expect(result, isEmpty);
    });
  });
}

Product _product({
  required String id,
  required String name,
  required String barcode,
  required int stock,
  required int lowStockLevel,
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    name: name,
    barcode: barcode,
    barcodeType: BarcodeType.manufacturer.dbValue,
    sellingPrice: 1000,
    costPrice: 800,
    stock: stock,
    lowStockLevel: lowStockLevel,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}
