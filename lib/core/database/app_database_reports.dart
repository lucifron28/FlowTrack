part of 'app_database.dart';

extension AppDatabaseReports on AppDatabase {
  Future<DashboardSummary> dashboardSummary(DateTime day) async {
    final start = startOfDay(day);
    final end = endOfDay(day);
    final report = await reportForRange(start: start, end: end);
    final activeProducts = await getActiveProducts();
    final stockAlertCount = activeProducts
        .where(
          (product) => isStockAlert(
            calculateProductStatus(
              stock: product.stock,
              lowStockLevel: product.lowStockLevel,
            ),
          ),
        )
        .length;
    final customerRows = await getActiveCustomers();
    final outstanding = customerRows.fold<int>(
      0,
      (total, customer) => total + customer.outstandingBalance,
    );
    return DashboardSummary(
      totalSalesToday: report.totalSales,
      costOfGoodsSoldToday: report.costOfGoodsSold,
      grossProfitToday: report.grossProfit,
      totalExpensesToday: report.totalExpenses,
      netIncomeToday: report.netIncome,
      totalOutstandingCredit: outstanding,
      stockAlertItemsCount: stockAlertCount,
      hasIncompleteCostData: report.hasIncompleteCostData,
    );
  }

  Future<List<Sale>> recentSales({int limit = 5}) {
    final query = select(sales)
      ..where((tbl) => tbl.status.equals(SaleStatus.completed.dbValue))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.saleDate)])
      ..limit(limit);
    return query.get();
  }

  Future<List<Product>> lowStockProducts({int limit = 5}) async {
    final active = await getActiveProducts();
    final low = active
        .where(
          (product) => isStockAlert(
            calculateProductStatus(
              stock: product.stock,
              lowStockLevel: product.lowStockLevel,
            ),
          ),
        )
        .toList();
    low.sort((left, right) {
      final leftStatus = calculateProductStatus(
        stock: left.stock,
        lowStockLevel: left.lowStockLevel,
      );
      final rightStatus = calculateProductStatus(
        stock: right.stock,
        lowStockLevel: right.lowStockLevel,
      );
      final statusOrder = _stockAlertPriority(
        leftStatus,
      ).compareTo(_stockAlertPriority(rightStatus));
      if (statusOrder != 0) {
        return statusOrder;
      }
      final stockOrder = left.stock.compareTo(right.stock);
      if (stockOrder != 0) {
        return stockOrder;
      }
      return left.name.compareTo(right.name);
    });
    return low.take(limit).toList();
  }

  Future<ReportSummary> reportForRange({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!end.isAfter(start)) {
      throw ArgumentError.value(end, 'end', 'End must be after start.');
    }
    final salesRows =
        await (select(sales)..where(
              (tbl) =>
                  tbl.saleDate.isBiggerOrEqualValue(start) &
                  tbl.saleDate.isSmallerThanValue(end) &
                  tbl.status.equals(SaleStatus.completed.dbValue),
            ))
            .get();
    final saleIds = salesRows.map((sale) => sale.id).toList(growable: false);
    final saleItemRows = saleIds.isEmpty
        ? const <SaleItem>[]
        : await (select(
            saleItems,
          )..where((tbl) => tbl.saleId.isIn(saleIds))).get();
    final expenseRows =
        await (select(expenses)..where(
              (tbl) =>
                  tbl.expenseDate.isBiggerOrEqualValue(start) &
                  tbl.expenseDate.isSmallerThanValue(end) &
                  tbl.isVoided.equals(false),
            ))
            .get();
    final creditPaymentsRows =
        await (select(creditPayments)..where(
              (tbl) =>
                  tbl.paymentDate.isBiggerOrEqualValue(start) &
                  tbl.paymentDate.isSmallerThanValue(end) &
                  tbl.isReversed.equals(false),
            ))
            .get();

    final totalSales = salesRows.fold<int>(
      0,
      (total, sale) => total + sale.totalAmount,
    );
    final totalExpenses = expenseRows.fold<int>(
      0,
      (total, expense) => total + expense.amount,
    );
    final costOfGoodsSold = saleItemRows.fold<int>(
      0,
      (total, item) => total + (item.costPriceSnapshot ?? 0) * item.quantity,
    );
    final missingCostItemCount = saleItemRows
        .where((item) => item.costPriceSnapshot == null)
        .length;
    final grossProfit = totalSales - costOfGoodsSold;
    final totalCreditGiven = salesRows
        .where((sale) => sale.paymentType == PaymentType.credit.dbValue)
        .fold<int>(0, (total, sale) => total + sale.totalAmount);
    final totalCreditCollected = creditPaymentsRows.fold<int>(
      0,
      (total, payment) => total + payment.amount,
    );

    return ReportSummary(
      totalSales: totalSales,
      costOfGoodsSold: costOfGoodsSold,
      grossProfit: grossProfit,
      totalExpenses: totalExpenses,
      netIncome: grossProfit - totalExpenses,
      totalCreditGiven: totalCreditGiven,
      totalCreditCollected: totalCreditCollected,
      missingCostItemCount: missingCostItemCount,
    );
  }

  int _stockAlertPriority(ProductStatus status) {
    return switch (status) {
      ProductStatus.outOfStock => 0,
      ProductStatus.lowStock => 1,
      ProductStatus.normal => 2,
    };
  }
}
