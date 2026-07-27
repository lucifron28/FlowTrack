import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    testWidgets('System scale 2.0 is preserved when AppFontScale is system', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      late BuildContext capturedContext;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                capturedContext = context;
                final scaler = MediaQuery.textScalerOf(context);
                return Text('Sample', textScaler: scaler);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaler = MediaQuery.textScalerOf(capturedContext);
      expect(scaler.scale(16.0), equals(32.0));
    });

    testWidgets('App minimum scaling applies minScaleFactor floor', (
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

      late BuildContext capturedContext;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) {
              return Consumer(
                builder: (context, ref, _) {
                  final fontScale = ref.watch(fontScaleProvider);
                  final mediaQuery = MediaQuery.of(context);
                  final minimumFactor = fontScale.minimumFactor;
                  final effectiveScaler = minimumFactor == null
                      ? mediaQuery.textScaler
                      : mediaQuery.textScaler.clamp(minScaleFactor: minimumFactor);
                  return MediaQuery(
                    data: mediaQuery.copyWith(textScaler: effectiveScaler),
                    child: child!,
                  );
                },
              );
            },
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const Text('Test');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Large setting (min scale factor 1.2)
      await container.read(fontScaleProvider.notifier).setFontScale(AppFontScale.large);
      await tester.pumpAndSettle();

      var scaler = MediaQuery.textScalerOf(capturedContext);
      expect(scaler.scale(10.0), greaterThanOrEqualTo(12.0));

      // 2. Extra Large setting (min scale factor 1.4)
      await container.read(fontScaleProvider.notifier).setFontScale(AppFontScale.extraLarge);
      await tester.pumpAndSettle();

      scaler = MediaQuery.textScalerOf(capturedContext);
      expect(scaler.scale(10.0), greaterThanOrEqualTo(14.0));
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

      // Open text size popup menu
      await tester.tap(find.text('Text size'));
      await tester.pumpAndSettle();

      expect(find.text('Extra large'), findsOneWidget);

      // Select Extra large
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
                child: MaterialApp(home: entry.value),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
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
