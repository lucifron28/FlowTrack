import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/flowtrack_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/section_card.dart';

enum ReportRange { daily, weekly, monthly, custom }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportRange _range = ReportRange.daily;
  DateTime _start = startOfDay(DateTime.now());
  DateTime _end = endOfDay(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('Reports')) : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ReportRange>(
            segments: const [
              ButtonSegment(value: ReportRange.daily, label: Text('Daily')),
              ButtonSegment(value: ReportRange.weekly, label: Text('Weekly')),
              ButtonSegment(value: ReportRange.monthly, label: Text('Monthly')),
              ButtonSegment(value: ReportRange.custom, label: Text('Custom')),
            ],
            selected: {_range},
            onSelectionChanged: (value) {
              setState(() {
                _range = value.first;
                _applyRange();
              });
            },
          ),
          if (_range == ReportRange.custom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickCustomDate(start: true),
                    icon: const Icon(Icons.date_range),
                    label: Text(_start.toLocal().toString().split(' ').first),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickCustomDate(start: false),
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _end
                          .subtract(const Duration(days: 1))
                          .toLocal()
                          .toString()
                          .split(' ')
                          .first,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FutureBuilder<ReportSummary>(
            future: database.reportForRange(start: _start, end: _end),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final report = snapshot.data!;
              return Column(
                children: [
                  _ReportTile(label: 'Total Sales', amount: report.totalSales),
                  _ReportTile(
                    label: 'Total Expenses',
                    amount: report.totalExpenses,
                  ),
                  _ReportTile(label: 'Net Income', amount: report.netIncome),
                  _ReportTile(
                    label: 'Total Credit Given',
                    amount: report.totalCreditGiven,
                  ),
                  _ReportTile(
                    label: 'Total Credit Collected',
                    amount: report.totalCreditCollected,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Exports'),
                SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.picture_as_pdf),
                  title: Text('Export PDF'),
                  subtitle: Text(
                    'Placeholder pending package and layout approval.',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.table_chart),
                  title: Text('Export CSV'),
                  subtitle: Text('Placeholder pending export approval.'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.print),
                  title: Text('Print Report'),
                  subtitle: Text('Placeholder pending printer workflow.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _applyRange() {
    final now = DateTime.now();
    switch (_range) {
      case ReportRange.daily:
        _start = startOfDay(now);
        _end = endOfDay(now);
        break;
      case ReportRange.weekly:
        _start = startOfDay(now).subtract(Duration(days: now.weekday - 1));
        _end = _start.add(const Duration(days: 7));
        break;
      case ReportRange.monthly:
        _start = DateTime(now.year, now.month);
        _end = DateTime(now.year, now.month + 1);
        break;
      case ReportRange.custom:
        _start = startOfDay(now);
        _end = endOfDay(now);
        break;
    }
  }

  Future<void> _pickCustomDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: start ? _start : _end.subtract(const Duration(days: 1)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (start) {
        _start = startOfDay(picked);
      } else {
        _end = endOfDay(picked);
      }
      if (!_end.isAfter(_start)) {
        _end = _start.add(const Duration(days: 1));
      }
    });
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          trailing: CurrencyText(
            amount,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
