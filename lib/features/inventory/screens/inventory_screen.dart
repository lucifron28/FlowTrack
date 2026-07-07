import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide BarcodeType;

import '../../../core/database/app_database.dart';
import '../../../core/domain/flowtrack_models.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import 'barcode_print_screen.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _query = '';
  ProductStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search product or barcode',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ProductStatus?>(
                  initialValue: _filter,
                  decoration: const InputDecoration(labelText: 'Status filter'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...ProductStatus.values.map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _filter = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: database.watchProducts(),
              builder: (context, snapshot) {
                final products = (snapshot.data ?? []).where((product) {
                  final status = calculateProductStatus(
                    stock: product.stock,
                    lowStockLevel: product.lowStockLevel,
                  );
                  final matchesQuery =
                      _query.trim().isEmpty ||
                      product.name.toLowerCase().contains(
                        _query.toLowerCase(),
                      ) ||
                      product.barcode.toLowerCase().contains(
                        _query.toLowerCase(),
                      );
                  final matchesFilter = _filter == null || status == _filter;
                  return matchesQuery && matchesFilter;
                }).toList();
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (products.isEmpty) {
                  return const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products found',
                    message:
                        'Add manufacturer items or tingi items to start selling.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final status = calculateProductStatus(
                      stock: product.stock,
                      lowStockLevel: product.lowStockLevel,
                    );
                    return ProductCard(
                      product: product,
                      status: status,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductDetailsScreen(productId: product.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddProductScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.status,
    required this.onTap,
  });

  final Product product;
  final ProductStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      ProductStatus.normal => theme.colorScheme.primary,
      ProductStatus.lowStock => Colors.orange.shade700,
      ProductStatus.outOfStock => theme.colorScheme.error,
    };
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.barcode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stock: ${product.stock}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 88,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CurrencyText(
                      product.sellingPrice,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusBadge(label: status.label, color: color),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({
    super.key,
    this.initialBarcode,
    this.initialType = BarcodeType.manufacturer,
  });

  final String? initialBarcode;
  final BarcodeType initialType;

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _lowStockController = TextEditingController(text: '0');
  late BarcodeType _barcodeType;

  @override
  void initState() {
    super.initState();
    _barcodeType = widget.initialType;
    _barcodeController.text = widget.initialBarcode ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<BarcodeType>(
              segments: const [
                ButtonSegment(
                  value: BarcodeType.manufacturer,
                  label: Text('Manufacturer'),
                  icon: Icon(Icons.barcode_reader),
                ),
                ButtonSegment(
                  value: BarcodeType.storeGenerated,
                  label: Text('Tingi'),
                  icon: Icon(Icons.sell),
                ),
              ],
              selected: {_barcodeType},
              onSelectionChanged: (value) {
                setState(() => _barcodeType = value.first);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Barcode',
                prefixIcon: const Icon(Icons.barcode_reader),
                suffixIcon: IconButton(
                  tooltip: _barcodeType == BarcodeType.storeGenerated
                      ? 'Generate barcode'
                      : 'Scan barcode',
                  onPressed: _barcodeType == BarcodeType.storeGenerated
                      ? _generateBarcode
                      : _scanBarcode,
                  icon: Icon(
                    _barcodeType == BarcodeType.storeGenerated
                        ? Icons.auto_awesome
                        : Icons.camera_alt,
                  ),
                ),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Barcode is required.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product name',
                prefixIcon: Icon(Icons.inventory),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Product name is required.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sellingPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Selling price',
                prefixIcon: Icon(Icons.payments),
              ),
              validator: _moneyValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _costPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cost price optional',
                prefixIcon: Icon(Icons.price_check),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null;
                }
                return _moneyValidator(value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Initial stock',
                prefixIcon: Icon(Icons.add_box),
              ),
              validator: _nonNegativeIntValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lowStockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Low stock level',
                prefixIcon: Icon(Icons.warning_amber),
              ),
              validator: _nonNegativeIntValidator,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save Product'),
            ),
            if (_barcodeType == BarcodeType.storeGenerated) ...[
              const SizedBox(height: 16),
              const Text(
                'Print this barcode once and place it on the sintra board.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _moneyValidator(String? value) {
    try {
      if (value == null || value.trim().isEmpty) {
        return 'Amount is required.';
      }
      final amount = CurrencyFormatter.parseToCentavos(value);
      if (amount < 0) {
        return 'Amount cannot be negative.';
      }
      return null;
    } catch (_) {
      return 'Enter a valid amount.';
    }
  }

  String? _nonNegativeIntValidator(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null) {
      return 'Enter a valid quantity.';
    }
    if (parsed < 0) {
      return 'Quantity cannot be negative.';
    }
    return null;
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null && mounted) {
      setState(() => _barcodeController.text = code);
    }
  }

  void _generateBarcode() {
    final service = ref.read(barcodeServiceProvider);
    setState(() => _barcodeController.text = service.generateStoreBarcode());
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final database = ref.read(appDatabaseProvider);
    try {
      final productId = await database.createProduct(
        name: _nameController.text,
        barcode: _barcodeController.text,
        barcodeType: _barcodeType,
        sellingPrice: CurrencyFormatter.parseToCentavos(
          _sellingPriceController.text,
        ),
        costPrice: _costPriceController.text.trim().isEmpty
            ? null
            : CurrencyFormatter.parseToCentavos(_costPriceController.text),
        initialStock: int.parse(_stockController.text),
        lowStockLevel: int.parse(_lowStockController.text),
      );
      if (mounted) {
        if (_barcodeType == BarcodeType.storeGenerated) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => BarcodePrintScreen(productId: productId),
            ),
          );
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (error) {
      final existing = await database.findProductByBarcode(
        _barcodeController.text,
      );
      if (mounted && existing != null) {
        final addStock = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Product already exists'),
            content: const Text(
              'This product already exists. Do you want to add stock instead?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Add Stock'),
              ),
            ],
          ),
        );
        if (addStock == true && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => AddStockScreen(productId: existing.id),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class ProductDetailsScreen extends ConsumerWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: StreamBuilder<Product?>(
        stream: database.watchProduct(productId),
        builder: (context, snapshot) {
          final product = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (product == null) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Product not found',
              message: 'The selected product is no longer available.',
            );
          }
          final status = calculateProductStatus(
            stock: product.stock,
            lowStockLevel: product.lowStockLevel,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('Barcode: ${product.barcode}'),
                      Text('Type: ${product.barcodeType}'),
                      Text('Stock: ${product.stock}'),
                      Text('Low stock level: ${product.lowStockLevel}'),
                      Text('Status: ${status.label}'),
                      Row(
                        children: [
                          const Text('Selling price: '),
                          CurrencyText(product.sellingPrice),
                        ],
                      ),
                      if (product.costPrice != null)
                        Row(
                          children: [
                            const Text('Cost price: '),
                            CurrencyText(product.costPrice!),
                          ],
                        ),
                      const Divider(),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active Status'),
                        subtitle: Text(
                          product.isActive
                              ? 'Visible in scanner and sales'
                              : 'Hidden from scanner and sales',
                        ),
                        value: product.isActive,
                        onChanged: (value) async {
                          await database.updateProductActive(
                            productId: product.id,
                            isActive: value,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddStockScreen(productId: product.id),
                  ),
                ),
                icon: const Icon(Icons.add_box),
                label: const Text('Add Stock'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditProductScreen(product: product),
                  ),
                ),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Product'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdjustStockScreen(product: product),
                  ),
                ),
                icon: const Icon(Icons.tune),
                label: const Text('Adjust Stock'),
              ),
              if (product.barcodeType == BarcodeType.storeGenerated.dbValue)
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BarcodePrintScreen(productId: product.id),
                    ),
                  ),
                  icon: const Icon(Icons.print),
                  label: const Text('Print Barcode Sheet'),
                ),
              const SizedBox(height: 12),
              Text(
                'Stock History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<StockMovement>>(
                stream: database.watchStockMovements(product.id),
                builder: (context, snapshot) {
                  final movements = snapshot.data ?? [];
                  if (movements.isEmpty) {
                    return const Text('No stock history yet.');
                  }
                  return Column(
                    children: movements
                        .map(
                          (movement) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(movement.movementType),
                            subtitle: Text(
                              movement.reason ?? movement.notes ?? '',
                            ),
                            trailing: Text('${movement.quantity}'),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class EditProductScreen extends ConsumerStatefulWidget {
  const EditProductScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _lowStockController;

  @override
  void initState() {
    super.initState();
    _sellingPriceController = TextEditingController(
      text: (widget.product.sellingPrice / 100).toStringAsFixed(2),
    );
    _costPriceController = TextEditingController(
      text: widget.product.costPrice == null
          ? ''
          : (widget.product.costPrice! / 100).toStringAsFixed(2),
    );
    _lowStockController = TextEditingController(
      text: widget.product.lowStockLevel.toString(),
    );
  }

  @override
  void dispose() {
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.product.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sellingPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Selling price'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _costPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cost price optional',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lowStockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Low stock level'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    try {
      await ref
          .read(appDatabaseProvider)
          .editProduct(
            productId: widget.product.id,
            sellingPrice: CurrencyFormatter.parseToCentavos(
              _sellingPriceController.text,
            ),
            costPrice: _costPriceController.text.trim().isEmpty
                ? null
                : CurrencyFormatter.parseToCentavos(_costPriceController.text),
            lowStockLevel: int.parse(_lowStockController.text),
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

class AddStockScreen extends ConsumerStatefulWidget {
  const AddStockScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends ConsumerState<AddStockScreen> {
  final _quantityController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Stock')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              prefixIcon: Icon(Icons.add_box),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Stock'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    try {
      await ref
          .read(appDatabaseProvider)
          .addStock(productId: widget.productId, quantity: quantity);
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

class AdjustStockScreen extends ConsumerStatefulWidget {
  const AdjustStockScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<AdjustStockScreen> createState() => _AdjustStockScreenState();
}

class _AdjustStockScreenState extends ConsumerState<AdjustStockScreen> {
  final _quantityController = TextEditingController();
  bool _add = true;
  String _reason = 'Correction';
  static const _reasons = [
    'Damaged',
    'Expired',
    'Personal Use',
    'Correction',
    'Others',
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adjust Stock')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.product.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Add'),
                icon: Icon(Icons.add),
              ),
              ButtonSegment(
                value: false,
                label: Text('Deduct'),
                icon: Icon(Icons.remove),
              ),
            ],
            selected: {_add},
            onSelectionChanged: (value) => setState(() => _add = value.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: _reasons
                .map(
                  (reason) =>
                      DropdownMenuItem(value: reason, child: Text(reason)),
                )
                .toList(),
            onChanged: (value) => setState(() => _reason = value ?? _reason),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Adjustment'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (!_add) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm deduction'),
          content: const Text('Deduct stock for this product?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Deduct'),
            ),
          ],
        ),
      );
      if (confirm != true) {
        return;
      }
    }
    try {
      await ref
          .read(appDatabaseProvider)
          .adjustStock(
            productId: widget.product.id,
            quantity: quantity,
            add: _add,
            reason: _reason,
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

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  final _manualController = TextEditingController();
  final _controller = MobileScannerController(
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  late final AnimationController _scanLineController;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _manualController.dispose();
    _controller.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scanWindow = _scannerWindowFor(
                  Size(constraints.maxWidth, constraints.maxHeight),
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      scanWindow: scanWindow,
                      onDetect: (capture) {
                        if (_locked) {
                          return;
                        }
                        final code = capture.barcodes
                            .map((barcode) => barcode.rawValue)
                            .whereType<String>()
                            .firstOrNull;
                        if (code == null || code.isEmpty) {
                          return;
                        }
                        _locked = true;
                        Navigator.of(context).pop(code);
                      },
                    ),
                    _ScannerOverlay(
                      animation: _scanLineController,
                      scanWindow: scanWindow,
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualController,
                    decoration: const InputDecoration(
                      labelText: 'Manual barcode',
                      prefixIcon: Icon(Icons.keyboard),
                    ),
                    onSubmitted: (_) => _submitManual(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Use barcode',
                  onPressed: _submitManual,
                  icon: const Icon(Icons.check),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submitManual() {
    final value = _manualController.text.trim();
    if (value.isNotEmpty) {
      Navigator.of(context).pop(value);
    }
  }
}

Rect _scannerWindowFor(Size size) {
  final width = math.min(math.max(size.width - 48, 220), 340).toDouble();
  const height = 170.0;
  final left = (size.width - width) / 2;
  final top = (size.height - height) / 2;
  return Rect.fromLTWH(left, top, width, height);
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.animation, required this.scanWindow});

  final Animation<double> animation;
  final Rect scanWindow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned(
          top: 18,
          left: 24,
          right: 24,
          child: _OverlayLabel(
            icon: Icons.barcode_reader,
            text: 'Align the barcode inside the frame',
            background: Colors.black.withValues(alpha: 0.62),
          ),
        ),
        Positioned.fromRect(
          rect: scanWindow,
          child: Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.primary, width: 2),
                ),
                child: const SizedBox.expand(),
              ),
              CustomPaint(
                size: scanWindow.size,
                painter: _ScannerCornerPainter(color: scheme.primary),
              ),
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Positioned(
                    left: 14,
                    right: 14,
                    top: 16 + ((scanWindow.height - 35) * animation.value),
                    child: child!,
                  );
                },
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.55),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 18,
          child: _OverlayLabel(
            icon: Icons.flash_on,
            text: 'Scanning inside frame only',
            background: Colors.black.withValues(alpha: 0.54),
          ),
        ),
      ],
    );
  }
}

class _OverlayLabel extends StatelessWidget {
  const _OverlayLabel({
    required this.icon,
    required this.text,
    required this.background,
  });

  final IconData icon;
  final String text;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerCornerPainter extends CustomPainter {
  const _ScannerCornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const length = 32.0;
    const inset = 2.0;
    final path = Path()
      ..moveTo(inset, length)
      ..lineTo(inset, inset)
      ..lineTo(length, inset)
      ..moveTo(size.width - length, inset)
      ..lineTo(size.width - inset, inset)
      ..lineTo(size.width - inset, length)
      ..moveTo(size.width - inset, size.height - length)
      ..lineTo(size.width - inset, size.height - inset)
      ..lineTo(size.width - length, size.height - inset)
      ..moveTo(length, size.height - inset)
      ..lineTo(inset, size.height - inset)
      ..lineTo(inset, size.height - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerCornerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
