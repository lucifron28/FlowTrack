import 'dart:math';

class BarcodeService {
  BarcodeService({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  String generateStoreBarcode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final code = List.generate(
      4,
      (_) => _random.nextInt(36),
    ).map((value) => value.toRadixString(36).toUpperCase()).join();
    return 'FT-$timestamp-$code';
  }
}
