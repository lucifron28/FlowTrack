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
    final dashboardAsync = ref.watch(dashboardDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayProvider);
          await ref.read(dashboardDataProvider.future);
        },
        child: dashboardAsync.when(
          loading: () => const _DashboardLoading(),
          error: (_, _) => _DashboardError(
            onRetry: () => ref.invalidate(dashboardDataProvider),
          ),
          data: (data) => _DashboardContent(
            data: data,
            onOpenSales: () async {
              await context.pushNamed(AppRoutes.newSaleName);
              ref.invalidate(dashboardDataProvider);
            },
            onOpenExpense: () async {
              await context.pushNamed(AppRoutes.addExpenseName);
              ref.invalidate(dashboardDataProvider);
            },
            onOpenInventory: () async {
              await context.pushNamed(AppRoutes.addProductName);
              ref.invalidate(dashboardDataProvider);
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 220),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 120),
        SectionCard(
          child: Column(
            children: [
              const Icon(Icons.error_outline),
              const SizedBox(height: 8),
              const Text('Dashboard unavailable'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.data,
    required this.onOpenSales,
    required this.onOpenExpense,
    required this.onOpenInventory,
  });

  final DashboardData data;
  final Future<void> Function() onOpenSales;
  final Future<void> Function() onOpenExpense;
  final Future<void> Function() onOpenInventory;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    final netIncomeLabel = summary.hasIncompleteCostData
        ? 'Net Income (Estimated)'
        : 'Net Income';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 3 : 2,
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
              label: netIncomeLabel,
              amount: summary.netIncomeToday,
              icon: Icons.trending_up,
            ),
            _MetricCard(
              label: 'Outstanding Credit',
              amount: summary.totalOutstandingCredit,
              icon: Icons.account_balance_wallet,
            ),
            _CountCard(
              label: 'Stock Alerts',
              count: summary.stockAlertItemsCount,
              icon: Icons.warning_amber,
            ),
          ],
        ),
        if (summary.hasIncompleteCostData) ...[
          const SizedBox(height: 12),
          Text(
            'Net income is estimated because some completed sales have no cost snapshot.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onOpenSales,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add Sale'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onOpenExpense,
                icon: const Icon(Icons.add_card),
                label: const Text('Expense'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onOpenInventory,
          icon: const Icon(Icons.add_box),
          label: const Text('Add Inventory Item'),
        ),
        const SizedBox(height: 20),
        _RecentSales(sales: data.recentSales),
        const SizedBox(height: 16),
        _LowStockPreview(products: data.lowStockProducts),
      ],
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
  const _RecentSales({required this.sales});

  final List<Sale> sales;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Sales', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (sales.isEmpty)
            const SizedBox(
              height: 132,
              child: EmptyState(
                icon: Icons.point_of_sale,
                title: 'No sales yet',
                message: 'Completed sales will appear here.',
                compact: true,
              ),
            )
          else
            Column(
              children: sales
                  .map(
                    (sale) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(sale.saleNumber),
                      subtitle: Text(sale.paymentType),
                      trailing: CurrencyText(sale.totalAmount),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _LowStockPreview extends StatelessWidget {
  const _LowStockPreview({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stock Alerts', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (products.isEmpty)
            const Text('No stock alerts right now.')
          else
            Column(
              children: products
                  .map(
                    (product) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(product.name),
                      subtitle: Text(product.barcode),
                      trailing: Text('Stock: ${product.stock}'),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
