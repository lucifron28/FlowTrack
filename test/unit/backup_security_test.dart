import 'dart:convert';

import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/core/services/backup_crypto_service.dart';
import 'package:flowtrack/core/services/backup_service.dart';
import 'package:flowtrack/core/services/backup_validator.dart';
import 'package:flowtrack/core/services/sample_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;
  late BackupService sourceService;
  late BackupService targetService;

  setUp(() {
    source = AppDatabase.inMemory();
    target = AppDatabase.inMemory();
    sourceService = BackupService(
      source,
      const BackupCryptoService(),
      const BackupValidator(),
    );
    targetService = BackupService(
      target,
      const BackupCryptoService(),
      const BackupValidator(),
    );
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('plaintext creation without valid passphrase is impossible', () async {
    await expectLater(
      () => sourceService.createBackupJson('short'),
      throwsA(isA<BackupException>()),
    );
  });

  test('encrypted round trip and tampering detection', () async {
    await SampleDataService(source).syncDemoData();
    await source.updateStoreName('Secure Store');
    await source.createCustomer(name: 'Secret Customer');

    final passphrase = 'my_secure_passphrase';
    final encryptedBackup =
        await sourceService.createBackupJson(passphrase);

    // Verify plaintext data is not exposed
    expect(encryptedBackup.contains('Secret Customer'), isFalse);
    expect(encryptedBackup.contains('Secure Store'), isFalse);

    // Restores with correct passphrase
    final validPayload = await targetService.validateBackupString(
        encryptedBackup,
        passphrase: passphrase);
    await targetService.restoreValidatedBackup(validPayload);
    final targetStore = await target.getSetting('store_name');
    expect(targetStore, 'Secure Store');

    // Wrong passphrase
    await expectLater(
      () => targetService.validateBackupString(encryptedBackup,
          passphrase: 'wrong_passphrase'),
      throwsA(isA<BackupException>()),
    );

    // Tampering (change one byte in cipherText)
    final map = jsonDecode(encryptedBackup) as Map<String, dynamic>;
    final cipher = map['cipher'] as Map<String, dynamic>;
    final cipherText = base64Decode(cipher['cipherText']);
    cipherText[0] ^= 0x01; // flip one bit
    cipher['cipherText'] = base64Encode(cipherText);
    final tamperedBackup = jsonEncode(map);

    await expectLater(
      () => targetService.validateBackupString(tamperedBackup,
          passphrase: passphrase),
      throwsA(isA<BackupException>()),
    );
  });

  test('invalid backup restore is atomic', () async {
    await SampleDataService(source).syncDemoData();
    await target.updateStoreName('Initial Target Store');

    final json = await sourceService.createUnencryptedBackupJsonForTest();
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;

    // Corrupt the data: add a sale item referencing a missing product
    final saleItems = (data['saleItems'] as List).cast<Map<String, dynamic>>();
    saleItems.add({
      'id': 'invalid-item',
      'saleId': 'sale-1',
      'productId': 'non-existent-product',
      'quantity': 1,
      'unitPriceSnapshot': 100,
      'costPriceSnapshot': 50,
      'productNameSnapshot': 'Ghost Product',
      'subtotal': 100,
      'createdAt': DateTime.now().toIso8601String(),
    });
    data['saleItems'] = saleItems;

    await expectLater(
      () => targetService.validateBackupString(jsonEncode(decoded)),
      throwsA(isA<BackupException>()),
    );

    // Existing target data remains unchanged
    final targetStore = await target.getSetting('store_name');
    expect(targetStore, 'Initial Target Store');
  });

  test('legacy restore and versioning', () async {
    await SampleDataService(source).syncDemoData();
    // Add product with unnormalized barcode and contact
    await source.createProduct(
      name: 'NormTest',
      barcode: '  aBc-123  ',
      barcodeType: BarcodeType.manufacturer,
      sellingPrice: 100,
      initialStock: 10,
      lowStockLevel: 5,
    );
    await source.createCustomer(name: 'NormCust', contactNumber: ' +63  917  123 4567  ');
    
    // Create legacy version 1 backup manually by omitting passphrase (test helper)
    final json = await sourceService.createUnencryptedBackupJsonForTest();
    
    // Target starts clean
    await target.updateStoreName('Initial Target Store');
    
    // Validate and restore
    final payload = await targetService.validateBackupString(json);
    await targetService.restoreValidatedBackup(payload);
    
    final products = await target.select(target.products).get();
    final normProduct = products.firstWhere((p) => p.name == 'NormTest');
    expect(normProduct.barcode, 'aBc-123'); // Case is preserved for Code 128

    final customers = await target.select(target.customers).get();
    final normCust = customers.firstWhere((c) => c.name == 'NormCust');
    expect(normCust.contactNumber, '+639171234567');

    // Create a new backup from target, must be encrypted if passphrase is provided
    final newBackup = await targetService.createBackupJson('pass1234');
    expect(newBackup.contains('"formatVersion":2'), isTrue);
  });
}
