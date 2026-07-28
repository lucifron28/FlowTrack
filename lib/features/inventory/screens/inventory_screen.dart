import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide BarcodeType;

import '../../../core/constants/app_routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/domain/flowtrack_models.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/barcode_utils.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import 'barcode_print_screen.dart';
import '../controllers/inventory_list_controller.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final InventoryListController _listController = InventoryListController();
  String _query = '';
  ProductStatus? _filter;
  ProductLifecycleFilter _lifecycleFilter = ProductLifecycleFilter.all;

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(appDatabaseProvider);

    final lifecycleDropdown = DropdownButtonFormField<ProductLifecycleFilter>(
      isExpanded: true,
      initialValue: _lifecycleFilter,
      decoration: const InputDecoration(labelText: 'Lifecycle'),
      items: ProductLifecycleFilter.values
          .map(
            (filter) => DropdownMenuItem(
              value: filter,
              child: Text(filter.label),
            ),
          )
          .toList(),
      onChanged: (value) => setState(
        () => _lifecycleFilter = value ?? ProductLifecycleFilter.all,
      ),
    );

    final statusDropdown = DropdownButtonFormField<ProductStatus?>(
      isExpanded: true,
      initialValue: _filter,
      decoration: const InputDecoration(labelText: 'Stock status'),
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
    );

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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final scale =
                        MediaQuery.textScalerOf(context).scale(14.0) / 14.0;
                    final stack = constraints.maxWidth < 420 || scale >= 1.35;

                    if (stack) {
                      return Column(
                        children: [
                          lifecycleDropdown,
                          const SizedBox(height: 8),
                          statusDropdown,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: lifecycleDropdown),
                        const SizedBox(width: 8),
                        Expanded(child: statusDropdown),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: database.watchAllProducts(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load products: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final products = _listController.filterProducts(
                  products: snapshot.data ?? [],
                  query: _query,
                  statusFilter: _filter,
                  lifecycleFilter: _lifecycleFilter,
                );
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
                    final item = products[index];
                    final product = item.product;
                    return ProductCard(
                      product: product,
                      status: item.status,
                      onTap: () => context.pushNamed(
                        AppRoutes.productDetailsName,
                        pathParameters: {'productId': product.id},
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
        onPressed: () => context.pushNamed(AppRoutes.addProductName),
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
    final statusColor = switch (status) {
      ProductStatus.normal => theme.colorScheme.primary,
      ProductStatus.lowStock => Colors.orange.shade700,
      ProductStatus.outOfStock => theme.colorScheme.error,
    };

    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final highTextScale = textScale > 1.35;

    final badges = Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _StatusBadge(label: status.label, color: statusColor),
        if (!product.isActive)
          _StatusBadge(
            label: 'Archived',
            color: theme.colorScheme.outline,
          ),
      ],
    );

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: highTextScale
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Barcode: ${product.barcode}',
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
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Price: ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        CurrencyText(
                          product.sellingPrice,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    badges,
                  ],
                )
              : Row(
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
                    Flexible(
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
                          badges,
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
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
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Barcode is required.';
                }
                String normalized;
                try {
                  normalized = normalizeBarcode(value);
                } on ArgumentError {
                  return 'Barcode cannot be empty.';
                }
                if (_barcodeType == BarcodeType.manufacturer) {
                  if (isSupportedRetailBarcode(normalized) &&
                      !hasValidRetailBarcodeChecksum(normalized)) {
                    return 'Invalid EAN/UPC check digit.';
                  }
                }
                return null;
              },
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
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load product details: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
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
                      if (!product.isActive) ...[
                        const SizedBox(height: 4),
                        _StatusBadge(
                          label: 'Archived',
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ],
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Selling price: '),
                          CurrencyText(product.sellingPrice),
                        ],
                      ),
                      if (product.costPrice != null)
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
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
                onPressed: () => context.pushNamed(
                  AppRoutes.addStockName,
                  pathParameters: {'productId': product.id},
                ),
                icon: const Icon(Icons.add_box),
                label: const Text('Add Stock'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.pushNamed(
                  AppRoutes.editProductName,
                  pathParameters: {'productId': product.id},
                  extra: product,
                ),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Product'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.pushNamed(
                  AppRoutes.adjustStockName,
                  pathParameters: {'productId': product.id},
                  extra: product,
                ),
                icon: const Icon(Icons.tune),
                label: const Text('Adjust Stock'),
              ),
              if (product.barcodeType == BarcodeType.storeGenerated.dbValue)
                OutlinedButton.icon(
                  onPressed: () => context.pushNamed(
                    AppRoutes.barcodePrintName,
                    pathParameters: {'productId': product.id},
                  ),
                  icon: const Icon(Icons.print),
                  label: const Text('Print Barcode Sheet'),
                ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final scale =
                      MediaQuery.textScalerOf(context).scale(14.0) / 14.0;
                  final stack = constraints.maxWidth < 420 || scale >= 1.35;

                  final titleWidget = Text(
                    'Stock History',
                    style: Theme.of(context).textTheme.titleMedium,
                  );
                  final buttonWidget = TextButton.icon(
                    onPressed: () => context.pushNamed(
                      AppRoutes.stockHistoryName,
                      pathParameters: {'productId': product.id},
                    ),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('View full history'),
                  );

                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleWidget,
                        const SizedBox(height: 4),
                        buttonWidget,
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      titleWidget,
                      buttonWidget,
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<StockHistoryEntry>>(
                stream: database.watchStockHistoryPreview(product.id, limit: 5),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      'Failed to load stock history preview.',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    );
                  }
                  final entries = snapshot.data ?? [];
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (entries.isEmpty) {
                    return const Text('No stock history yet.');
                  }
                  return Column(
                    children: entries
                        .map((entry) => StockHistoryTile(entry: entry))
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
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Stock')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                prefixIcon: Icon(Icons.add_box),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter quantity';
                }
                final qty = int.tryParse(value.trim());
                if (qty == null || qty <= 0) {
                  return 'Enter a positive integer';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Stock'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final quantity = int.parse(_quantityController.text.trim());
    final trimmedNotes = _notesController.text.trim();
    final notes = trimmedNotes.isEmpty ? null : trimmedNotes;

    try {
      await ref.read(appDatabaseProvider).addStock(
            productId: widget.productId,
            quantity: quantity,
            notes: notes,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
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
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  bool _add = true;
  String _reason = 'Correction';
  bool _isSaving = false;
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
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adjust Stock')),
      body: Form(
        key: _formKey,
        child: ListView(
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
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter quantity';
                }
                final qty = int.tryParse(value.trim());
                if (qty == null || qty <= 0) {
                  return 'Enter a positive integer';
                }
                return null;
              },
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: _reason == 'Others'
                    ? 'Notes (required for Others)'
                    : 'Notes (optional)',
              ),
              validator: (value) {
                if (_reason == 'Others' &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Notes required when reason is Others';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Adjustment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (!_add) {
        final quantity = int.parse(_quantityController.text.trim());
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm deduction'),
            content: Text(
              'Deduct $quantity units from ${widget.product.name}?\nReason: $_reason',
            ),
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

        if (!mounted) return;
        if (confirm != true) return;
      }

      final quantity = int.parse(_quantityController.text.trim());
      final trimmedNotes = _notesController.text.trim();
      final notes = trimmedNotes.isEmpty ? null : trimmedNotes;

      await ref.read(appDatabaseProvider).adjustStock(
            productId: widget.product.id,
            quantity: quantity,
            add: _add,
            reason: _reason,
            notes: notes,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
                        HapticFeedback.mediumImpact();
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

class StockHistoryTile extends StatelessWidget {
  const StockHistoryTile({super.key, required this.entry});

  final StockHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final movement = entry.movement;
    final theme = Theme.of(context);
    final isInbound = isStockMovementInbound(movement.movementType);
    final signedQty =
        formatSignedQuantity(movement.movementType, movement.quantity);
    final label = formatStockMovementLabel(movement.movementType);
    final dateStr =
        DateFormat('MMM d, yyyy • h:mm a').format(movement.createdAt);

    final String? saleText;
    final VoidCallback? onSaleTap;
    if (movement.relatedSaleId != null) {
      if (entry.isSaleAvailable) {
        final saleNum = entry.relatedSaleNumber ?? movement.relatedSaleId!;
        saleText = 'Sale #$saleNum';
        onSaleTap = () => context.pushNamed(
              AppRoutes.saleDetailsName,
              pathParameters: {'saleId': movement.relatedSaleId!},
            );
      } else {
        saleText = 'Related sale unavailable';
        onSaleTap = null;
      }
    } else {
      saleText = null;
      onSaleTap = null;
    }

    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final highTextScale = textScale > 1.35;

    final qtyWidget = Text(
      signedQty,
      style: theme.textTheme.titleMedium?.copyWith(
        color: isInbound ? Colors.green.shade700 : theme.colorScheme.error,
        fontWeight: FontWeight.bold,
      ),
    );

    final detailsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          dateStr,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (movement.reason != null && movement.reason!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Reason: ${movement.reason}',
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (movement.notes != null && movement.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Notes: ${movement.notes}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (saleText != null) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: onSaleTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 16,
                  color: onSaleTap != null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    saleText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onSaleTap != null
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      decoration: onSaleTap != null
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      fontWeight: onSaleTap != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: highTextScale
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: detailsColumn),
                      const SizedBox(width: 8),
                      qtyWidget,
                    ],
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: detailsColumn),
                  const SizedBox(width: 12),
                  qtyWidget,
                ],
              ),
      ),
    );
  }
}

