String normalizeBarcode(String barcode) {
  final normalized = barcode.replaceAll(RegExp(r'\s+'), '');
  if (normalized.isEmpty) {
    throw ArgumentError('Barcode cannot be empty.');
  }
  return normalized;
}

bool isSupportedRetailBarcode(String barcode) {
  final numericOnly = RegExp(r'^[0-9]+$');
  if (!numericOnly.hasMatch(barcode)) {
    return false;
  }
  return barcode.length == 8 || barcode.length == 12 || barcode.length == 13;
}

bool hasValidRetailBarcodeChecksum(String barcode) {
  if (!isSupportedRetailBarcode(barcode)) {
    return true;
  }
  final len = barcode.length;
  int sum = 0;
  for (int i = 0; i < len - 1; i++) {
    final digit = int.parse(barcode[i]);
    final positionFromRight = len - i - 1;
    final weight = positionFromRight % 2 == 1 ? 3 : 1;
    sum += digit * weight;
  }
  final checkDigit = (10 - (sum % 10)) % 10;
  final lastDigit = int.parse(barcode[len - 1]);
  return lastDigit == checkDigit;
}
