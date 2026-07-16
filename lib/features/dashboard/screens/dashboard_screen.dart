import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(todayProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder(
              future: database.dashboardSummary(DateTime.now()),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final summary = snapshot.data!;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.sizeOf(context).width > 520
                      ? 3
                      : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  children: [
                    _MetricCard(
                      label: 'Sales Today',
                      amount: summary.totalSalesToday,
                      icon: Icons.point_of_sale,
                    ),
                    _MetricCard(
                      label: 'Expenses Today',
                      amount: summary.totalExpensesToday,
                      icon: Icons.receipt_long,
                    ),
                    _MetricCard(
                      label: 'Net Income',
                      amount: summary.netIncomeToday,
                      icon: Icons.trending_up,
                    ),
                    _MetricCard(
                      label: 'Outstanding Credit',
                      amount: summary.totalOutstandingCredit,
                      icon: Icons.account_balance_wallet,
                    ),
                    _CountCard(
                      label: 'Low Stock Items',
                      count: summary.stockAlertItemsCount,
                      icon: Icons.warning_amber,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.pushNamed(AppRoutes.newSaleName),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add Sale'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () =>
                        context.pushNamed(AppRoutes.addExpenseName),
                    icon: const Icon(Icons.add_card),
                    label: const Text('Expense'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.pushNamed(AppRoutes.addProductName),
              icon: const Icon(Icons.add_box),
              label: const Text('Add Inventory Item'),
            ),
            const SizedBox(height: 20),
            _RecentSales(database: database),
            const SizedBox(height: 16),
            _LowStockPreview(database: database),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.amount,
    required this.icon,
  });

  final String label;
  final int amount;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const Spacer(),
          CurrencyText(
            amount,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.icon,
  });

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.error),
          const Spacer(),
          Text(
            '$count',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RecentSales extends StatelessWidget {
  const _RecentSales({required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Sales', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<List<Sale>>(
            future: database.recentSales(),
            builder: (context, snapshot) {
              final sales = snapshot.data ?? [];
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (sales.isEmpty) {
                return const SizedBox(
                  height: 132,
                  child: EmptyState(
                    icon: Icons.point_of_sale,
                    title: 'No sales yet',
                    message: 'Completed sales will appear here.',
                    compact: true,
                  ),
                );
              }
              return Column(
                children: sales.map((sale) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(sale.saleNumber),
                    subtitle: Text(sale.paymentType),
                    trailing: CurrencyText(sale.totalAmount),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LowStockPreview extends StatelessWidget {
  const _LowStockPreview({required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Low Stock Preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Product>>(
            future: database.lowStockProducts(),
            builder: (context, snapshot) {
              final products = snapshot.data ?? [];
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (products.isEmpty) {
                return const Text('No low stock items right now.');
              }
              return Column(
                children: products.map((product) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(product.name),
                    subtitle: Text(product.barcode),
                    trailing: Text('Stock: ${product.stock}'),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
