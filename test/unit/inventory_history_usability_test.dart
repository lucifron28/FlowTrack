import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/features/inventory/controllers/inventory_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late InventoryListController controller;

  setUp(() {
    database = AppDatabase.inMemory();
    controller = InventoryListController();
  });

  tearDown(() async {
    await database.close();
  });

  // ─── Test 1 ───────────────────────────────────────────────────────────────
  test(
    'Archived products remain visible in Inventory but stay excluded from sales queries',
    () async {
      final activeProduct = await database.createProduct(
        name: 'Active Soda',
        barcode: 'BAR-111',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 1500,
        initialStock: 20,
        lowStockLevel: 5,
      );

      final archivedProductId = await database.createProduct(
        name: 'Archived Chips',
        barcode: 'BAR-222',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 2000,
        initialStock: 10,
        lowStockLevel: 2,
      );

      await database.updateProductActive(
        productId: archivedProductId,
        isActive: false,
      );

      // Inventory query (watchAllProducts) returns both products.
      final allProducts = await database.watchAllProducts().first;
      expect(allProducts, hasLength(2));
      expect(allProducts.map((p) => p.name), containsAll(['Active Soda', 'Archived Chips']));

      // Inventory list controller filtering checks:
      final allFiltered = controller.filterProducts(
        products: allProducts,
        lifecycleFilter: ProductLifecycleFilter.all,
      );
      expect(allFiltered, hasLength(2));

      final activeFiltered = controller.filterProducts(
        products: allProducts,
        lifecycleFilter: ProductLifecycleFilter.active,
      );
      expect(activeFiltered, hasLength(1));
      expect(activeFiltered.single.product.id, activeProduct);

      final archivedFiltered = controller.filterProducts(
        products: allProducts,
        lifecycleFilter: ProductLifecycleFilter.archived,
      );
      expect(archivedFiltered, hasLength(1));
      expect(archivedFiltered.single.product.id, archivedProductId);

      // Sales query (getActiveProducts) returns ONLY active products.
      final activeProductsForSales = await database.getActiveProducts();
      expect(activeProductsForSales, hasLength(1));
      expect(activeProductsForSales.single.id, activeProduct);
    },
  );

  // ─── Test 2 ───────────────────────────────────────────────────────────────
  test(
    'Stock-history mapping correctly handles labels, signs, ordering, and related sale number',
    () async {
      final productId = await database.createProduct(
        name: 'Test Shampoo',
        barcode: 'BAR-333',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 5000,
        initialStock: 100,
        lowStockLevel: 10,
      );

      final customerId = await database.createCustomer(name: 'Maria Clara');

      await database.addStock(
        productId: productId,
        quantity: 50,
        notes: 'Restock delivery',
      );

      final saleId = await database.completeSale(
        lines: [SaleRequestLine(productId: productId, quantity: 3)],
        paymentType: PaymentType.credit,
        saleDate: DateTime.now(),
        customerId: customerId,
      );

      final sale = await database.getSale(saleId);
      expect(sale, isNotNull);

      await database.adjustStock(
        productId: productId,
        quantity: 2,
        add: false,
        reason: 'Damaged',
        notes: 'Broken seal',
      );

      final history = await database.getStockHistoryPage(
        productId,
        limit: 50,
        offset: 0,
      );

      expect(history, hasLength(4));

      // 1st (newest): adjustment_deduct
      expect(history[0].movement.movementType, 'adjustment_deduct');
      expect(formatStockMovementLabel(history[0].movement.movementType), 'Adjustment deducted');
      expect(formatSignedQuantity(history[0].movement.movementType, history[0].movement.quantity), '-2');
      expect(history[0].movement.reason, 'Damaged');
      expect(history[0].movement.notes, 'Broken seal');
      expect(history[0].relatedSaleNumber, isNull);

      // 2nd: sale_deduction
      expect(history[1].movement.movementType, 'sale_deduction');
      expect(formatStockMovementLabel(history[1].movement.movementType), 'Sale');
      expect(formatSignedQuantity(history[1].movement.movementType, history[1].movement.quantity), '-3');
      expect(history[1].movement.relatedSaleId, saleId);
      expect(history[1].relatedSaleNumber, sale!.saleNumber);
      expect(history[1].isSaleAvailable, isTrue);

      // 3rd: restock
      expect(history[2].movement.movementType, 'restock');
      expect(formatStockMovementLabel(history[2].movement.movementType), 'Restock');
      expect(formatSignedQuantity(history[2].movement.movementType, history[2].movement.quantity), '+50');
      expect(history[2].movement.notes, 'Restock delivery');

      // 4th (oldest): initial_stock
      expect(history[3].movement.movementType, 'initial_stock');
      expect(formatStockMovementLabel(history[3].movement.movementType), 'Initial stock');
      expect(formatSignedQuantity(history[3].movement.movementType, history[3].movement.quantity), '+100');
    },
  );
}
