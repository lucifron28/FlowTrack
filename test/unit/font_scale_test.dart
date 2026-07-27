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

    test('AppFontScale enum has correct factor and labels', () {
      expect(AppFontScale.small.factor, equals(0.85));
      expect(AppFontScale.defaultScale.factor, equals(1.0));
      expect(AppFontScale.large.factor, equals(1.2));
      expect(AppFontScale.extraLarge.factor, equals(1.4));

      expect(AppFontScale.small.label, equals('Small'));
      expect(AppFontScale.defaultScale.label, equals('Default'));
      expect(AppFontScale.large.label, equals('Large'));
      expect(AppFontScale.extraLarge.label, equals('Extra Large'));
    });

    test('FontScaleController defaults to defaultScale and persists changes', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      // Initially defaultScale
      expect(container.read(fontScaleProvider), equals(AppFontScale.defaultScale));

      // Set to large
      container.read(fontScaleProvider.notifier).setFontScale(AppFontScale.large);
      expect(container.read(fontScaleProvider), equals(AppFontScale.large));

      // Check DB persistence
      final savedVal = await db.getSetting('font_scale');
      expect(savedVal, equals('large'));

      // New container reads persisted value
      final container2 = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container2.dispose);

      // Trigger provider build and wait for async load
      container2.read(fontScaleProvider);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(container2.read(fontScaleProvider), equals(AppFontScale.large));
    });
  });
}
