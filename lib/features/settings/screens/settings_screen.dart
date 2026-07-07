import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/sync_service.dart';
import '../../../shared/providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final storeNameAsync = ref.watch(storeNameProvider);
    final authState = ref.watch(authControllerProvider).value;
    const syncService = SyncService();
    return Scaffold(
      appBar: showAppBar ? AppBar(title: const Text('Settings')) : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront),
              title: Text(storeNameAsync.value ?? AppConfig.appName),
              subtitle: const Text(AppConfig.appDescription),
              trailing: const Text(AppConfig.appVersion),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (value) => _setTheme(ref, value.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge),
                  title: const Text('Owner profile'),
                  subtitle: Text(
                    authState?.ownerName != null
                        ? 'Owner: ${authState!.ownerName}'
                        : 'Editable owner/store profile placeholder.',
                  ),
                  onTap: () => _editProfile(
                    context,
                    ref,
                    authState?.ownerName,
                    storeNameAsync.value,
                  ),
                ),
                const ListTile(
                  leading: Icon(Icons.sell),
                  title: Text('Currency symbol'),
                  subtitle: Text(AppConfig.currency),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_off),
                  title: const Text('Supabase connection'),
                  subtitle: Text(syncService.currentState.label),
                ),
                const ListTile(
                  leading: Icon(Icons.backup),
                  title: Text('Database backup/export'),
                  subtitle: Text(
                    'Placeholder pending export and sync approval.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _QaToolsCard(),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About ${AppConfig.appName}'),
              subtitle: const Text(
                'Temporary app name. Rename from the central config when finalized.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    String? currentOwner,
    String? currentStore,
  ) async {
    final ownerController = TextEditingController(text: currentOwner);
    final storeController = TextEditingController(text: currentStore);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Owner Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: storeController,
              decoration: const InputDecoration(
                labelText: 'Store name',
                prefixIcon: Icon(Icons.storefront),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ownerController,
              decoration: const InputDecoration(
                labelText: 'Owner name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newStore = storeController.text.trim();
              final newOwner = ownerController.text.trim();
              if (newStore.isNotEmpty && newOwner.isNotEmpty) {
                await ref.read(appDatabaseProvider).updateStoreName(newStore);
                ref.invalidate(storeNameProvider);
                await ref
                    .read(authControllerProvider.notifier)
                    .updateOwnerName(newOwner);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _setTheme(WidgetRef ref, ThemeMode? value) {
    if (value == null) {
      return;
    }
    ref.read(themeModeProvider.notifier).setThemeMode(value);
  }
}

class _QaToolsCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_QaToolsCard> createState() => _QaToolsCardState();
}

class _QaToolsCardState extends ConsumerState<_QaToolsCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<bool>(
        future: ref.watch(sampleDataServiceProvider).isLoaded(),
        builder: (context, snapshot) {
          final loaded = snapshot.data ?? false;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(loaded ? Icons.check_circle : Icons.science),
                  title: const Text('Demo data'),
                  subtitle: Text(
                    loaded
                        ? 'Demo data is loaded. Sync to repair missing demo items or reset for a clean recording.'
                        : 'Load Filipino sari-sari products, barcode samples, sales, utang, and expenses.',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _syncSampleData,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('Sync demo data'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _confirmResetSampleData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset demo data'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _syncSampleData() async {
    await _runDemoDataAction(
      action: () => ref.read(sampleDataServiceProvider).syncDemoData(),
      successMessage: 'Demo data synced.',
    );
  }

  Future<void> _confirmResetSampleData() async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset demo data?'),
          content: const Text(
            'This clears local products, sales, credits, expenses, and stock history, then reloads the demo dataset. Owner login is not changed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (reset != true) {
      return;
    }

    await _runDemoDataAction(
      action: () => ref.read(sampleDataServiceProvider).resetDemoData(),
      successMessage: 'Demo data reset and synced.',
    );
  }

  Future<void> _runDemoDataAction({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    setState(() => _loading = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      setState(() {});
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
