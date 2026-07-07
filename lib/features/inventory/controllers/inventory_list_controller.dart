import '../../../core/database/app_database.dart';
import '../../../core/domain/flowtrack_models.dart';

class InventoryListItem {
  const InventoryListItem({required this.product, required this.status});

  final Product product;
  final ProductStatus status;
}

class InventoryListController {
  List<InventoryListItem> filterProducts({
    required Iterable<Product> products,
    String query = '',
    ProductStatus? statusFilter,
  }) {
    final normalizedQuery = query.trim().toLowerCase();

    return products
        .map(
          (product) => InventoryListItem(
            product: product,
            status: calculateProductStatus(
              stock: product.stock,
              lowStockLevel: product.lowStockLevel,
            ),
          ),
        )
        .where((item) {
          final product = item.product;
          final matchesQuery =
              normalizedQuery.isEmpty ||
              product.name.toLowerCase().contains(normalizedQuery) ||
              product.barcode.toLowerCase().contains(normalizedQuery);
          final matchesStatus =
              statusFilter == null || item.status == statusFilter;

          return matchesQuery && matchesStatus;
        })
        .toList();
  }
}
