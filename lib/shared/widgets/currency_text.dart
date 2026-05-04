import 'package:flutter/material.dart';

import '../../core/utils/currency_formatter.dart';

class CurrencyText extends StatelessWidget {
  const CurrencyText(this.amount, {super.key, this.style, this.textAlign});

  final int amount;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      CurrencyFormatter.format(amount),
      style: style,
      textAlign: textAlign,
    );
  }
}
