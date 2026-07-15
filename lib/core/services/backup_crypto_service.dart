import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class BackupCryptoService {
  const BackupCryptoService();

  static const String formatLabel = 'flowtrack-encrypted-backup';
  static const int formatVersion = 2;
  static const int kdfIterations = 210000;
  static const int saltLength = 16;
  static const int nonceLength = 12;

  Future<String> encryptBackup(String json, String passphrase) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: kdfIterations,
      bits: 256,
    );
    final aesGcm = AesGcm.with256bits();

    final salt = _randomBytes(saltLength);
    final nonce = _randomBytes(nonceLength);

    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );

    final secretBox = await aesGcm.encrypt(
      utf8.encode(json),
      secretKey: secretKey,
      nonce: nonce,
      aad: utf8.encode(formatLabel),
    );

    return jsonEncode({
      'format': formatLabel,
      'formatVersion': formatVersion,
      'kdf': {
        'name': 'pbkdf2-hmac-sha256',
        'iterations': kdfIterations,
        'salt': base64Encode(salt),
      },
      'cipher': {
        'name': 'aes-256-gcm',
        'nonce': base64Encode(nonce),
        'cipherText': base64Encode(secretBox.cipherText),
        'mac': base64Encode(secretBox.mac.bytes),
      }
    });
  }

  Future<String> decryptBackup(String envelopeJson, String passphrase) async {
    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
    } catch (e) {
      throw const FormatException('Invalid backup format.');
    }

    if (envelope['format'] != formatLabel ||
        envelope['formatVersion'] != formatVersion) {
      throw const FormatException('Unsupported backup format version.');
    }

    final kdf = envelope['kdf'] as Map<String, dynamic>?;
    final cipher = envelope['cipher'] as Map<String, dynamic>?;

    if (kdf == null ||
        kdf['name'] != 'pbkdf2-hmac-sha256' ||
        cipher == null ||
        cipher['name'] != 'aes-256-gcm') {
      throw const FormatException('Unsupported encryption parameters.');
    }

    try {
      final salt = base64Decode(kdf['salt'] as String);
      final iterations = kdf['iterations'] as int;
      final nonce = base64Decode(cipher['nonce'] as String);
      final cipherText = base64Decode(cipher['cipherText'] as String);
      final macBytes = base64Decode(cipher['mac'] as String);

      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      );

      final secretKey = await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(passphrase)),
        nonce: salt,
      );

      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );
      
      final aesGcm = AesGcm.with256bits();
      final clearText = await aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
        aad: utf8.encode(formatLabel),
      );

      return utf8.decode(clearText);
    } catch (e) {
      throw Exception('Incorrect passphrase or corrupted backup.');
    }
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
