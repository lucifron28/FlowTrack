import 'package:intl/intl.dart';

import '../config/app_config.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _format = NumberFormat.currency(
    locale: AppConfig.defaultLocale,
    symbol: AppConfig.currency,
    decimalDigits: 2,
  );

  static String format(int centavos) {
    return _format.format(centavos / 100);
  }

  static int parseToCentavos(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    final amount = double.tryParse(cleaned);
    if (amount == null) {
      throw const FormatException('Enter a valid peso amount.');
    }
    return (amount * 100).round();
  }
}
