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

  testWidgets('reports screen exposes a working save PDF action', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flowtrack/pdf_export'),
          (call) async => 'content://downloads/flowtrack-report.pdf',
        );

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
    expect(
      find.text('Placeholder pending package and layout approval.'),
      findsNothing,
    );

    await tester.tap(find.text('Save PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Report PDF saved to Downloads.'), findsOneWidget);
  });
}
