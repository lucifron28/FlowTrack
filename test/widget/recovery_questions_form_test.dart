import 'package:flowtrack/features/auth/widgets/recovery_questions_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('changing a recovery question clears its typed answer', (
    tester,
  ) async {
    final formKey = GlobalKey<RecoveryQuestionsFormState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecoveryQuestionsForm(key: formKey),
          ),
        ),
      ),
    );

    await tester.enterText(find.bySemanticsLabel('Answer 1'), 'Lala');
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('What was your first school called?').last);
    await tester.pumpAndSettle();

    expect(formKey.currentState!.answers['first_school'], isEmpty);
  });
}
