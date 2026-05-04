import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalAuthService {
  LocalAuthService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _ownerNameKey = 'owner_name';
  static const _passwordSaltKey = 'owner_password_salt';
  static const _passwordHashKey = 'owner_password_hash';
  static const _passwordAlgorithmKey = 'owner_password_algorithm';
  static const _passwordIterationsKey = 'owner_password_iterations';
  static const _passwordAlgorithm = 'pbkdf2_sha256_v1';
  static const _passwordIterations = 120000;

  final FlutterSecureStorage _storage;

  Future<bool> hasOwnerAccount() async {
    final hash = await _storage.read(key: _passwordHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<String?> ownerName() {
    return _storage.read(key: _ownerNameKey);
  }

  Future<void> setupOwner({
    required String ownerName,
    required String password,
  }) async {
    _validatePassword(password);
    await _storage.write(key: _ownerNameKey, value: ownerName.trim());
    await _storePassword(password);
  }

  Future<bool> verifyPassword(String password) async {
    final salt = await _storage.read(key: _passwordSaltKey);
    final expectedHash = await _storage.read(key: _passwordHashKey);
    final algorithm = await _storage.read(key: _passwordAlgorithmKey);
    final iterationsText = await _storage.read(key: _passwordIterationsKey);
    if (salt == null || expectedHash == null) {
      return false;
    }
    if (algorithm == _passwordAlgorithm) {
      final iterations =
          int.tryParse(iterationsText ?? '') ?? _passwordIterations;
      final hash = PasswordHasher.pbkdf2Hash(
        password: password,
        salt: salt,
        iterations: iterations,
      );
      return PasswordHasher.fixedTimeEquals(hash, expectedHash);
    }

    final legacyHash = PasswordHasher.legacySha256Hash(
      password: password,
      salt: salt,
    );
    final isLegacyMatch = PasswordHasher.fixedTimeEquals(
      legacyHash,
      expectedHash,
    );
    if (isLegacyMatch) {
      await _storePassword(password);
    }
    return isLegacyMatch;
  }

  String _newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<void> _storePassword(String password) async {
    final salt = _newSalt();
    final hash = PasswordHasher.pbkdf2Hash(
      password: password,
      salt: salt,
      iterations: _passwordIterations,
    );
    await _storage.write(key: _passwordSaltKey, value: salt);
    await _storage.write(key: _passwordHashKey, value: hash);
    await _storage.write(key: _passwordAlgorithmKey, value: _passwordAlgorithm);
    await _storage.write(
      key: _passwordIterationsKey,
      value: _passwordIterations.toString(),
    );
  }

  void _validatePassword(String password) {
    if (password.length < 4) {
      throw StateError('Password must be at least 4 characters.');
    }
  }
}

class PasswordHasher {
  const PasswordHasher._();

  static const derivedKeyLength = 32;

  static String pbkdf2Hash({
    required String password,
    required String salt,
    required int iterations,
  }) {
    if (iterations <= 0) {
      throw ArgumentError.value(iterations, 'iterations', 'Must be positive.');
    }
    final passwordBytes = utf8.encode(password);
    final saltBytes = base64Url.decode(salt);
    var block = _hmacSha256(passwordBytes, [...saltBytes, 0, 0, 0, 1]);
    final output = List<int>.from(block);
    for (var i = 1; i < iterations; i++) {
      block = _hmacSha256(passwordBytes, block);
      for (var j = 0; j < output.length; j++) {
        output[j] ^= block[j];
      }
    }
    return base64Url.encode(output.take(derivedKeyLength).toList());
  }

  static String legacySha256Hash({
    required String password,
    required String salt,
  }) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  static bool fixedTimeEquals(String left, String right) {
    final leftBytes = utf8.encode(left);
    final rightBytes = utf8.encode(right);
    var mismatch = leftBytes.length ^ rightBytes.length;
    final maxLength = max(leftBytes.length, rightBytes.length);
    for (var i = 0; i < maxLength; i++) {
      final leftByte = i < leftBytes.length ? leftBytes[i] : 0;
      final rightByte = i < rightBytes.length ? rightBytes[i] : 0;
      mismatch |= leftByte ^ rightByte;
    }
    return mismatch == 0;
  }

  static List<int> _hmacSha256(List<int> key, List<int> message) {
    return Hmac(sha256, key).convert(message).bytes;
  }
}
