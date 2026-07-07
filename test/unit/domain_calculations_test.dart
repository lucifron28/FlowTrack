import 'dart:convert';

import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/core/services/barcode_service.dart';
import 'package:flowtrack/core/services/local_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product status follows low-stock rule', () {
    expect(
      calculateProductStatus(stock: 0, lowStockLevel: 10),
      ProductStatus.outOfStock,
    );
    expect(
      calculateProductStatus(stock: 6, lowStockLevel: 10),
      ProductStatus.lowStock,
    );
    expect(
      calculateProductStatus(stock: 10, lowStockLevel: 10),
      ProductStatus.lowStock,
    );
    expect(
      calculateProductStatus(stock: 11, lowStockLevel: 10),
      ProductStatus.normal,
    );
  });

  test('sale total and cash change are calculated from cart lines', () {
    const items = [
      SaleCartLine(
        productId: 'p1',
        productName: 'Coffee',
        barcode: '111',
        unitPrice: 1200,
        quantity: 2,
      ),
      SaleCartLine(
        productId: 'p2',
        productName: 'Sugar',
        barcode: '222',
        unitPrice: 800,
        quantity: 3,
      ),
    ];

    expect(calculateSaleTotal(items), 4800);
    expect(calculateCashChange(amountReceived: 5000, total: 4800), 200);
  });

  test('store-generated barcodes are unique and use the FlowTrack prefix', () {
    final service = BarcodeService();
    final barcodes = List.generate(
      25,
      (_) => service.generateStoreBarcode(),
    ).toSet();

    expect(barcodes.length, 25);
    expect(barcodes.every((barcode) => barcode.startsWith('FT-')), isTrue);
  });

  test(
    'password hasher uses salted PBKDF2 output instead of raw SHA-256 only',
    () {
      const password = 'owner-pass';
      final encodedSaltA = base64Url.encode(utf8.encode('salt-a'));
      final encodedSaltB = base64Url.encode(utf8.encode('salt-b'));

      final hashA = PasswordHasher.pbkdf2Hash(
        password: password,
        salt: encodedSaltA,
        iterations: 2,
      );
      final hashB = PasswordHasher.pbkdf2Hash(
        password: password,
        salt: encodedSaltB,
        iterations: 2,
      );

      expect(hashA, isNot(hashB));
      expect(PasswordHasher.fixedTimeEquals(hashA, hashA), isTrue);
      expect(PasswordHasher.fixedTimeEquals(hashA, hashB), isFalse);
    },
  );
}
