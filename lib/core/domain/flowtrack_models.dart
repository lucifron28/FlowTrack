enum BarcodeType {
  manufacturer('manufacturer'),
  storeGenerated('store_generated');

  const BarcodeType(this.dbValue);
  final String dbValue;
}

enum ProductStatus {
  normal,
  lowStock,
  outOfStock;

  String get label => switch (this) {
    ProductStatus.normal => 'Normal',
    ProductStatus.lowStock => 'Low Stock',
    ProductStatus.outOfStock => 'Out of Stock',
  };
}

enum StockMovementType {
  initialStock('initial_stock'),
  restock('restock'),
  saleDeduction('sale_deduction'),
  voidRestore('void_restore'),
  adjustmentAdd('adjustment_add'),
  adjustmentDeduct('adjustment_deduct');

  const StockMovementType(this.dbValue);
  final String dbValue;
}

enum PaymentType {
  cash('cash'),
  credit('credit');

  const PaymentType(this.dbValue);
  final String dbValue;
}

enum SaleStatus {
  completed('completed'),
  voided('voided');

  const SaleStatus(this.dbValue);
  final String dbValue;
}

enum CreditStatus {
  unpaid('unpaid'),
  partiallyPaid('partially_paid'),
  paid('paid'),
  voided('voided');

  const CreditStatus(this.dbValue);
  final String dbValue;
}

class SaleCartLine {
  const SaleCartLine({
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.unitPrice,
    required this.quantity,
    this.costPrice,
  });

  final String productId;
  final String productName;
  final String barcode;
  final int unitPrice;
  final int? costPrice;
  final int quantity;

  int get subtotal => unitPrice * quantity;

  SaleCartLine copyWith({int? quantity}) {
    return SaleCartLine(
      productId: productId,
      productName: productName,
      barcode: barcode,
      unitPrice: unitPrice,
      costPrice: costPrice,
      quantity: quantity ?? this.quantity,
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalSalesToday,
    required this.totalExpensesToday,
    required this.netIncomeToday,
    required this.totalOutstandingCredit,
    required this.lowStockItemsCount,
  });

  final int totalSalesToday;
  final int totalExpensesToday;
  final int netIncomeToday;
  final int totalOutstandingCredit;
  final int lowStockItemsCount;
}

class ReportSummary {
  const ReportSummary({
    required this.totalSales,
    required this.totalExpenses,
    required this.netIncome,
    required this.totalCreditGiven,
    required this.totalCreditCollected,
  });

  final int totalSales;
  final int totalExpenses;
  final int netIncome;
  final int totalCreditGiven;
  final int totalCreditCollected;
}

ProductStatus calculateProductStatus({
  required int stock,
  required int lowStockLevel,
}) {
  if (stock <= 0) {
    return ProductStatus.outOfStock;
  }
  if (stock <= lowStockLevel * 0.25) {
    return ProductStatus.lowStock;
  }
  return ProductStatus.normal;
}

int calculateSaleTotal(Iterable<SaleCartLine> items) {
  return items.fold<int>(0, (total, item) => total + item.subtotal);
}

int calculateCashChange({required int amountReceived, required int total}) {
  return amountReceived - total;
}

DateTime startOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime endOfDay(DateTime value) {
  return startOfDay(value).add(const Duration(days: 1));
}
