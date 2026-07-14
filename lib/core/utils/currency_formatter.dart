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
    var s = value.trim();
    if (s.isEmpty) {
      throw const FormatException('Enter a valid peso amount.');
    }

    if (s.startsWith('₱')) {
      s = s.substring(1).trim();
    } else if (s.toLowerCase().startsWith('php')) {
      s = s.substring(3).trim();
    }

    if (s.isEmpty || s.contains('₱') || s.toLowerCase().contains('php')) {
      throw const FormatException('Enter a valid peso amount.');
    }

    final hasNoCommas = RegExp(r'^[0-9]+(?:\.[0-9]{1,2})?$');
    final hasCommas = RegExp(r'^[0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?$');
    if (!hasNoCommas.hasMatch(s) && !hasCommas.hasMatch(s)) {
      throw const FormatException('Enter a valid peso amount.');
    }

    final parts = s.split('.');
    final wholePart = parts[0].replaceAll(',', '');
    final wholePesos = int.tryParse(wholePart);
    if (wholePesos == null) {
      throw const FormatException('Enter a valid peso amount.');
    }

    int centavos = wholePesos * 100;
    if (parts.length > 1) {
      final decimalPart = parts[1];
      if (decimalPart.length == 1) {
        centavos += int.parse(decimalPart) * 10;
      } else if (decimalPart.length == 2) {
        centavos += int.parse(decimalPart);
      }
    }
    return centavos;
  }
}
