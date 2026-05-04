import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Credits')),
      body: StreamBuilder<List<Customer>>(
        stream: database.watchCustomers(),
        builder: (context, snapshot) {
          final customers = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (customers.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No customers yet',
              message: 'Credit customers will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: customers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final customer = customers[index];
              return Card(
                child: ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerDetailsScreen(customer: customer),
                    ),
                  ),
                  title: Text(customer.name),
                  subtitle: Text(customer.contactNumber ?? 'No contact number'),
                  trailing: CurrencyText(customer.outstandingBalance),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddCustomerScreen())),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
    );
  }
}

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Customer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Customer name',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact number optional',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Customer'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    try {
      await ref
          .read(appDatabaseProvider)
          .createCustomer(
            name: _nameController.text,
            contactNumber: _contactController.text,
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

class CustomerDetailsScreen extends ConsumerWidget {
  const CustomerDetailsScreen({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: Text(customer.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Outstanding Balance'),
              subtitle: Text(customer.contactNumber ?? 'No contact number'),
              trailing: CurrencyText(
                customer.outstandingBalance,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: customer.outstandingBalance <= 0
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecordPaymentScreen(customer: customer),
                    ),
                  ),
            icon: const Icon(Icons.payments),
            label: const Text('Record Payment'),
          ),
          const SizedBox(height: 16),
          Text(
            'Credit Records',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          StreamBuilder<List<CreditRecord>>(
            stream: database.watchCreditRecords(customer.id),
            builder: (context, snapshot) {
              final records = snapshot.data ?? [];
              if (records.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No credit records yet.'),
                );
              }
              return Column(
                children: records
                    .map(
                      (record) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: CurrencyText(record.amount),
                        subtitle: Text(record.status),
                        trailing: record.paidAmount > 0
                            ? Text(
                                'Paid ${CurrencyFormatter.format(record.paidAmount)}',
                              )
                            : null,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Payment Records',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          StreamBuilder<List<CreditPayment>>(
            stream: database.watchCreditPayments(customer.id),
            builder: (context, snapshot) {
              final payments = snapshot.data ?? [];
              if (payments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No payments yet.'),
                );
              }
              return Column(
                children: payments
                    .map(
                      (payment) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: CurrencyText(payment.amount),
                        subtitle: Text(payment.notes ?? 'Payment'),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class RecordPaymentScreen extends ConsumerStatefulWidget {
  const RecordPaymentScreen({super.key, required this.customer});

  final Customer customer;

  @override
  ConsumerState<RecordPaymentScreen> createState() =>
      _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(widget.customer.name),
            subtitle: const Text('Outstanding balance'),
            trailing: CurrencyText(widget.customer.outstandingBalance),
          ),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Payment amount',
              prefixIcon: Icon(Icons.payments),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Payment date'),
            subtitle: Text(_date.toLocal().toString().split(' ').first),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes optional'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Payment'),
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
          .recordCreditPayment(
            customerId: widget.customer.id,
            amount: CurrencyFormatter.parseToCentavos(_amountController.text),
            paymentDate: _date,
            notes: _notesController.text,
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
