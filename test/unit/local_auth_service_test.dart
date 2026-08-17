import 'dart:convert';

import 'package:flowtrack/core/services/local_auth_service.dart';
import 'package:flowtrack/features/auth/domain/password_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

class MemorySecureStorage implements SecureStorageAdapter {
  final values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

class FailingWriteStorage extends MemorySecureStorage {
  FailingWriteStorage(this.failingKey);

  final String failingKey;

  @override
  Future<void> write({required String key, required String value}) async {
    if (key == failingKey) {
      throw StateError('Secure storage is unavailable.');
    }
    await super.write(key: key, value: value);
  }
}

void main() {
  const answers = {
    'family_nickname': 'Lala',
    'first_pet': 'Bantay',
    'childhood_best_friend': 'Mia',
  };

  late MemorySecureStorage storage;
  late LocalAuthService service;

  setUp(() {
    storage = MemorySecureStorage();
    service = LocalAuthService(adapter: storage, passwordIterations: 2);
  });

  test('stores recovery answers as salted hashes', () async {
    await service.setupOwner(
      ownerName: 'Nena',
      password: 'old-pass',
      recoveryAnswers: answers,
    );

    final encoded = storage.values['owner_recovery_questions_v1'];
    expect(encoded, isNotNull);
    expect(encoded, isNot(contains('Lala')));
    expect(encoded, isNot(contains('Bantay')));

    final records =
        (jsonDecode(encoded!) as Map<String, dynamic>)['records']
            as List<dynamic>;
    expect(records, hasLength(3));
    expect(
      records.map((record) => (record as Map<String, dynamic>)['salt']).toSet(),
      hasLength(3),
    );
    expect(
      records.every(
        (record) =>
            (record as Map<String, dynamic>)['algorithm'] == 'pbkdf2_sha256_v1',
      ),
      isTrue,
    );
    expect(
      records.every(
        (record) => (record as Map<String, dynamic>)['iterations'] == 2,
      ),
      isTrue,
    );

    final serviceWithDifferentDefault = LocalAuthService(
      adapter: storage,
      passwordIterations: 3,
    );
    final result = await serviceWithDifferentDefault.recoverPassword(
      recoveryAnswers: answers,
      newPassword: 'new-pass',
    );
    expect(result.status, PasswordRecoveryStatus.success);
  });

  test('a failed first-run password write leaves no owner account', () async {
    final failingStorage = FailingWriteStorage('owner_password_bundle_v2');
    final failingService = LocalAuthService(
      adapter: failingStorage,
      passwordIterations: 2,
    );

    await expectLater(
      failingService.setupOwner(
        ownerName: 'Nena',
        password: 'old-pass',
        recoveryAnswers: answers,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await failingService.hasOwnerAccount(), isFalse);
    expect(await failingService.ownerName(), isNull);
    expect(await failingService.recoveryQuestions(), isEmpty);
  });

  test('a failed recovery write leaves the account uncommitted', () async {
    final failingStorage = FailingWriteStorage('owner_recovery_questions_v1');
    final failingService = LocalAuthService(
      adapter: failingStorage,
      passwordIterations: 2,
    );

    await expectLater(
      failingService.setupOwner(
        ownerName: 'Nena',
        password: 'old-pass',
        recoveryAnswers: answers,
      ),
      throwsA(isA<StateError>()),
    );

    expect(failingStorage.values, isEmpty);
    expect(await failingService.hasOwnerAccount(), isFalse);
  });

  test('a malformed modern password bundle fails closed', () async {
    storage.values['owner_password_bundle_v2'] = '{not-json';

    await expectLater(
      () => service.hasOwnerAccount(),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      () => service.verifyPassword('old-pass'),
      throwsA(isA<FormatException>()),
    );
  });

  test('normalizes easy answer differences and resets the password', () async {
    await service.setupOwner(
      ownerName: 'Nena',
      password: 'old-pass',
      recoveryAnswers: answers,
    );

    final result = await service.recoverPassword(
      recoveryAnswers: const {
        'family_nickname': '  lala  ',
        'first_pet': 'BANTAY',
        'childhood_best_friend': 'Mia',
      },
      newPassword: 'new-pass',
    );

    expect(result.status, PasswordRecoveryStatus.success);
    expect(await service.verifyPassword('old-pass'), isFalse);
    expect(await service.verifyPassword('new-pass'), isTrue);
  });

  test(
    'wrong answers do not change the password and lock after five tries',
    () async {
      await service.setupOwner(
        ownerName: 'Nena',
        password: 'old-pass',
        recoveryAnswers: answers,
      );

      for (var attempt = 1; attempt <= 5; attempt++) {
        final result = await service.recoverPassword(
          recoveryAnswers: const {
            'family_nickname': 'wrong',
            'first_pet': 'wrong',
            'childhood_best_friend': 'wrong',
          },
          newPassword: 'new-pass',
        );
        expect(
          result.status,
          attempt == 5
              ? PasswordRecoveryStatus.lockedOut
              : PasswordRecoveryStatus.invalidAnswers,
        );
      }

      final lockedResult = await service.recoverPassword(
        recoveryAnswers: answers,
        newPassword: 'new-pass',
      );
      expect(lockedResult.status, PasswordRecoveryStatus.lockedOut);
      expect(await service.verifyPassword('old-pass'), isTrue);
    },
  );

  test('evaluates every recovery answer before returning a mismatch', () async {
    var hashCalls = 0;
    final countingService = LocalAuthService(
      adapter: storage,
      passwordIterations: 2,
      hashFunction:
          ({
            required String password,
            required String salt,
            required int iterations,
          }) {
            hashCalls++;
            final bytes = utf8.encode('$password|$salt|$iterations');
            return base64Url.encode(
              List<int>.generate(
                PasswordHasher.derivedKeyLength,
                (index) => index < bytes.length ? bytes[index] : 0,
              ),
            );
          },
    );

    await countingService.setupOwner(
      ownerName: 'Nena',
      password: 'old-pass',
      recoveryAnswers: answers,
    );
    hashCalls = 0;

    final result = await countingService.recoverPassword(
      recoveryAnswers: const {
        'family_nickname': 'wrong',
        'first_pet': 'wrong',
        'childhood_best_friend': 'wrong',
      },
      newPassword: 'new-pass',
    );

    expect(result.status, PasswordRecoveryStatus.invalidAnswers);
    expect(hashCalls, 3);
  });

  test('recovery lockout expires using the injected clock', () async {
    var now = DateTime(2026, 1, 1);
    final clockedService = LocalAuthService(
      adapter: storage,
      passwordIterations: 2,
      clock: () => now,
    );
    await clockedService.setupOwner(
      ownerName: 'Nena',
      password: 'old-pass',
      recoveryAnswers: answers,
    );

    for (var attempt = 0; attempt < 5; attempt++) {
      await clockedService.recoverPassword(
        recoveryAnswers: const {
          'family_nickname': 'wrong',
          'first_pet': 'wrong',
          'childhood_best_friend': 'wrong',
        },
        newPassword: 'new-pass',
      );
    }

    now = now.add(const Duration(minutes: 16));
    final result = await clockedService.recoverPassword(
      recoveryAnswers: answers,
      newPassword: 'new-pass',
    );
    expect(result.status, PasswordRecoveryStatus.success);
  });

  test('new and reset passwords require eight characters', () async {
    await expectLater(
      service.setupOwner(
        ownerName: 'Nena',
        password: '1234567',
        recoveryAnswers: answers,
      ),
      throwsA(isA<StateError>()),
    );

    await service.setupOwner(
      ownerName: 'Nena',
      password: 'old-pass',
      recoveryAnswers: answers,
    );
    await expectLater(
      service.recoverPassword(recoveryAnswers: answers, newPassword: '1234567'),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'existing legacy passwords remain compatible with the new policy',
    () async {
      const legacyPassword = '1234';
      const legacySalt = 'legacy-salt';
      storage.values['owner_password_salt'] = legacySalt;
      storage.values['owner_password_hash'] = PasswordHasher.legacySha256Hash(
        password: legacyPassword,
        salt: legacySalt,
      );

      expect(await service.verifyPassword(legacyPassword), isTrue);
      expect(storage.values['owner_password_bundle_v2'], isNotNull);
    },
  );

  test('rejects unsupported recovery configuration versions', () async {
    await service.setupOwner(
      ownerName: 'Nena',
      password: 'old-pass',
      recoveryAnswers: answers,
    );
    final config =
        jsonDecode(storage.values['owner_recovery_questions_v1']!)
            as Map<String, dynamic>;
    config['version'] = 2;
    storage.values['owner_recovery_questions_v1'] = jsonEncode(config);

    expect(await service.recoveryQuestions(), isEmpty);
    final result = await service.recoverPassword(
      recoveryAnswers: answers,
      newPassword: 'new-pass',
    );
    expect(result.status, PasswordRecoveryStatus.notConfigured);
  });

  test('rejects common weak recovery answers', () async {
    await expectLater(
      service.setupOwner(
        ownerName: 'Nena',
        password: 'old-pass',
        recoveryAnswers: const {
          'family_nickname': 'password',
          'first_pet': 'Bantay',
          'childhood_best_friend': 'Mia',
        },
      ),
      throwsA(isA<StateError>()),
    );

    await service.setupOwner(
      ownerName: 'Nena',
      password: 'old-pass',
      recoveryAnswers: answers,
    );
    await expectLater(
      service.updateRecoveryQuestions(
        currentPassword: 'old-pass',
        recoveryAnswers: const {
          'family_nickname': 'Lala',
          'first_pet': '1234',
          'childhood_best_friend': 'Mia',
        },
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('updating recovery questions requires the current password', () async {
    await service.setupOwner(
      ownerName: 'Nena',
      password: 'old-pass',
      recoveryAnswers: answers,
    );

    await expectLater(
      service.updateRecoveryQuestions(
        currentPassword: 'wrong-pass',
        recoveryAnswers: const {
          'family_nickname': 'Nena',
          'first_pet': 'Muning',
          'childhood_snack': 'Piattos',
        },
      ),
      throwsA(isA<StateError>()),
    );

    await service.updateRecoveryQuestions(
      currentPassword: 'old-pass',
      recoveryAnswers: const {
        'family_nickname': 'Nena',
        'first_pet': 'Muning',
        'childhood_snack': 'Piattos',
      },
    );
    expect((await service.recoveryQuestions()).map((question) => question.id), [
      'family_nickname',
      'first_pet',
      'childhood_snack',
    ]);
  });
}
