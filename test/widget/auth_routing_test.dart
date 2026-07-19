import 'dart:async';
import 'package:flowtrack/app.dart';
import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/services/local_auth_service.dart';
import 'package:flowtrack/core/constants/app_routes.dart';
import 'package:flowtrack/features/auth/screens/auth_gate.dart';
import 'package:flowtrack/features/settings/screens/settings_screen.dart';
import 'package:flowtrack/features/dashboard/screens/main_shell.dart';
import 'package:flowtrack/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

class FakeAppDatabase extends AppDatabase {
  FakeAppDatabase() : super(NativeDatabase.memory());

  Completer<void>? storeNameCompleter;
  int storeNameCallCount = 0;
  bool throwOnStoreName = false;

  @override
  Future<void> updateStoreName(String name) async {
    storeNameCallCount++;
    if (throwOnStoreName) {
      throw Exception('DB Error');
    }
    if (storeNameCompleter != null) {
      await storeNameCompleter!.future;
    }
  }
}

class FakeLocalAuthService extends LocalAuthService {
  FakeLocalAuthService({
    this.hasOwnerResult = true,
    this.ownerNameResult = 'Nena',
    this.verifyResult = true,
    this.throwOnInit = false,
    this.verifyCompleter,
    this.setupCompleter,
    this.updateCompleter,
  });

  bool hasOwnerResult;
  String? ownerNameResult;
  bool verifyResult;
  bool throwOnInit;
  Completer<bool>? verifyCompleter;
  Completer<void>? setupCompleter;
  Completer<void>? updateCompleter;
  int setupCallCount = 0;
  int updateCallCount = 0;

  @override
  Future<bool> hasOwnerAccount() async {
    if (throwOnInit) throw Exception('Secure storage failed');
    return hasOwnerResult;
  }

  @override
  Future<String?> ownerName() async {
    if (throwOnInit) throw Exception('Secure storage failed');
    return ownerNameResult;
  }

  @override
  Future<bool> verifyPassword(String password) async {
    if (verifyCompleter != null) {
      return verifyCompleter!.future;
    }
    return verifyResult;
  }

  @override
  Future<void> setupOwner({
    required String ownerName,
    required String password,
  }) async {
    setupCallCount++;
    if (setupCompleter != null) {
      await setupCompleter!.future;
    }
    hasOwnerResult = true;
    ownerNameResult = ownerName;
  }

