import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/services/backup_crypto_service.dart';
import '../../../shared/providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final storeNameAsync = ref.watch(storeNameProvider);
    final authState = ref.watch(authControllerProvider).value;
    final appMode = ref.watch(appModeProvider);
    final isDemo = appMode == AppMode.demo;

    return Scaffold(
      appBar: showAppBar ? AppBar(title: const Text('Settings')) : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(storeNameAsync.value ?? AppConfig.appName),
                  if (isDemo) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DEMO',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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
                const ListTile(
                  leading: Icon(Icons.backup),
                  title: Text('Local backup'),
                  subtitle: Text(
                    'Create, share, or restore a FlowTrack backup file.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _BackupToolsCard(),
          if (isDemo) ...[const SizedBox(height: 12), _QaToolsCard()],
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About ${AppConfig.appName}'),
              subtitle: const Text(
                'Offline-first cash flow and credit monitoring for sari-sari stores.',
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

class _BackupToolsCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BackupToolsCard> createState() => _BackupToolsCardState();
}

class _BackupToolsCardState extends ConsumerState<_BackupToolsCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_copy),
              title: const Text('Backup and restore'),
              subtitle: const Text(
                'Backups are secure files. Save one outside this phone when possible.',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _shareBackup,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              label: const Text('Create and share backup'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _saveBackup,
              icon: const Icon(Icons.download),
              label: const Text('Save backup to Downloads'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _confirmRestore,
              icon: const Icon(Icons.restore),
              label: const Text('Restore backup'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptPassphrase(
    String title, {
    bool isRestore = false,
  }) async {
    String passphrase = '';
    String? errorText;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRestore)
                    const Text('Enter the passphrase to decrypt this backup.')
                  else
                    const Text(
                      'Create a secure passphrase (at least 8 characters). Do not lose it; it cannot be recovered.',
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Passphrase',
                      errorText: errorText,
                    ),
                    onChanged: (val) {
                      passphrase = val;
                      if (errorText != null) setState(() => errorText = null);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (passphrase.length < 8) {
                      setState(
                        () => errorText =
                            'Passphrase must be at least 8 characters',
                      );
                      return;
                    }
                    Navigator.of(context).pop(passphrase);
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveBackup() async {
    final passphrase = await _promptPassphrase('Secure Backup');
    if (passphrase == null) return;

    await _runBackupAction(() async {
      final path = await ref
          .read(backupServiceProvider)
          .saveBackupFile(passphrase);
      return path == null || path.isEmpty
          ? 'Backup saved.'
          : 'Backup saved to Downloads.';
    });
  }

  Future<void> _shareBackup() async {
    final passphrase = await _promptPassphrase('Secure Backup');
    if (passphrase == null) return;

    await _runBackupAction(() async {
      await ref.read(backupServiceProvider).shareBackupFile(passphrase);
      return 'Backup ready to share.';
    });
  }

  Future<void> _confirmRestore() async {
    final backupService = ref.read(backupServiceProvider);

    String? fileContents;
    try {
      fileContents = await backupService.pickBackupFile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }
    if (fileContents == null) return;

    bool isEncrypted = false;
    try {
      final decoded = jsonDecode(fileContents);
      if (decoded is Map<String, dynamic> &&
          decoded['format'] == BackupCryptoService.formatLabel) {
        isEncrypted = true;
      }
    } catch (_) {}

    String? passphrase;
    if (isEncrypted) {
      passphrase = await _promptPassphrase('Decrypt Backup', isRestore: true);
      if (passphrase == null) return;
    }

    await _runBackupAction(() async {
      final decoded = await backupService.validateBackupString(
        fileContents!,
        passphrase: passphrase,
      );

      final metadata = decoded['metadata'] as Map<String, dynamic>? ?? {};
      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      final createdAt = metadata['createdAt'] as String? ?? 'Unknown time';

      final productsCount = (data['products'] as List?)?.length ?? 0;
      final salesCount = (data['sales'] as List?)?.length ?? 0;

      if (!mounted) return 'Restore cancelled.';

      final restore = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Restore backup?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isEncrypted)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Legacy unencrypted backup',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Text('Created: $createdAt'),
                Text('Products: $productsCount'),
                Text('Sales: $salesCount'),
                const SizedBox(height: 16),
                const Text(
                  'Restoring will replace current products, sales, credits, expenses, settings, and history. Owner login is not changed.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Restore'),
              ),
            ],
          );
        },
      );

      if (restore != true) {
        return 'Restore cancelled.';
      }

      await backupService.restoreValidatedBackup(decoded);

      ref.invalidate(storeNameProvider);
      ref.invalidate(todayProvider);
      return 'Backup restored.';
    });
  }

  Future<void> _runBackupAction(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
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
