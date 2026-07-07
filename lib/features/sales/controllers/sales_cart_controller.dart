import '../../../core/database/app_database.dart';
import '../../../core/domain/flowtrack_models.dart';

enum SalesCartResult {
  added,
  updated,
  removed,
  missing,
  insufficientStock;

  bool get succeeded => switch (this) {
    SalesCartResult.added ||
    SalesCartResult.updated ||
    SalesCartResult.removed => true,
    SalesCartResult.missing || SalesCartResult.insufficientStock => false,
  };
}

class SalesCartController {
  final List<SaleCartLine> _items = [];

  List<SaleCartLine> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  int get total => calculateSaleTotal(_items);

  int get itemCount => _items.fold<int>(0, (sum, item) => sum + item.quantity);

  void clear() => _items.clear();

  SalesCartResult addProduct(Product product) {
    final existingIndex = _items.indexWhere(
      (item) => item.productId == product.id,
    );
    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      if (existing.quantity + 1 > product.stock) {
        return SalesCartResult.insufficientStock;
      }
      _items[existingIndex] = existing.copyWith(
        quantity: existing.quantity + 1,
      );
      return SalesCartResult.updated;
    }

    if (product.stock <= 0) {
      return SalesCartResult.insufficientStock;
    }
    _items.add(
      SaleCartLine(
        productId: product.id,
        productName: product.name,
        barcode: product.barcode,
        unitPrice: product.sellingPrice,
        costPrice: product.costPrice,
        quantity: 1,
      ),
    );
    return SalesCartResult.added;
  }

  SalesCartResult changeQuantity({
    required String productId,
    required int delta,
    int? availableStock,
  }) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index < 0) {
      return SalesCartResult.missing;
    }

    final current = _items[index];
    final nextQuantity = current.quantity + delta;
    if (nextQuantity <= 0) {
      _items.removeAt(index);
      return SalesCartResult.removed;
    }
    if (availableStock != null && nextQuantity > availableStock) {
      return SalesCartResult.insufficientStock;
    }
    _items[index] = current.copyWith(quantity: nextQuantity);
    return SalesCartResult.updated;
  }
}
