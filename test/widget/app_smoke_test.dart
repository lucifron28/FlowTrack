import 'package:flowtrack/shared/widgets/currency_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('currency text renders peso amounts', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CurrencyText(12345))),
    );

    expect(find.text('₱123.45'), findsOneWidget);
  });
}
