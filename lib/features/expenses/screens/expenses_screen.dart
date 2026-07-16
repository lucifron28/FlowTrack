import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: showAppBar ? AppBar(title: const Text('Expenses')) : null,
      body: StreamBuilder<List<Expense>>(
        stream: database.watchExpenses(),
        builder: (context, snapshot) {
          final expenses = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (expenses.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long,
              title: 'No expenses yet',
              message: 'Record restocking, rent, utilities, and store costs.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: expenses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final expense = expenses[index];
              return Card(
                child: ListTile(
                  onTap: expense.isVoided
                      ? null
                      : () => context.pushNamed(
                          AppRoutes.editExpenseName,
                          pathParameters: {'expenseId': expense.id},
                          extra: expense,
                        ),
                  title: Text(expense.category),
                  subtitle: Text(
                    expense.isVoided
                        ? 'Voided ${_dateLabel(expense.voidedAt)}: '
                              '${expense.voidReason}'
                        : '${expense.description ?? 'No description'}\n'
                              '${_dateLabel(expense.expenseDate)}',
                  ),
                  isThreeLine: expense.isVoided,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          CurrencyText(expense.amount),
                          if (expense.isVoided)
                            Text(
                              'VOIDED',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRoutes.addExpenseName),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  static String _dateLabel(DateTime? date) {
    if (date == null) {
      return 'unknown date';
    }
    return date.toLocal().toString().split(' ').first;
  }
}

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key, this.expense});

  final Expense? expense;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  static const categories = [
    'Restocking',
    'Utilities',
    'Rent',
    'Transportation',
    'Store Supplies',
    'Personal Use',
    'Others',
  ];

  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = categories.first;
  DateTime _date = DateTime.now();
  bool _isVoiding = false;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _category = categories.contains(widget.expense!.category)
          ? widget.expense!.category
          : categories.first;
      _descriptionController.text = widget.expense!.description ?? '';
      _amountController.text = (widget.expense!.amount / 100).toStringAsFixed(
        2,
      );
      _date = widget.expense!.expenseDate;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.expense != null;
    final isVoided = widget.expense?.isVoided ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Expense' : 'Add Expense')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category),
            ),
            items: categories
                .map(
                  (category) =>
                      DropdownMenuItem(value: category, child: Text(category)),
                )
                .toList(),
            onChanged: isVoided
                ? null
                : (value) => setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            enabled: !isVoided,
            decoration: const InputDecoration(
              labelText: 'Description optional',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            enabled: !isVoided,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixIcon: Icon(Icons.payments),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Expense date'),
            subtitle: Text(_date.toLocal().toString().split(' ').first),
            trailing: const Icon(Icons.calendar_today),
            onTap: isVoided ? null : _pickDate,
          ),
          const SizedBox(height: 20),
          if (isVoided) ...[
            Text(
              'This expense was voided on ${_dateLabel(widget.expense!.voidedAt)}. '
              'Reason: ${widget.expense!.voidReason}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(isEdit ? 'Save Changes' : 'Save Expense'),
            ),
          ],
          if (isEdit && !isVoided) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isVoiding ? null : _voidExpense,
              icon: _isVoiding
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.block),
              label: const Text('Void Expense'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final amount = CurrencyFormatter.parseToCentavos(_amountController.text);
      if (widget.expense == null) {
        await db.createExpense(
          category: _category,
          description: _descriptionController.text,
          amount: amount,
          expenseDate: _date,
        );
      } else {
        await db.updateExpense(
          expenseId: widget.expense!.id,
          category: _category,
          description: _descriptionController.text,
          amount: amount,
          expenseDate: _date,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _voidExpense() async {
    final reasonController = TextEditingController();
    String? errorText;
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Void Expense?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Voiding preserves this expense in history and removes it from financial reports.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Void reason',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = reasonController.text.trim();
                if (value.isEmpty) {
                  setDialogState(() => errorText = 'A void reason is required.');
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Void Expense'),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();

    if (reason == null || !mounted) {
      return;
    }

    setState(() => _isVoiding = true);
    try {
      await ref.read(appDatabaseProvider).voidExpense(
            expenseId: widget.expense!.id,
            reason: reason,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isVoiding = false);
      }
    }
  }

  static String _dateLabel(DateTime? date) {
    if (date == null) {
      return 'unknown date';
    }
    return date.toLocal().toString().split(' ').first;
  }
}
