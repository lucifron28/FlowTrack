import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/features/sales/controllers/sales_cart_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SalesCartController', () {
    test('adds products with sale item snapshots and totals', () {
      final controller = SalesCartController();
      final product = _product(
        id: 'p-1',
        name: 'Lucky Me Pancit Canton',
        barcode: '4800361417406',
        sellingPrice: 1700,
        costPrice: 1200,
        stock: 3,
      );

      final result = controller.addProduct(product);

      expect(result, SalesCartResult.added);
      expect(controller.itemCount, 1);
      expect(controller.total, 1700);
      expect(controller.items.single.productId, product.id);
      expect(controller.items.single.productName, product.name);
      expect(controller.items.single.barcode, product.barcode);
      expect(controller.items.single.unitPrice, product.sellingPrice);
      expect(controller.items.single.costPrice, product.costPrice);
    });

    test('increments existing product without creating a duplicate line', () {
      final controller = SalesCartController();
      final product = _product(id: 'p-1', stock: 3);

      controller.addProduct(product);
      final result = controller.addProduct(product);

      expect(result, SalesCartResult.updated);
      expect(controller.items, hasLength(1));
      expect(controller.items.single.quantity, 2);
      expect(controller.itemCount, 2);
    });

    test('blocks adding products beyond available stock', () {
      final controller = SalesCartController();
      final product = _product(id: 'p-1', stock: 1);

      controller.addProduct(product);
      final result = controller.addProduct(product);

      expect(result, SalesCartResult.insufficientStock);
      expect(controller.items.single.quantity, 1);
    });

    test('changes quantity, removes zero quantity, and clears cart', () {
      final controller = SalesCartController();
      final product = _product(id: 'p-1', stock: 5);

      controller.addProduct(product);
      expect(
        controller.changeQuantity(
          productId: product.id,
          delta: 2,
          availableStock: product.stock,
        ),
        SalesCartResult.updated,
      );
      expect(controller.items.single.quantity, 3);

      expect(
        controller.changeQuantity(
          productId: product.id,
          delta: -3,
          availableStock: product.stock,
        ),
        SalesCartResult.removed,
      );
      expect(controller.isEmpty, isTrue);

      controller.addProduct(product);
      controller.clear();
      expect(controller.isEmpty, isTrue);
    });

    test('blocks quantity changes beyond available stock', () {
      final controller = SalesCartController();
      final product = _product(id: 'p-1', stock: 2);

      controller.addProduct(product);
      final result = controller.changeQuantity(
        productId: product.id,
        delta: 2,
        availableStock: product.stock,
      );

      expect(result, SalesCartResult.insufficientStock);
      expect(controller.items.single.quantity, 1);
    });

    test('reports missing when changing an unknown line', () {
      final controller = SalesCartController();

      final result = controller.changeQuantity(productId: 'missing', delta: 1);

      expect(result, SalesCartResult.missing);
    });
  });
}

Product _product({
  required String id,
  String name = 'Test Product',
  String barcode = '1234567890',
  int sellingPrice = 1000,
  int? costPrice,
  required int stock,
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    name: name,
    barcode: barcode,
    barcodeType: BarcodeType.manufacturer.dbValue,
    sellingPrice: sellingPrice,
    costPrice: costPrice,
    stock: stock,
    lowStockLevel: 1,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}
