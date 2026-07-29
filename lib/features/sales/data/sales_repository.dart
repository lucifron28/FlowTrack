import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/database/database_provider.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class SalesRepository {
  Stream<List<SaleListEntry>> watchSalesWithCustomer();
  Future<SaleListEntry?> getSaleWithCustomer(String saleId);
  Future<List<SaleItem>> getSaleItems(String saleId);
  Future<List<Product>> getActiveProducts();
  Future<Product?> getProduct(String productId);
  Future<Product?> findProductByBarcode(String barcode);
  Future<List<Customer>> getActiveCustomers();
  Future<String> completeSale({
    required List<SaleRequestLine> lines,
    required PaymentType paymentType,
    required DateTime saleDate,
    int? amountReceived,
    String? customerId,
    String? customerName,
    String? contactNumber,
  });
  Future<void> voidSale(String saleId, {String? reason});
}

class DriftSalesRepository implements SalesRepository {
  DriftSalesRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<SaleListEntry>> watchSalesWithCustomer() {
    return _db.watchSalesWithCustomer();
  }

  @override
  Future<SaleListEntry?> getSaleWithCustomer(String saleId) {
    return _db.getSaleWithCustomer(saleId);
  }

  @override
  Future<List<SaleItem>> getSaleItems(String saleId) {
    return _db.getSaleItems(saleId);
  }

  @override
  Future<List<Product>> getActiveProducts() => _db.getActiveProducts();

  @override
  Future<Product?> getProduct(String productId) => _db.getProduct(productId);

  @override
  Future<Product?> findProductByBarcode(String barcode) {
    return _db.findProductByBarcode(barcode);
  }

  @override
  Future<List<Customer>> getActiveCustomers() => _db.getActiveCustomers();

  @override
  Future<String> completeSale({
    required List<SaleRequestLine> lines,
    required PaymentType paymentType,
    required DateTime saleDate,
    int? amountReceived,
    String? customerId,
    String? customerName,
    String? contactNumber,
  }) {
    return _db.completeSale(
      lines: lines,
      paymentType: paymentType,
      saleDate: saleDate,
      amountReceived: amountReceived,
      customerId: customerId,
      customerName: customerName,
      contactNumber: contactNumber,
    );
  }

  @override
  Future<void> voidSale(String saleId, {String? reason}) {
    return _db.voidSale(saleId, reason: reason);
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftSalesRepository(db);
});
