import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/domain/flowtrack_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/empty_state.dart';

class BarcodePrintScreen extends ConsumerWidget {
  const BarcodePrintScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Print Barcode')),
      body: FutureBuilder<Product?>(
        future: database.getProduct(productId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final product = snapshot.data;
          if (product == null) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Product not found',
              message: 'The selected product is no longer available.',
            );
          }

          if (product.barcodeType != BarcodeType.storeGenerated.dbValue) {
            return const EmptyState(
              icon: Icons.info_outline,
              title: 'Manufacturer barcode',
              message:
                  'Printable barcode sheets are for store-generated tingi items.',
            );
          }

          return _BarcodePrintPanel(product: product);
        },
      ),
    );
  }
}

class _BarcodePrintPanel extends ConsumerStatefulWidget {
  const _BarcodePrintPanel({required this.product});

  final Product product;

  @override
  ConsumerState<_BarcodePrintPanel> createState() => _BarcodePrintPanelState();
}

class _BarcodePrintPanelState extends ConsumerState<_BarcodePrintPanel> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.barcode_reader,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.product.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  widget.product.barcode,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'PDF sheet: 10 Code 128 labels',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _sharePdf,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.share),
          label: const Text('Share PDF'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _savePdf,
          icon: const Icon(Icons.save_alt),
          label: const Text('Save PDF'),
        ),
      ],
    );
  }

  Future<void> _sharePdf() async {
    await _runAction(() async {
      await ref
          .read(barcodePrintServiceProvider)
          .shareProductBarcodePdf(widget.product);
    });
  }

  Future<void> _savePdf() async {
    await _runAction(() async {
      final uri = await ref
          .read(barcodePrintServiceProvider)
          .saveProductBarcodePdf(widget.product);
      if (mounted && uri != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Barcode PDF saved.')));
      }
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
