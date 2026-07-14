import 'package:flowtrack/core/utils/barcode_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeBarcode', () {
    test('removes all whitespace', () {
      expect(normalizeBarcode(' 123 456 '), '123456');
      expect(normalizeBarcode('\t123\n456\r'), '123456');
    });

    test('preserves leading zeroes', () {
      expect(normalizeBarcode('000123'), '000123');
    });

    test('preserves punctuation', () {
      expect(normalizeBarcode('FT-123-456'), 'FT-123-456');
    });

    test('preserves case', () {
      expect(normalizeBarcode('abcXYZ'), 'abcXYZ');
    });

    test('rejects empty and whitespace-only', () {
      expect(() => normalizeBarcode(''), throwsA(isA<ArgumentError>()));
      expect(() => normalizeBarcode('   '), throwsA(isA<ArgumentError>()));
    });
  });

  group('retail barcode checksum validation', () {
    test('EAN-8', () {
      expect(isSupportedRetailBarcode('96385074'), true);
      expect(hasValidRetailBarcodeChecksum('96385074'), true);

      expect(isSupportedRetailBarcode('96385075'), true);
      expect(hasValidRetailBarcodeChecksum('96385075'), false);
    });

    test('UPC-A', () {
      expect(isSupportedRetailBarcode('036000291452'), true);
      expect(hasValidRetailBarcodeChecksum('036000291452'), true);

      expect(isSupportedRetailBarcode('036000291453'), true);
      expect(hasValidRetailBarcodeChecksum('036000291453'), false);
    });

    test('EAN-13', () {
      expect(isSupportedRetailBarcode('4006381333931'), true);
      expect(hasValidRetailBarcodeChecksum('4006381333931'), true);

      expect(isSupportedRetailBarcode('4006381333932'), true);
      expect(hasValidRetailBarcodeChecksum('4006381333932'), false);
    });

    test('generic and non-supported retail barcodes are valid', () {
      // Non-numeric barcodes (e.g. Code 128)
      expect(isSupportedRetailBarcode('FT-123456'), false);
      expect(hasValidRetailBarcodeChecksum('FT-123456'), true);

      // Numeric but other lengths (e.g. 5, 10)
      expect(isSupportedRetailBarcode('12345'), false);
      expect(hasValidRetailBarcodeChecksum('12345'), true);

      expect(isSupportedRetailBarcode('1234567890'), false);
      expect(hasValidRetailBarcodeChecksum('1234567890'), true);
    });
  });
}
