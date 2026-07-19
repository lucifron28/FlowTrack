import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/features/dashboard/screens/dashboard_screen.dart';
import 'package:flowtrack/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard exposes retry after a failed refresh', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardDataProvider.overrideWith((ref) async {
            attempts++;
            if (attempts == 1) {
              throw StateError('Temporary database failure');
            }
            return const DashboardData(
              summary: DashboardSummary(
                totalSalesToday: 0,
                costOfGoodsSoldToday: 0,
                grossProfitToday: 0,
                totalExpensesToday: 0,
                netIncomeToday: 0,
                totalOutstandingCredit: 0,
                stockAlertItemsCount: 0,
                hasIncompleteCostData: false,
              ),
              recentSales: [],
              lowStockProducts: [],
            );
          }),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Dashboard unavailable'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Sales Today'), findsOneWidget);
    expect(find.text('Stock Alerts'), findsOneWidget);
  });
}
