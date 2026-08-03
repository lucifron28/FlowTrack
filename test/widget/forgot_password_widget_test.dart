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
  @override
  Future<bool> hasOwnerAccount() async => true;

  @override
  Future<String?> ownerName() async => 'Nena';

  @override
  Future<bool> verifyPassword(String password) async => true;

  @override
  Future<List<RecoveryQuestion>> recoveryQuestions() async =>
      RecoveryQuestionCatalog.all
          .take(RecoveryQuestionCatalog.requiredCount)
          .toList(growable: false);
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('login opens the offline Forgot Password screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localAuthServiceProvider.overrideWithValue(FakeRecoveryAuthService()),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const FlowTrackApp(),
      ),
    );

    await tester.pumpAndSettle();
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
}
