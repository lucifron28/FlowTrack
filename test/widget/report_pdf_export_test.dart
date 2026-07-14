import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/features/reports/screens/reports_screen.dart';
import 'package:flowtrack/shared/providers/app_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.inMemory();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flowtrack/pdf_export'),
          null,
        );
    await database.close();
  });

  testWidgets('reports screen exposes working save PDF action and busy state', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flowtrack/pdf_export'), (
          call,
        ) async {
          calls.add(call);
          await Future.delayed(const Duration(milliseconds: 50));
          return 'content://downloads/flowtrack-report.pdf';
        });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Save PDF'), findsOneWidget);

    await tester.tap(find.text('Save PDF'));
    await tester.pump();

    // Check busy state
    final saveButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Save PDF'),
        matching: find.byType(FilledButton),
      ),
    );
    final shareButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Share PDF'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(saveButton.onPressed, isNull);
    expect(shareButton.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpAndSettle();

    expect(find.text('Report PDF saved to Downloads.'), findsOneWidget);
    expect(calls.length, 1);
    expect(calls.single.method, 'savePdf');
  });

  testWidgets('reports screen exposes working share PDF action', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flowtrack/pdf_export'), (
          call,
        ) async {
          calls.add(call);
          return 'content://downloads/flowtrack-report.pdf';
        });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Report PDF ready to share.'), findsOneWidget);
    expect(calls.length, 1);
    expect(calls.single.method, 'sharePdf');
  });
}
