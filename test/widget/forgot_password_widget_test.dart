import 'dart:ui' show Size;

import 'package:flowtrack/app.dart';
import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/services/local_auth_service.dart';
import 'package:flowtrack/features/auth/domain/password_recovery.dart';
import 'package:flowtrack/features/auth/screens/auth_gate.dart';
import 'package:flowtrack/features/auth/screens/forgot_password_screen.dart';
import 'package:flowtrack/shared/providers/app_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FakeRecoveryAuthService extends LocalAuthService {
  bool recoveryConfigured = true;
  PasswordRecoveryResult recoveryResult = const PasswordRecoveryResult(
    status: PasswordRecoveryStatus.success,
  );
  Map<String, String>? recoveredAnswers;
  String? recoveredPassword;

  @override
  Future<bool> hasOwnerAccount() async => true;

  @override
  Future<String?> ownerName() async => 'Nena';

  @override
  Future<bool> verifyPassword(String password) async => true;

  @override
  Future<List<RecoveryQuestion>> recoveryQuestions() async => recoveryConfigured
      ? RecoveryQuestionCatalog.all
            .take(RecoveryQuestionCatalog.requiredCount)
            .toList(growable: false)
      : const [];

  @override
  Future<PasswordRecoveryResult> recoverPassword({
    required Map<String, String> recoveryAnswers,
    required String newPassword,
  }) async {
    recoveredAnswers = recoveryAnswers;
    recoveredPassword = newPassword;
    return recoveryResult;
  }
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  Future<FakeRecoveryAuthService> pumpApp(
    WidgetTester tester, {
    FakeRecoveryAuthService? auth,
  }) async {
    final service = auth ?? FakeRecoveryAuthService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localAuthServiceProvider.overrideWithValue(service),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const FlowTrackApp(),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets('login opens the offline Forgot Password screen', (tester) async {
    await pumpApp(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.tap(find.text('Forgot password'));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text('Forgot password'), findsOneWidget);
    expect(
      find.text('Answer your three questions, then choose a new password.'),
      findsOneWidget,
    );
  });

  testWidgets('Forgot Password completes a successful offline reset', (
    tester,
  ) async {
    final auth = await pumpApp(tester);
    await tester.tap(find.text('Forgot password'));
    await tester.pumpAndSettle();

    await tester.enterText(find.bySemanticsLabel('Answer 1'), 'Lala');
    await tester.enterText(find.bySemanticsLabel('Answer 2'), 'Bantay');
    await tester.enterText(find.bySemanticsLabel('Answer 3'), 'Mia');
    await tester.enterText(find.bySemanticsLabel('New password'), 'new-pass-1');
    await tester.enterText(
      find.bySemanticsLabel('Confirm new password'),
      'new-pass-1',
    );
    await tester.ensureVisible(find.text('Reset password'));
    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(auth.recoveredAnswers, {
      'family_nickname': 'Lala',
      'first_pet': 'Bantay',
      'childhood_best_friend': 'Mia',
    });
    expect(auth.recoveredPassword, 'new-pass-1');
  });

  testWidgets('Forgot Password explains the existing-owner setup path', (
    tester,
  ) async {
    final auth = FakeRecoveryAuthService()..recoveryConfigured = false;
    await pumpApp(tester, auth: auth);
    await tester.tap(find.text('Forgot password'));
    await tester.pumpAndSettle();

    expect(find.textContaining('log in once'), findsOneWidget);
  });

  testWidgets(
    'Forgot Password remains renderable at large text on a small phone',
    (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;

      await pumpApp(tester);
      await tester.ensureVisible(find.text('Forgot password'));
      await tester.tap(find.text('Forgot password'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    },
  );
}