  @override
  Future<void> updateOwnerName(String name) async {
    updateCallCount++;
    if (updateCompleter != null) {
      await updateCompleter!.future;
    }
    ownerNameResult = name;
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

  testWidgets('Test 1: unauthenticated route protection', (tester) async {
    final fakeAuth = FakeLocalAuthService(hasOwnerResult: true, verifyResult: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localAuthServiceProvider.overrideWithValue(fakeAuth),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const FlowTrackApp(),
      ),
    );

    // Starts initializing
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    // Completes initialization and redirects to login
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // Attempt direct navigation to a protected route (Settings)
    final context = tester.element(find.byType(LoginScreen));
    final router = ProviderScope.containerOf(context).read(appRouterProvider);
    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();

    // Should remain on LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('Test 2: successful login routing', (tester) async {
    final fakeAuth = FakeLocalAuthService(hasOwnerResult: true, verifyResult: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localAuthServiceProvider.overrideWithValue(fakeAuth),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const FlowTrackApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // Perform login
    await tester.enterText(find.byType(TextField), 'password');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // Should transition to MainShell and destroy LoginScreen
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('Test 3: logout invalidates protected navigation', (tester) async {
    final fakeAuth = FakeLocalAuthService(hasOwnerResult: true, verifyResult: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localAuthServiceProvider.overrideWithValue(fakeAuth),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const FlowTrackApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Log in
    await tester.enterText(find.byType(TextField), 'password');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.byType(MainShell), findsOneWidget);

    // Navigate to Settings
    final context = tester.element(find.byType(MainShell));
    final router = ProviderScope.containerOf(context).read(appRouterProvider);
    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);

    // Invoke logout using the active settings context
    final settingsContext = tester.element(find.byType(SettingsScreen));
    ProviderScope.containerOf(settingsContext).read(authControllerProvider.notifier).logout();
    await tester.pumpAndSettle();

    // Router transitions to LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);

    // Attempting back navigation to Settings does not reveal it
    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Test 4: failed or cancelled login', (tester) async {
    final fakeAuth = FakeLocalAuthService(hasOwnerResult: true);
    fakeAuth.verifyCompleter = Completer<bool>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localAuthServiceProvider.overrideWithValue(fakeAuth),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const FlowTrackApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'wrong_password');

    // Tap Login once
    await tester.tap(find.text('Login'));
    await tester.pump();

    // Verify it shows loading progress
    expect(find.text('Logging in...'), findsOneWidget);

    // Tap Login again (duplicate attempts should be disabled/ignored)
    await tester.tap(find.text('Logging in...'));
    await tester.pump();

    // Complete verify completer
    fakeAuth.verifyCompleter!.complete(false);
    await tester.pumpAndSettle();

    // Should return to Login screen with error
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Test 5: initialization failure and Retry', (tester) async {
    final fakeAuth = FakeLocalAuthService(throwOnInit: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localAuthServiceProvider.overrideWithValue(fakeAuth),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const FlowTrackApp(),
      ),
    );

    // Verify it shows loading progress initially
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    // Settle to let build throw error
    await tester.pumpAndSettle();

    // Should show retry UI and NOT login or owner setup
    expect(find.text('Failed to initialize authentication service.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(OwnerSetupScreen), findsNothing);

    // Fix the fake and trigger retry
    fakeAuth.throwOnInit = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Should land on LoginScreen now
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Failed to initialize authentication service.'), findsNothing);
  });

  testWidgets('Test 6: setup operations preserve routing and prevent duplicates', (tester) async {
    final fakeAuth = FakeLocalAuthService(
      hasOwnerResult: false,
    );
    fakeAuth.setupCompleter = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localAuthServiceProvider.overrideWithValue(fakeAuth),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const FlowTrackApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(OwnerSetupScreen), findsOneWidget);

    // Enter details
    await tester.enterText(find.bySemanticsLabel('Owner name'), 'Nena');
    await tester.enterText(find.bySemanticsLabel('Password'), 'password');
    await tester.enterText(find.bySemanticsLabel('Confirm password'), 'password');

    // Tap Create once
    await tester.tap(find.text('Create owner account'));
    await tester.pump();

    // Verify it is loading/creating
    expect(find.text('Creating...'), findsOneWidget);

    // Tap again to verify duplicate attempts are blocked
    await tester.tap(find.text('Creating...'));
    await tester.pump();

    // Complete setup
    fakeAuth.setupCompleter!.complete();
    await tester.pumpAndSettle();

    expect(fakeAuth.setupCallCount, 1);
    expect(find.byType(MainShell), findsOneWidget);
  });

  testWidgets('Test 7: async profile update completion does not override logout', (tester) async {
    final fakeAuth = FakeLocalAuthService(hasOwnerResult: true, verifyResult: true);
    fakeAuth.updateCompleter = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localAuthServiceProvider.overrideWithValue(fakeAuth),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const FlowTrackApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Log in
    await tester.enterText(find.byType(TextField), 'password');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.byType(MainShell), findsOneWidget);

    // Trigger updateOwnerName
    final container = ProviderScope.containerOf(tester.element(find.byType(MainShell)));
    final authNotifier = container.read(authControllerProvider.notifier);
    
    final updateFuture = authNotifier.updateOwnerName('New Name');
    await tester.pump(); // state is now updatingProfile

    // Trigger logout while update is in flight
    authNotifier.logout();
    await tester.pumpAndSettle();

    // State is now unauthenticated and route should redirect to login
    expect(find.byType(LoginScreen), findsOneWidget);

    // Complete the update
    fakeAuth.updateCompleter!.complete();
    await updateFuture; // waits for completion
    await tester.pumpAndSettle();

    // Verify it is STILL unauthenticated and on login screen
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
  });

