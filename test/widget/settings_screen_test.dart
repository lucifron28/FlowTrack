import 'package:flowtrack/core/config/app_environment.dart';
import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/features/settings/screens/settings_screen.dart';
import 'package:flowtrack/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets(
    'SettingsScreen in production mode hides QA/demo tools and badge',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            appModeProvider.overrideWithValue(AppMode.production),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Theme and Profile settings are visible
      expect(find.text('Theme mode'), findsOneWidget);
      expect(find.text('Owner profile'), findsOneWidget);
      expect(find.text('Local backup'), findsOneWidget);

      // Verify demo tools are absent
      expect(find.text('Demo data'), findsNothing);
      expect(find.text('Sync demo data'), findsNothing);
      expect(find.text('Reset demo data'), findsNothing);

      // Verify DEMO badge is absent
      expect(find.text('DEMO'), findsNothing);
    },
  );

  testWidgets('SettingsScreen in demo mode shows QA/demo tools and badge', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          appModeProvider.overrideWithValue(AppMode.demo),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Theme and Profile settings are visible
    expect(find.text('Theme mode'), findsOneWidget);

    // Verify demo tools are present
    expect(find.text('Demo data'), findsOneWidget);
    expect(find.text('Sync demo data'), findsOneWidget);
    expect(find.text('Reset demo data'), findsOneWidget);

    // Verify DEMO badge is present
    expect(find.text('DEMO'), findsOneWidget);
  });
}
