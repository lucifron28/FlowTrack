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
