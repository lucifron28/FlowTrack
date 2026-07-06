import 'package:flowtrack/core/services/barcode_print_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a printable barcode PDF for store-generated products', () async {
    const label = BarcodeLabelData(
      name: 'Tingi Asukal',
      barcode: 'FT-TINGI-ASUKAL',
      sellingPrice: 500,
    );

    const service = BarcodePrintService();
    final bytes = await service.buildBarcodePdf(label);

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(service.barcodePdfFileName(label), 'tingi-asukal-barcode.pdf');
  });
}
