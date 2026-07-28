import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class SalesRepository {
  Stream<List<Sale>> watchSales();
  Future<Sale?> getSale(String saleId);
  Future<List<Product>> getActiveProducts();
  Future<Product?> getProduct(String productId);
  Future<Product?> findProductByBarcode(String barcode);
  Future<String> createCustomer({
    required String name,
    String? phone,
    String? address,
  });
  Future<String> completeSale({
    required List<SaleRequestLine> lines,
    required PaymentType paymentType,
    required DateTime saleDate,
    String? customerId,
    int? amountPaid,
  });
  Future<void> voidSale(String saleId, {required String reason});
}

class DriftSalesRepository implements SalesRepository {
  DriftSalesRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Sale>> watchSales() => _db.watchSales();

  @override
  Future<Sale?> getSale(String saleId) => _db.getSale(saleId);

  @override
  Future<List<Product>> getActiveProducts() => _db.getActiveProducts();

  @override
  Future<Product?> getProduct(String productId) => _db.getProduct(productId);

  @override
  Future<Product?> findProductByBarcode(String barcode) {
    return _db.findProductByBarcode(barcode);
  }

  @override
  Future<String> createCustomer({
    required String name,
    String? phone,
    String? address,
  }) {
    return _db.createCustomer(
      name: name,
      phone: phone,
      address: address,
    );
  }

  @override
  Future<String> completeSale({
    required List<SaleRequestLine> lines,
    required PaymentType paymentType,
    required DateTime saleDate,
    String? customerId,
    int? amountPaid,
  }) {
    return _db.completeSale(
      lines: lines,
      paymentType: paymentType,
      saleDate: saleDate,
      customerId: customerId,
      amountPaid: amountPaid,
    );
  }

  @override
  Future<void> voidSale(String saleId, {required String reason}) {
    return _db.voidSale(saleId, reason: reason);
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftSalesRepository(db);
});
