import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(expense: expense),
                    ),
                  ),
                  title: Text(expense.category),
                  subtitle: Text(expense.description ?? 'No description'),
                  trailing: CurrencyText(expense.amount),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
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

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _category = categories.contains(widget.expense!.category)
          ? widget.expense!.category
          : categories.first;
      _descriptionController.text = widget.expense!.description ?? '';
      _amountController.text = (widget.expense!.amount / 100).toStringAsFixed(2);
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
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description optional',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
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
            onTap: _pickDate,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(isEdit ? 'Save Changes' : 'Save Expense'),
          ),
          if (isEdit) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete),
              label: const Text('Delete Expense'),
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

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text('Are you sure you want to delete this expense? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref
            .read(appDatabaseProvider)
            .deleteExpense(widget.expense!.id);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      }
    }
  }
}
