import '../../../core/database/app_database.dart';
import '../../../core/domain/flowtrack_models.dart';
import '../../../core/utils/barcode_utils.dart';

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
          
          var matchesBarcodeQuery = false;
          if (normalizedQuery.isNotEmpty) {
            try {
              final norm = normalizeBarcode(normalizedQuery);
              matchesBarcodeQuery = product.barcode.toLowerCase().contains(norm.toLowerCase());
            } catch (_) {}
          }

          final matchesQuery =
              normalizedQuery.isEmpty ||
              product.name.toLowerCase().contains(normalizedQuery) ||
              product.barcode.toLowerCase().contains(normalizedQuery) ||
              matchesBarcodeQuery;
          final matchesStatus =
              statusFilter == null || item.status == statusFilter;

          return matchesQuery && matchesStatus;
        })
        .toList();
  }
}
