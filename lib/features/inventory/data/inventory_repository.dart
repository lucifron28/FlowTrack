import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/database/database_provider.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class InventoryRepository {
  Stream<List<Product>> watchAllProducts();
  Stream<Product?> watchProduct(String productId);
  Future<Product?> getProduct(String productId);
  Future<Product?> findProductByBarcode(String barcode);
  Future<String> createProduct({
    required String name,
    required String barcode,
    required BarcodeType barcodeType,
    required int sellingPrice,
    int? costPrice,
    required int initialStock,
    required int lowStockLevel,
  });
  Future<void> editProduct({
    required String productId,
    required int sellingPrice,
    int? costPrice,
    required int lowStockLevel,
  });
  Future<void> updateProductActive({
    required String productId,
    required bool isActive,
  });
  Future<void> addStock({
    required String productId,
    required int quantity,
    String? notes,
  });
  Future<void> adjustStock({
    required String productId,
    required int quantity,
    required bool add,
    required String reason,
    String? notes,
  });
  Stream<List<StockHistoryEntry>> watchStockHistoryPreview(
    String productId, {
    int limit = 5,
  });
  Future<List<StockHistoryEntry>> getStockHistoryPage(
    String productId, {
    required int limit,
    required int offset,
  });
}

class DriftInventoryRepository implements InventoryRepository {
  DriftInventoryRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Product>> watchAllProducts() => _db.watchAllProducts();

  @override
  Stream<Product?> watchProduct(String productId) =>
      _db.watchProduct(productId);

  @override
  Future<Product?> getProduct(String productId) => _db.getProduct(productId);

  @override
  Future<Product?> findProductByBarcode(String barcode) {
    return _db.findProductByBarcode(barcode);
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
  }) {
    return _db.createProduct(
      name: name,
      barcode: barcode,
      barcodeType: barcodeType,
      sellingPrice: sellingPrice,
      costPrice: costPrice,
      initialStock: initialStock,
      lowStockLevel: lowStockLevel,
    );
  }

  @override
  Future<void> editProduct({
    required String productId,
    required int sellingPrice,
    int? costPrice,
    required int lowStockLevel,
  }) {
    return _db.editProduct(
      productId: productId,
      sellingPrice: sellingPrice,
      costPrice: costPrice,
      lowStockLevel: lowStockLevel,
    );
  }

  @override
  Future<void> updateProductActive({
    required String productId,
    required bool isActive,
  }) {
    return _db.updateProductActive(productId: productId, isActive: isActive);
  }

  @override
  Future<void> addStock({
    required String productId,
    required int quantity,
    String? notes,
  }) {
    return _db.addStock(productId: productId, quantity: quantity, notes: notes);
  }

  @override
  Future<void> adjustStock({
    required String productId,
    required int quantity,
    required bool add,
    required String reason,
    String? notes,
  }) {
    return _db.adjustStock(
      productId: productId,
      quantity: quantity,
      add: add,
      reason: reason,
      notes: notes,
    );
  }

  @override
  Stream<List<StockHistoryEntry>> watchStockHistoryPreview(
    String productId, {
    int limit = 5,
  }) {
    return _db.watchStockHistoryPreview(productId, limit: limit);
  }

  @override
  Future<List<StockHistoryEntry>> getStockHistoryPage(
    String productId, {
    required int limit,
    required int offset,
  }) {
    return _db.getStockHistoryPage(productId, limit: limit, offset: offset);
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftInventoryRepository(db);
});