  testWidgets('Test 8: owner setup failure, visible error, clean retry', (tester) async {
    final fakeAuth = FakeLocalAuthService(hasOwnerResult: false);
    fakeAuth.setupCompleter = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localAuthServiceProvider.overrideWithValue(fakeAuth),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const FlowTrackApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(OwnerSetupScreen), findsOneWidget);

    // Enter details
    await tester.enterText(find.bySemanticsLabel('Owner name'), 'Nena');
    await tester.enterText(find.bySemanticsLabel('Password'), 'password');
    await tester.enterText(find.bySemanticsLabel('Confirm password'), 'password');

    // Tap Create
    await tester.tap(find.text('Create owner account'));
    await tester.pump();

    expect(find.text('Creating...'), findsOneWidget);

    // Fail the setup call
    fakeAuth.setupCompleter!.completeError(Exception('Database error'));
    await tester.pumpAndSettle();

    // Verify: no unhandled exceptions
    expect(tester.takeException(), isNull);

    // Verify OwnerSetup remains visible and error message is displayed
    expect(find.byType(OwnerSetupScreen), findsOneWidget);
    expect(find.text('Setup failed. Please try again.'), findsOneWidget);

    // Prepare fresh setup completer for retry
    fakeAuth.setupCompleter = Completer<void>();

    // Tap Create again (Retry)
    await tester.tap(find.text('Create owner account'));
    await tester.pump();

    // Error message should be cleared when retry starts
    expect(find.text('Setup failed. Please try again.'), findsNothing);
    expect(find.text('Creating...'), findsOneWidget);

    // Succeed the second attempt
    fakeAuth.setupCompleter!.complete();
    await tester.pumpAndSettle();

    // Lands on MainShell on success
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(OwnerSetupScreen), findsNothing);
  });

  testWidgets('Test 9: profile Save becomes busy immediately, accepts one submission, and reports failure without closing', (tester) async {
    final fakeAuth = FakeLocalAuthService(hasOwnerResult: true, verifyResult: true);
    fakeAuth.updateCompleter = Completer<void>();

    final fakeDb = FakeAppDatabase();
    fakeDb.storeNameCompleter = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localAuthServiceProvider.overrideWithValue(fakeAuth),
          appDatabaseProvider.overrideWithValue(fakeDb),
        ],
        child: const FlowTrackApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Log in
    await tester.enterText(find.byType(TextField), 'password');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // Navigate to Settings
    final context = tester.element(find.byType(MainShell));
    final router = ProviderScope.containerOf(context).read(appRouterProvider);
    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();

    // Open Edit Profile Dialog
    await tester.tap(find.text('Owner profile'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Owner Profile'), findsOneWidget);

    // Edit values
    await tester.enterText(find.widgetWithText(TextField, 'Store name'), 'New Store');
    await tester.enterText(find.widgetWithText(TextField, 'Owner name'), 'New Owner');

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pump();

    // Dialog should immediately become busy (Save and Cancel disabled)
    final saveButton = tester.widget<FilledButton>(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)),
    );
    expect(saveButton.onPressed, isNull);

    final cancelButton = tester.widget<TextButton>(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextButton)),
    );
    expect(cancelButton.onPressed, isNull);

    // Tap again, verify no second call to updateOwnerName (first step)
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)),
    );
    await tester.pump();
    expect(fakeAuth.updateCallCount, 1);

    // Complete the owner name update successfully
    fakeAuth.updateCompleter!.complete();
    await tester.pump();

    // Now it should be executing the store name DB write
    final saveButton2 = tester.widget<FilledButton>(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)),
    );
    expect(saveButton2.onPressed, isNull);

    // Tap again, verify no second call to updateStoreName
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)),
    );
    await tester.pump();
    expect(fakeDb.storeNameCallCount, 1);

    // Fail the store name update call (second step)
    fakeDb.storeNameCompleter!.completeError(Exception('Database error'));
    await tester.pumpAndSettle();

    // Verify: dialog remains open and displays the partial failure error message
    expect(find.text('Edit Owner Profile'), findsOneWidget);
    expect(
      find.text('Owner profile updated, but store name failed to save: Exception: Database error'),
      findsOneWidget,
    );

    // DB and auth should be back to idle
    final saveButton3 = tester.widget<FilledButton>(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)),
    );
    expect(saveButton3.onPressed, isNotNull);

    // Verify cancel works
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextButton)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit Owner Profile'), findsNothing);

    // Clean up
    await fakeDb.close();
  });
}
