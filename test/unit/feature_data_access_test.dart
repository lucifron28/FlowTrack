import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/features/inventory/data/inventory_repository.dart';
import 'package:flowtrack/features/sales/data/sales_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SalesRepository salesRepository;
  late InventoryRepository inventoryRepository;

  setUp(() {
    db = AppDatabase.inMemory();
    salesRepository = DriftSalesRepository(db);
    inventoryRepository = DriftInventoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'complete a sale through SalesRepository and verify stock and sale data remain correct',
    () async {
      final productId = await inventoryRepository.createProduct(
        name: 'Integration Rice 5kg',
        barcode: 'INT-RICE-001',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 25000,
        initialStock: 10,
        lowStockLevel: 2,
      );

      final saleDate = DateTime(2026, 7, 28, 10, 0);
      final saleId = await salesRepository.completeSale(
        lines: [SaleRequestLine(productId: productId, quantity: 3)],
        paymentType: PaymentType.cash,
        saleDate: saleDate,
        amountReceived: 100000,
      );

      final entry = await salesRepository.getSaleWithCustomer(saleId);
      expect(entry, isNotNull);
      final sale = entry!.sale;
      expect(sale.totalAmount, 75000);
      expect(sale.paymentType, PaymentType.cash.dbValue);

      final updatedProduct = await inventoryRepository.getProduct(productId);
      expect(updatedProduct, isNotNull);
      expect(updatedProduct!.stock, 7);
    },
  );
}
