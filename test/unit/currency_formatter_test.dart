import 'package:flowtrack/core/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyFormatter.parseToCentavos', () {
    test('accepted formats', () {
      expect(CurrencyFormatter.parseToCentavos('0'), 0);
      expect(CurrencyFormatter.parseToCentavos('1'), 100);
      expect(CurrencyFormatter.parseToCentavos('100'), 10000);
      expect(CurrencyFormatter.parseToCentavos('100.5'), 10050);
      expect(CurrencyFormatter.parseToCentavos('100.50'), 10050);
      expect(CurrencyFormatter.parseToCentavos('₱100.50'), 10050);
      expect(CurrencyFormatter.parseToCentavos('PHP 100.50'), 10050);
      expect(CurrencyFormatter.parseToCentavos('php 100.50'), 10050);
      expect(CurrencyFormatter.parseToCentavos('1,000.50'), 100050);
      expect(CurrencyFormatter.parseToCentavos('12,345,678.90'), 1234567890);
    });

    test('accepted formats with leading/trailing whitespace', () {
      expect(CurrencyFormatter.parseToCentavos('  100  '), 10000);
      expect(CurrencyFormatter.parseToCentavos(' ₱ 100.50 '), 10050);
      expect(CurrencyFormatter.parseToCentavos(' PHP   100.50 '), 10050);
    });

    test('one centavo value', () {
      expect(CurrencyFormatter.parseToCentavos('0.01'), 1);
      expect(CurrencyFormatter.parseToCentavos('₱0.01'), 1);
    });

    test('rejected formats', () {
      final invalidValues = [
        '-100',
        '+100',
        'abc50',
        '50abc',
        '1.999',
        '1..00',
        '1,00',
        '1,0000',
        '₱',
        'PHP',
        '',
        '   ',
        '₱₱100',
        'PHP PHP 100',
        '100.5,0',
        '100.50,',
        '99999999999999999999999999999999999999999', // out of integer range
      ];

      for (final value in invalidValues) {
        expect(
          () => CurrencyFormatter.parseToCentavos(value),
          throwsA(isA<FormatException>()),
          reason: 'Value "$value" should be rejected.',
        );
      }
    });
  });
}
