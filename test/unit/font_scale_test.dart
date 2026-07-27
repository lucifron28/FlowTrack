import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/shared/providers/app_providers.dart';

void main() {
  group('AppFontScale & FontScaleController', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.inMemory();
    });

    tearDown(() async {
      await db.close();
    });

    test('AppFontScale enum has correct minimumFactors and labels', () {
      expect(AppFontScale.system.minimumFactor, isNull);
      expect(AppFontScale.large.minimumFactor, equals(1.2));
      expect(AppFontScale.extraLarge.minimumFactor, equals(1.4));

      expect(AppFontScale.system.label, equals('Device setting'));
      expect(AppFontScale.large.label, equals('Large'));
      expect(AppFontScale.extraLarge.label, equals('Extra large'));
    });

    test('FontScaleController defaults to system and persists changes', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(fontScaleProvider), equals(AppFontScale.system));

      await container.read(fontScaleProvider.notifier).setFontScale(AppFontScale.large);
      expect(container.read(fontScaleProvider), equals(AppFontScale.large));

      final savedVal = await db.getSetting('font_scale');
      expect(savedVal, equals('large'));

      final container2 = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container2.dispose);

      container2.read(fontScaleProvider);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(container2.read(fontScaleProvider), equals(AppFontScale.large));
    });

    test('FontScaleController preserves user choice when set during async load (race safety)', () async {
      await db.setSetting('font_scale', 'large');

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      // Trigger load but immediately set extraLarge before async load completes
      container.read(fontScaleProvider);
      await container.read(fontScaleProvider.notifier).setFontScale(AppFontScale.extraLarge);

      await Future.delayed(const Duration(milliseconds: 100));
      // User selection (extraLarge) must be preserved, not overwritten by old DB value (large)
      expect(container.read(fontScaleProvider), equals(AppFontScale.extraLarge));
    });
  });
}
