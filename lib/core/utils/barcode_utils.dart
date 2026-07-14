String normalizeBarcode(String barcode) {
  final normalized = barcode.replaceAll(RegExp(r'\s+'), '');
  if (normalized.isEmpty) {
    throw ArgumentError('Barcode cannot be empty.');
  }
  return normalized;
}
