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
  const AddExpenseScreen({super.key});

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
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
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
            label: const Text('Save Expense'),
          ),
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
      await ref
          .read(appDatabaseProvider)
          .createExpense(
            category: _category,
            description: _descriptionController.text,
            amount: CurrencyFormatter.parseToCentavos(_amountController.text),
            expenseDate: _date,
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
    }
  }
}
