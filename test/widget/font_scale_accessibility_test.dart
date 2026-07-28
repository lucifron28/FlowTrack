import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowtrack/app.dart';
import 'package:flowtrack/core/config/app_environment.dart';
import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/features/auth/screens/auth_gate.dart';
import 'package:flowtrack/features/dashboard/screens/dashboard_screen.dart';
import 'package:flowtrack/features/expenses/screens/expenses_screen.dart';
import 'package:flowtrack/features/reports/screens/reports_screen.dart';
import 'package:flowtrack/features/sales/screens/sales_screen.dart';
import 'package:flowtrack/features/settings/screens/settings_screen.dart';
import 'package:flowtrack/shared/providers/app_providers.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  group('Font Scale Accessibility Widget Tests', () {
    testWidgets('System scale 2.0 is preserved when AppFontScale is system using FlowTrackApp', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
          ],
          child: const FlowTrackApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final element = tester.element(find.byType(Scaffold).first);
      final scaler = MediaQuery.textScalerOf(element);
      expect(scaler.scale(16.0), equals(32.0));
    });

    testWidgets('Extra Large font scale on system 1.0 produces at least 1.4 using FlowTrackApp', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
      addTearDown(() {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FlowTrackApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final success = await container
          .read(fontScaleProvider.notifier)
          .setFontScale(AppFontScale.extraLarge);
      expect(success, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final element = tester.element(find.byType(Scaffold).first);
      final scaler = MediaQuery.textScalerOf(element);
      expect(scaler.scale(10.0), greaterThanOrEqualTo(14.0));
    });

    testWidgets('Failed setting write causes no uncaught exception and restores prior selection', (
      WidgetTester tester,
    ) async {
      final failingDb = _FailingAppDatabase();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(failingDb),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(fontScaleProvider), equals(AppFontScale.system));

      final success = await container
          .read(fontScaleProvider.notifier)
          .setFontScale(AppFontScale.large);

      expect(success, isFalse);
      expect(container.read(fontScaleProvider), equals(AppFontScale.system));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Pre-auth Text size control on LoginScreen updates font scale', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Text size'), findsOneWidget);

      await tester.tap(find.text('Text size'));
      await tester.pumpAndSettle();

      expect(find.text('Extra large'), findsOneWidget);

      await tester.tap(find.text('Extra large'));
      await tester.pumpAndSettle();

      expect(container.read(fontScaleProvider), equals(AppFontScale.extraLarge));
    });

    testWidgets('Pre-auth Text size control on OwnerSetupScreen works', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: OwnerSetupScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Text size'), findsOneWidget);

      await tester.tap(find.text('Text size'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();

      expect(container.read(fontScaleProvider), equals(AppFontScale.large));
    });

    testWidgets('Pre-auth Text size control on Auth Initialization Error screen works', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          authControllerProvider.overrideWith(
            () => _FakeInitializationFailedController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Text size'), findsOneWidget);

      await tester.tap(find.text('Text size'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Extra large'));
      await tester.pumpAndSettle();

      expect(container.read(fontScaleProvider), equals(AppFontScale.extraLarge));
    });
  });

  group('Narrow Viewport & 200% System Font Size Overflow Verification', () {
    final viewports = [
      const Size(320, 640),
      const Size(360, 800),
    ];

    final screens = <String, Widget>{
      'LoginScreen': const LoginScreen(),
      'OwnerSetupScreen': const OwnerSetupScreen(),
      'SettingsScreen': const SettingsScreen(),
      'DashboardScreen': const DashboardScreen(),
      'NewSaleScreen': const NewSaleScreen(),
      'ExpensesScreen': const ExpensesScreen(),
      'ReportsScreen': const ReportsScreen(),
    };

    for (final size in viewports) {
      testWidgets(
        'No overflow at viewport ${size.width}x${size.height} with 2.0 text scale',
        (WidgetTester tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = 2.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });

          for (final entry in screens.entries) {
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  appDatabaseProvider.overrideWithValue(database),
                  appModeProvider.overrideWithValue(AppMode.production),
                ],
                child: MaterialApp(
                  builder: (context, child) {
                    final mediaQuery = MediaQuery.of(context);
                    return MediaQuery(
                      data: mediaQuery.copyWith(
                        textScaler: mediaQuery.textScaler.clamp(minScaleFactor: 1.0),
                      ),
                      child: child!,
                    );
                  },
                  home: entry.value,
                ),
              ),
            );
            await tester.pumpAndSettle();
            final exc = tester.takeException();
            if (exc != null) {
              fail('Overflow/Exception on ${entry.key} at ${size.width}x${size.height}: $exc');
            }
          }
        },
      );
    }
  });
}

class _FakeInitializationFailedController extends AuthController {
  @override
  Future<AuthState> build() async {
    return const AuthState(
      status: AuthStatus.initializationFailed,
      hasOwner: false,
    );
  }
}

class _FailingAppDatabase extends AppDatabase {
  _FailingAppDatabase() : super.inMemory();

  @override
  Future<void> setSetting(String key, String value) async {
    throw Exception('Database write failure');
  }
}