class StockHistoryScreen extends ConsumerStatefulWidget {
  const StockHistoryScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<StockHistoryScreen> createState() =>
      _StockHistoryScreenState();
}

class _StockHistoryScreenState extends ConsumerState<StockHistoryScreen> {
  static const _pageSize = 50;
  final List<StockHistoryEntry> _entries = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _loadMoreError;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _loadMoreError = null;
    });
    try {
      final db = ref.read(appDatabaseProvider);
      final page = await db.getStockHistoryPage(
        widget.productId,
        limit: _pageSize,
        offset: 0,
      );
      if (mounted) {
        setState(() {
          _entries.clear();
          _entries.addAll(page);
          _hasMore = page.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });
    try {
      final db = ref.read(appDatabaseProvider);
      final page = await db.getStockHistoryPage(
        widget.productId,
        limit: _pageSize,
        offset: _entries.length,
      );
      if (mounted) {
        setState(() {
          _entries.addAll(page);
          _hasMore = page.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadMoreError = e.toString();
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock History')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadInitial,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No stock history',
        message: 'No stock movements recorded for this product.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _entries.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : _loadMoreError != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Failed to load older history: $_loadMoreError',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _loadMore,
                              child: const Text('Retry'),
                            ),
                          ],
                        )
                      : OutlinedButton(
                          onPressed: _loadMore,
                          child: const Text('Load More'),
                        ),
            ),
          );
        }
        final entry = _entries[index];
        return StockHistoryTile(entry: entry);
      },
    );
  }
}
