import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
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
  bool _exportBusy = false;

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('Reports')) : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportRangeSelector(
            value: _range,
            onChanged: (value) {
              setState(() {
                _range = value;
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
              children: [
                const Text('Exports'),
                const SizedBox(height: 8),
                Text(
                  'Save or share the currently selected report range as a PDF.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _exportBusy ? null : _savePdf,
                        icon: _exportBusy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_alt),
                        label: const Text('Save PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exportBusy ? null : _sharePdf,
                        icon: const Icon(Icons.share),
                        label: const Text('Share PDF'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.table_chart),
                  title: Text('Export CSV'),
                  subtitle: Text('Placeholder pending export approval.'),
                ),
                const ListTile(
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

  Future<void> _savePdf() async {
    await _runPdfExport(
      action: (summary) async {
        await ref
            .read(reportPdfServiceProvider)
            .saveReportPdf(
              reportTitle: _reportTitle,
              start: _start,
              end: _end,
              summary: summary,
            );
      },
      successMessage: 'Report PDF saved to Downloads.',
    );
  }

  Future<void> _sharePdf() async {
    await _runPdfExport(
      action: (summary) => ref
          .read(reportPdfServiceProvider)
          .shareReportPdf(
            reportTitle: _reportTitle,
            start: _start,
            end: _end,
            summary: summary,
          ),
      successMessage: 'Report PDF ready to share.',
    );
  }

  Future<void> _runPdfExport({
    required Future<void> Function(ReportSummary summary) action,
    required String successMessage,
  }) async {
    setState(() => _exportBusy = true);
    try {
      final summary = await ref
          .read(appDatabaseProvider)
          .reportForRange(start: _start, end: _end);
      await action(summary);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _exportBusy = false);
      }
    }
  }

  String get _reportTitle {
    return switch (_range) {
      ReportRange.daily => 'Daily Report',
      ReportRange.weekly => 'Weekly Report',
      ReportRange.monthly => 'Monthly Report',
      ReportRange.custom => 'Custom Date Range Report',
    };
  }
}

class _ReportRangeSelector extends StatelessWidget {
  const _ReportRangeSelector({required this.value, required this.onChanged});

  final ReportRange value;
  final ValueChanged<ReportRange> onChanged;

  static const _items = [
    (range: ReportRange.daily, label: 'Daily'),
    (range: ReportRange.weekly, label: 'Weekly'),
    (range: ReportRange.monthly, label: 'Monthly'),
    (range: ReportRange.custom, label: 'Custom'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = scheme.outline;

    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Row(
            children: [
              for (var index = 0; index < _items.length; index++) ...[
                Expanded(
                  child: _ReportRangeSegment(
                    label: _items[index].label,
                    selected: value == _items[index].range,
                    onTap: () => onChanged(_items[index].range),
                  ),
                ),
                if (index != _items.length - 1)
                  VerticalDivider(width: 1, thickness: 1, color: borderColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportRangeSegment extends StatelessWidget {
  const _ReportRangeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: selected ? scheme.onPrimary : scheme.onSurface,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
    );

    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      child: InkWell(
        onTap: selected ? null : onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textStyle,
            ),
          ),
        ),
      ),
    );
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
