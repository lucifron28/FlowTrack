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
    const syncService = SyncService();
    return Scaffold(
      appBar: showAppBar ? AppBar(title: const Text('Settings')) : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront),
              title: const Text(AppConfig.appName),
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
                const ListTile(
                  leading: Icon(Icons.badge),
                  title: Text('Owner profile'),
                  subtitle: Text('Editable owner/store profile placeholder.'),
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
          return ListTile(
            leading: Icon(loaded ? Icons.check_circle : Icons.science),
            title: const Text('QA sample data'),
            subtitle: Text(
              loaded
                  ? 'Filipino sari-sari sample data is already loaded.'
                  : 'Load products, scan codes, sales, utang, and expenses for testing.',
            ),
            trailing: FilledButton.tonalIcon(
              onPressed: loaded || _loading ? null : _loadSampleData,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(loaded ? 'Loaded' : 'Load'),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadSampleData() async {
    setState(() => _loading = true);
    try {
      await ref.read(sampleDataServiceProvider).load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QA sample data loaded.')));
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
