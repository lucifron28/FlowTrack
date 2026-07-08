part of 'app_database.dart';

extension AppDatabaseReports on AppDatabase {
  Future<DashboardSummary> dashboardSummary(DateTime day) async {
    final start = startOfDay(day);
    final end = endOfDay(day);
    final report = await reportForRange(start: start, end: end);
    final activeProducts = await getActiveProducts();
    final lowStockCount = activeProducts
        .where(
          (product) =>
              calculateProductStatus(
                stock: product.stock,
                lowStockLevel: product.lowStockLevel,
              ) ==
              ProductStatus.lowStock,
        )
        .length;
    final customerRows = await getActiveCustomers();
    final outstanding = customerRows.fold<int>(
      0,
      (total, customer) => total + customer.outstandingBalance,
    );
    return DashboardSummary(
      totalSalesToday: report.totalSales,
      totalExpensesToday: report.totalExpenses,
      netIncomeToday: report.netIncome,
      totalOutstandingCredit: outstanding,
      lowStockItemsCount: lowStockCount,
    );
  }

  Future<List<Sale>> recentSales({int limit = 5}) {
    final query = select(sales)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.saleDate)])
      ..limit(limit);
    return query.get();
  }

  Future<List<Product>> lowStockProducts({int limit = 5}) async {
    final active = await getActiveProducts();
    final low = active
        .where(
          (product) =>
              calculateProductStatus(
                stock: product.stock,
                lowStockLevel: product.lowStockLevel,
              ) !=
              ProductStatus.normal,
        )
        .toList();
    return low.take(limit).toList();
  }

  Future<ReportSummary> reportForRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final salesRows =
        await (select(sales)..where(
              (tbl) =>
                  tbl.saleDate.isBiggerOrEqualValue(start) &
                  tbl.saleDate.isSmallerThanValue(end) &
                  tbl.status.equals(SaleStatus.completed.dbValue),
            ))
            .get();
    final expenseRows =
        await (select(expenses)..where(
              (tbl) =>
                  tbl.expenseDate.isBiggerOrEqualValue(start) &
                  tbl.expenseDate.isSmallerThanValue(end),
            ))
            .get();
    final creditPaymentsRows =
        await (select(creditPayments)..where(
              (tbl) =>
                  tbl.paymentDate.isBiggerOrEqualValue(start) &
                  tbl.paymentDate.isSmallerThanValue(end),
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
    final totalCreditGiven = salesRows
        .where((sale) => sale.paymentType == PaymentType.credit.dbValue)
        .fold<int>(0, (total, sale) => total + sale.totalAmount);
    final totalCreditCollected = creditPaymentsRows.fold<int>(
      0,
      (total, payment) => total + payment.amount,
    );

    return ReportSummary(
      totalSales: totalSales,
      totalExpenses: totalExpenses,
      netIncome: totalSales - totalExpenses,
      totalCreditGiven: totalCreditGiven,
      totalCreditCollected: totalCreditCollected,
    );
  }
}
