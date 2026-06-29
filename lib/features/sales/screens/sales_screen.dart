import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/domain/flowtrack_models.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../inventory/screens/inventory_screen.dart';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: StreamBuilder<List<Sale>>(
        stream: database.watchSales(),
        builder: (context, snapshot) {
          final sales = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (sales.isEmpty) {
            return const EmptyState(
              icon: Icons.point_of_sale,
              title: 'No sales yet',
              message: 'Create a sale by scanning or searching products.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: sales.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final sale = sales[index];
              return Card(
                child: ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SaleDetailsScreen(saleId: sale.id),
                    ),
                  ),
                  title: Text(sale.saleNumber),
                  subtitle: Text('${sale.paymentType} • ${sale.status}'),
                  trailing: CurrencyText(sale.totalAmount),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NewSaleScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Sale'),
      ),
    );
  }
}

class NewSaleScreen extends ConsumerStatefulWidget {
  const NewSaleScreen({super.key});

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  final _amountReceivedController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _contactController = TextEditingController();
  final List<SaleCartLine> _cart = [];
  PaymentType _paymentType = PaymentType.cash;
  String? _selectedCustomerId;

  int get _total => calculateSaleTotal(_cart);

  @override
  void dispose() {
    _amountReceivedController.dispose();
    _customerNameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(appDatabaseProvider);
    final amountReceived = _parseAmountReceived();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        actions: [
          IconButton(
            tooltip: 'Clear sale',
            onPressed: _cart.isEmpty ? null : () => setState(_cart.clear),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Barcode'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _searchProduct,
                  icon: const Icon(Icons.search),
                  label: const Text('Search Product'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Current Sale', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_cart.isEmpty)
            const Card(
              child: SizedBox(
                height: 160,
                child: EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'No items',
                  message: 'Scan a barcode or search a product.',
                ),
              ),
            )
          else
            ..._cart.map(
              (item) => Card(
                child: ListTile(
                  title: Text(item.productName),
                  subtitle: Text(
                    '${CurrencyFormatter.format(item.unitPrice)} x ${item.quantity}',
                  ),
                  trailing: SizedBox(
                    width: 148,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Decrease',
                          onPressed: () => _changeQuantity(item.productId, -1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('${item.quantity}'),
                        IconButton(
                          tooltip: 'Increase',
                          onPressed: () => _changeQuantity(item.productId, 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_cart.fold<int>(0, (sum, item) => sum + item.quantity)} items',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  CurrencyText(
                    _total,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<PaymentType>(
            segments: const [
              ButtonSegment(
                value: PaymentType.cash,
                label: Text('Cash'),
                icon: Icon(Icons.payments),
              ),
              ButtonSegment(
                value: PaymentType.credit,
                label: Text('Credit'),
                icon: Icon(Icons.account_balance_wallet),
              ),
            ],
            selected: {_paymentType},
            onSelectionChanged: (value) =>
                setState(() => _paymentType = value.first),
          ),
          const SizedBox(height: 12),
          if (_paymentType == PaymentType.cash) ...[
            _CashChangePanel(
              total: _total,
              amountReceived: amountReceived,
              controller: _amountReceivedController,
              onAmountChanged: () => setState(() {}),
              onTenderSelected: _setTenderedAmount,
            ),
          ] else
            FutureBuilder<List<Customer>>(
              future: database.getActiveCustomers(),
              builder: (context, snapshot) {
                final customers = snapshot.data ?? [];
                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCustomerId,
                      decoration: const InputDecoration(
                        labelText: 'Existing customer optional',
                        prefixIcon: Icon(Icons.person_search),
                      ),
                      items: customers
                          .map(
                            (customer) => DropdownMenuItem(
                              value: customer.id,
                              child: Text(customer.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCustomerId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'New customer name',
                        prefixIcon: Icon(Icons.person_add),
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
                  ],
                );
              },
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _cart.isEmpty ? null : _completeSale,
            icon: const Icon(Icons.check_circle),
            label: const Text('Complete Sale'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null) {
      await _addBarcode(code);
    }
  }

  Future<void> _searchProduct() async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      showDragHandle: true,
      builder: (context) => ProductPickerSheet(
        productsFuture: ref.read(appDatabaseProvider).getActiveProducts(),
      ),
    );
    if (product != null) {
      _addProduct(product);
    }
  }

  Future<void> _addBarcode(String barcode) async {
    final database = ref.read(appDatabaseProvider);
    final product = await database.findProductByBarcode(barcode);
    if (product == null && mounted) {
      final add = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Product not found'),
          content: const Text('Do you want to add this product to inventory?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add Product'),
            ),
          ],
        ),
      );
      if (add == true && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddProductScreen(initialBarcode: barcode),
          ),
        );
      }
      return;
    }
    if (product != null) {
      _addProduct(product);
    }
  }

  void _addProduct(Product product) {
    final existingIndex = _cart.indexWhere(
      (item) => item.productId == product.id,
    );
    setState(() {
      if (existingIndex >= 0) {
        final existing = _cart[existingIndex];
        if (existing.quantity + 1 > product.stock) {
          _showMessage('Not enough stock available.');
          return;
        }
        _cart[existingIndex] = existing.copyWith(
          quantity: existing.quantity + 1,
        );
      } else {
        if (product.stock <= 0) {
          _showMessage('Not enough stock available.');
          return;
        }
        _cart.add(
          SaleCartLine(
            productId: product.id,
            productName: product.name,
            barcode: product.barcode,
            unitPrice: product.sellingPrice,
            costPrice: product.costPrice,
            quantity: 1,
          ),
        );
      }
    });
  }

  Future<void> _changeQuantity(String productId, int delta) async {
    final index = _cart.indexWhere((item) => item.productId == productId);
    if (index < 0) {
      return;
    }
    final current = _cart[index];
    final product = await ref.read(appDatabaseProvider).getProduct(productId);
    final nextQuantity = current.quantity + delta;
    if (nextQuantity <= 0) {
      setState(() => _cart.removeAt(index));
      return;
    }
    if (product != null && nextQuantity > product.stock) {
      _showMessage('Not enough stock available.');
      return;
    }
    setState(() => _cart[index] = current.copyWith(quantity: nextQuantity));
  }

  Future<void> _completeSale() async {
    final amountReceived = _paymentType == PaymentType.cash
        ? _parseAmountReceived()
        : null;
    if (_paymentType == PaymentType.cash && amountReceived == null) {
      _showMessage('Enter a valid amount received.');
      return;
    }
    try {
      await ref
          .read(appDatabaseProvider)
          .completeSale(
            items: _cart,
            paymentType: _paymentType,
            saleDate: DateTime.now(),
            amountReceived: amountReceived,
            customerId: _selectedCustomerId,
            customerName: _customerNameController.text,
            contactNumber: _contactController.text,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  int? _parseAmountReceived() {
    final text = _amountReceivedController.text.trim();
    if (text.isEmpty) {
      return null;
    }
    try {
      return CurrencyFormatter.parseToCentavos(text);
    } catch (_) {
      return null;
    }
  }

  void _setTenderedAmount(int amount) {
    _amountReceivedController.text = (amount / 100).toStringAsFixed(2);
    setState(() {});
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CashChangePanel extends StatelessWidget {
  const _CashChangePanel({
    required this.total,
    required this.amountReceived,
    required this.controller,
    required this.onAmountChanged,
    required this.onTenderSelected,
  });

  final int total;
  final int? amountReceived;
  final TextEditingController controller;
  final VoidCallback onAmountChanged;
  final ValueChanged<int> onTenderSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final validAmount = amountReceived;
    final change = validAmount == null ? null : validAmount - total;
    final isShort = change != null && change < 0;
    final tenderOptions = _suggestTenderAmounts(total);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Amount Due', style: theme.textTheme.titleMedium),
                CurrencyText(
                  total,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount received',
                prefixIcon: const Icon(Icons.payments),
                errorText:
                    controller.text.trim().isNotEmpty && validAmount == null
                    ? 'Enter a valid peso amount.'
                    : null,
              ),
              onChanged: (_) => onAmountChanged(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final amount in tenderOptions)
                  ActionChip(
                    label: Text(CurrencyFormatter.format(amount)),
                    avatar: amount == total
                        ? const Icon(Icons.price_check, size: 18)
                        : null,
                    onPressed: () => onTenderSelected(amount),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isShort
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.primaryContainer,
              ),
              child: Row(
                children: [
                  Icon(
                    isShort ? Icons.warning_amber : Icons.change_circle,
                    color: isShort
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isShort ? 'Short by' : 'Change',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isShort
                            ? theme.colorScheme.onErrorContainer
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  CurrencyText(
                    change == null ? 0 : change.abs(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isShort
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<int> _suggestTenderAmounts(int total) {
    if (total <= 0) {
      return const [2000, 5000, 10000, 50000, 100000];
    }
    final candidates = <int>{
      total,
      _roundUp(total, 2000),
      _roundUp(total, 5000),
      _roundUp(total, 10000),
      _roundUp(total, 50000),
      _roundUp(total, 100000),
    }.where((amount) => amount >= total).toList()..sort();
    return candidates.take(5).toList();
  }

  int _roundUp(int value, int step) {
    return ((value + step - 1) ~/ step) * step;
  }
}

class ProductPickerSheet extends StatefulWidget {
  const ProductPickerSheet({super.key, required this.productsFuture});

  final Future<List<Product>> productsFuture;

  @override
  State<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search product',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Product>>(
                future: widget.productsFuture,
                builder: (context, snapshot) {
                  final products = (snapshot.data ?? [])
                      .where(
                        (product) =>
                            product.name.toLowerCase().contains(
                              _query.toLowerCase(),
                            ) ||
                            product.barcode.toLowerCase().contains(
                              _query.toLowerCase(),
                            ),
                      )
                      .toList();
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (products.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off,
                      title: 'No products',
                      message: 'Try a different product name or barcode.',
                    );
                  }
                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ListTile(
                        title: Text(product.name),
                        subtitle: Text('Stock: ${product.stock}'),
                        trailing: CurrencyText(product.sellingPrice),
                        onTap: () => Navigator.of(context).pop(product),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SaleDetailsScreen extends ConsumerWidget {
  const SaleDetailsScreen({super.key, required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sale Details')),
      body: FutureBuilder<Sale?>(
        future: database.getSale(saleId),
        builder: (context, saleSnapshot) {
          final sale = saleSnapshot.data;
          if (saleSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (sale == null) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Sale not found',
              message: 'The selected transaction is unavailable.',
            );
          }
          return FutureBuilder<List<SaleItem>>(
            future: database.getSaleItems(sale.id),
            builder: (context, itemSnapshot) {
              final items = itemSnapshot.data ?? [];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      title: Text(sale.saleNumber),
                      subtitle: Text('${sale.paymentType} • ${sale.status}'),
                      trailing: CurrencyText(sale.totalAmount),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...items.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productNameSnapshot),
                      subtitle: Text('Qty ${item.quantity}'),
                      trailing: CurrencyText(item.subtotal),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (sale.status == SaleStatus.completed.dbValue)
                    FilledButton.icon(
                      onPressed: () => _voidSale(context, ref),
                      icon: const Icon(Icons.undo),
                      label: const Text('Void Transaction'),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _voidSale(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void transaction'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason optional'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) {
      return;
    }
    try {
      await ref.read(appDatabaseProvider).voidSale(saleId, reason: reason);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}
