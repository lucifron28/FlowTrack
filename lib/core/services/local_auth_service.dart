import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/password_recovery.dart';

abstract class SecureStorageAdapter {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});
}

class FlutterSecureStorageAdapter implements SecureStorageAdapter {
  const FlutterSecureStorageAdapter(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

class LocalAuthService {
  LocalAuthService({
    FlutterSecureStorage? storage,
    SecureStorageAdapter? adapter,
    int passwordIterations = _passwordIterations,
  }) : _storage =
           adapter ??
           FlutterSecureStorageAdapter(storage ?? const FlutterSecureStorage()),
       _hashIterations = passwordIterations {
    if (passwordIterations <= 0) {
      throw ArgumentError.value(
        passwordIterations,
        'passwordIterations',
        'Must be positive.',
      );
    }
  }

  static const _ownerNameKey = 'owner_name';
  static const _passwordBundleKey = 'owner_password_bundle_v2';
  static const _passwordSaltKey = 'owner_password_salt';
  static const _passwordHashKey = 'owner_password_hash';
  static const _passwordAlgorithmKey = 'owner_password_algorithm';
  static const _passwordIterationsKey = 'owner_password_iterations';
  static const _passwordAlgorithm = 'pbkdf2_sha256_v1';
  static const _passwordIterations = 120000;
  static const _recoveryConfigKey = 'owner_recovery_questions_v1';
  static const _recoveryAttemptsKey = 'owner_recovery_attempts';
  static const _recoveryLockedUntilKey = 'owner_recovery_locked_until';
  static const _recoveryMaxAttempts = 5;
  static const _recoveryLockout = Duration(minutes: 15);

  final SecureStorageAdapter _storage;
  final int _hashIterations;

  Future<bool> hasOwnerAccount() async {
    final bundle = await _readPasswordBundle();
    if (bundle != null) {
      return true;
    }
    final hash = await _storage.read(key: _passwordHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<String?> ownerName() {
    return _storage.read(key: _ownerNameKey);
  }

  Future<void> updateOwnerName(String name) async {
    await _storage.write(key: _ownerNameKey, value: name.trim());
  }

  Future<void> setupOwner({
    required String ownerName,
    required String password,
    required Map<String, String> recoveryAnswers,
  }) async {
    _validatePassword(password);
    final recoveryConfig = _buildRecoveryConfig(recoveryAnswers);
    await _storage.write(key: _ownerNameKey, value: ownerName.trim());
    await _storePassword(password);
    await _writeRecoveryConfig(recoveryConfig);
    await _clearRecoveryFailures();
  }

  Future<bool> verifyPassword(String password) async {
    final bundle = await _readPasswordBundle();
    if (bundle != null) {
      final hash = PasswordHasher.pbkdf2Hash(
        password: password,
        salt: bundle.salt,
        iterations: bundle.iterations,
      );
      return PasswordHasher.fixedTimeEquals(hash, bundle.hash);
    }

    final salt = await _storage.read(key: _passwordSaltKey);
    final expectedHash = await _storage.read(key: _passwordHashKey);
    final algorithm = await _storage.read(key: _passwordAlgorithmKey);
    final iterationsText = await _storage.read(key: _passwordIterationsKey);
    if (salt == null || expectedHash == null) {
      return false;
    }
    if (algorithm == _passwordAlgorithm) {
      final iterations = int.tryParse(iterationsText ?? '') ?? _hashIterations;
      final hash = PasswordHasher.pbkdf2Hash(
        password: password,
        salt: salt,
        iterations: iterations,
      );
      final isMatch = PasswordHasher.fixedTimeEquals(hash, expectedHash);
      if (isMatch) {
        await _storePassword(password);
      }
      return isMatch;
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

  Future<bool> hasRecoveryQuestions() async {
    final questions = await recoveryQuestions();
    return questions.length == RecoveryQuestionCatalog.requiredCount;
  }

  Future<List<RecoveryQuestion>> recoveryQuestions() async {
    final config = await _readRecoveryConfig();
    if (config == null) {
      return const [];
    }

    final questions = <RecoveryQuestion>[];
    for (final id in config.questionIds) {
      try {
        questions.add(RecoveryQuestionCatalog.byId(id));
      } on StateError {
        return const [];
      }
    }
    return questions;
  }

  Future<void> updateRecoveryQuestions({
    required String currentPassword,
    required Map<String, String> recoveryAnswers,
  }) async {
    if (!await verifyPassword(currentPassword)) {
      throw StateError('Current password is incorrect.');
    }
    final config = _buildRecoveryConfig(recoveryAnswers);
    await _writeRecoveryConfig(config);
    await _clearRecoveryFailures();
  }

  Future<PasswordRecoveryResult> recoverPassword({
    required Map<String, String> recoveryAnswers,
    required String newPassword,
  }) async {
    _validatePassword(newPassword);

    final now = DateTime.now();
    final lockedUntil = await _readRecoveryLockout();
    if (lockedUntil != null && now.isBefore(lockedUntil)) {
      return PasswordRecoveryResult(
        status: PasswordRecoveryStatus.lockedOut,
        lockedUntil: lockedUntil,
      );
    }
    if (lockedUntil != null) {
      await _clearRecoveryFailures();
    }

    final config = await _readRecoveryConfig();
    if (config == null) {
      return const PasswordRecoveryResult(
        status: PasswordRecoveryStatus.notConfigured,
      );
    }

    if (!_recoveryAnswersMatch(config, recoveryAnswers)) {
      return _recordRecoveryFailure(now);
    }

    await _storePassword(newPassword);
    await _clearRecoveryFailures();
    return const PasswordRecoveryResult(status: PasswordRecoveryStatus.success);
  }

  String _newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<void> _storePassword(String password) async {
    final salt = _newSalt();
    final record = _PasswordRecord(
      salt: salt,
      hash: PasswordHasher.pbkdf2Hash(
        password: password,
        salt: salt,
        iterations: _hashIterations,
      ),
      iterations: _hashIterations,
    );
    await _storage.write(
      key: _passwordBundleKey,
      value: jsonEncode(record.toJson()),
    );

    // The bundle is authoritative. Legacy keys remain readable for old
    // installs if cleanup is unavailable on a particular platform.
    for (final key in [
      _passwordSaltKey,
      _passwordHashKey,
      _passwordAlgorithmKey,
      _passwordIterationsKey,
    ]) {
      try {
        await _storage.delete(key: key);
      } catch (_) {
        // A successful bundle write must not make login fail during cleanup.
      }
    }
  }

  Future<_PasswordRecord?> _readPasswordBundle() async {
    final encoded = await _storage.read(key: _passwordBundleKey);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return null;
      }
      return _PasswordRecord.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  _RecoveryConfig _buildRecoveryConfig(Map<String, String> answers) {
    if (answers.length != RecoveryQuestionCatalog.requiredCount) {
      throw StateError('Choose three recovery questions.');
    }

    final records = <_RecoveryAnswerRecord>[];
    for (final questionId in answers.keys) {
      try {
        RecoveryQuestionCatalog.byId(questionId);
      } on StateError {
        throw StateError('Choose valid recovery questions.');
      }

      final normalizedAnswer = RecoveryQuestionCatalog.normalizeAnswer(
        answers[questionId] ?? '',
      );
      if (normalizedAnswer.isEmpty) {
        throw StateError('Recovery answers cannot be blank.');
      }

      final salt = _newSalt();
      records.add(
        _RecoveryAnswerRecord(
          questionId: questionId,
          salt: salt,
          hash: PasswordHasher.pbkdf2Hash(
            password: normalizedAnswer,
            salt: salt,
            iterations: _hashIterations,
          ),
        ),
      );
    }

    return _RecoveryConfig(records: records);
  }

  Future<void> _writeRecoveryConfig(_RecoveryConfig config) async {
    await _storage.write(
      key: _recoveryConfigKey,
      value: jsonEncode(config.toJson()),
    );
  }

  Future<_RecoveryConfig?> _readRecoveryConfig() async {
    final encoded = await _storage.read(key: _recoveryConfigKey);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return null;
      }
      return _RecoveryConfig.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  bool _recoveryAnswersMatch(
    _RecoveryConfig config,
    Map<String, String> answers,
  ) {
    if (answers.length != config.records.length) {
      return false;
    }
    for (final record in config.records) {
      final answer = answers[record.questionId];
      if (answer == null) {
        return false;
      }
      final normalizedAnswer = RecoveryQuestionCatalog.normalizeAnswer(answer);
      if (normalizedAnswer.isEmpty) {
        return false;
      }
      final hash = PasswordHasher.pbkdf2Hash(
        password: normalizedAnswer,
        salt: record.salt,
        iterations: _hashIterations,
      );
      if (!PasswordHasher.fixedTimeEquals(hash, record.hash)) {
        return false;
      }
    }
    return true;
  }

  Future<PasswordRecoveryResult> _recordRecoveryFailure(DateTime now) async {
    final attemptsText = await _storage.read(key: _recoveryAttemptsKey);
    final attempts = (int.tryParse(attemptsText ?? '') ?? 0) + 1;
    if (attempts >= _recoveryMaxAttempts) {
      final lockedUntil = now.add(_recoveryLockout);
      await _storage.write(
        key: _recoveryAttemptsKey,
        value: attempts.toString(),
      );
      await _storage.write(
        key: _recoveryLockedUntilKey,
        value: lockedUntil.millisecondsSinceEpoch.toString(),
      );
      return PasswordRecoveryResult(
        status: PasswordRecoveryStatus.lockedOut,
        lockedUntil: lockedUntil,
      );
    }

    await _storage.write(key: _recoveryAttemptsKey, value: attempts.toString());
    return const PasswordRecoveryResult(
      status: PasswordRecoveryStatus.invalidAnswers,
    );
  }

  Future<DateTime?> _readRecoveryLockout() async {
    final encoded = await _storage.read(key: _recoveryLockedUntilKey);
    final milliseconds = int.tryParse(encoded ?? '');
    if (milliseconds == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  Future<void> _clearRecoveryFailures() async {
    try {
      await _storage.delete(key: _recoveryAttemptsKey);
      await _storage.delete(key: _recoveryLockedUntilKey);
    } catch (_) {
      // Recovery succeeded; cleanup failure should not undo the new password.
    }
  }

  void _validatePassword(String password) {
    if (password.length < 4) {
      throw StateError('Password must be at least 4 characters.');
    }
  }
}

class _PasswordRecord {
  const _PasswordRecord({
    required this.salt,
    required this.hash,
    required this.iterations,
  });

  final String salt;
  final String hash;
  final int iterations;

  Map<String, dynamic> toJson() => {
    'algorithm': 'pbkdf2_sha256_v1',
    'salt': salt,
    'hash': hash,
    'iterations': iterations,
  };

  factory _PasswordRecord.fromJson(Map<String, dynamic> json) {
    final algorithm = json['algorithm'];
    final salt = json['salt'];
    final hash = json['hash'];
    final iterations = json['iterations'];
    if (algorithm != 'pbkdf2_sha256_v1' ||
        salt is! String ||
        hash is! String ||
        iterations is! int ||
        iterations <= 0) {
      throw const FormatException('Invalid password bundle.');
    }
    return _PasswordRecord(salt: salt, hash: hash, iterations: iterations);
  }
}

class _RecoveryAnswerRecord {
  const _RecoveryAnswerRecord({
    required this.questionId,
    required this.salt,
    required this.hash,
  });

  final String questionId;
  final String salt;
  final String hash;

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'salt': salt,
    'hash': hash,
  };

  factory _RecoveryAnswerRecord.fromJson(Map<String, dynamic> json) {
    final questionId = json['questionId'];
    final salt = json['salt'];
    final hash = json['hash'];
    if (questionId is! String || salt is! String || hash is! String) {
      throw const FormatException('Invalid recovery answer record.');
    }
    RecoveryQuestionCatalog.byId(questionId);
    return _RecoveryAnswerRecord(
      questionId: questionId,
      salt: salt,
      hash: hash,
    );
  }
}

class _RecoveryConfig {
  const _RecoveryConfig({required this.records});

  final List<_RecoveryAnswerRecord> records;

  List<String> get questionIds =>
      records.map((record) => record.questionId).toList(growable: false);

  Map<String, dynamic> toJson() => {
    'version': 1,
    'records': records.map((record) => record.toJson()).toList(),
  };

  factory _RecoveryConfig.fromJson(Map<String, dynamic> json) {
    final records = json['records'];
    if (records is! List ||
        records.length != RecoveryQuestionCatalog.requiredCount) {
      throw const FormatException('Invalid recovery configuration.');
    }
    final parsed = records
        .map((record) {
          if (record is! Map) {
            throw const FormatException('Invalid recovery answer record.');
          }
          return _RecoveryAnswerRecord.fromJson(
            Map<String, dynamic>.from(record),
          );
        })
        .toList(growable: false);
    if (parsed.map((record) => record.questionId).toSet().length !=
        parsed.length) {
      throw const FormatException('Duplicate recovery questions.');
    }
    return _RecoveryConfig(records: parsed);
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
