enum PasswordRecoveryStatus {
  success,
  notConfigured,
  invalidAnswers,
  lockedOut,
}

class PasswordRecoveryResult {
  const PasswordRecoveryResult({required this.status, this.lockedUntil});

  final PasswordRecoveryStatus status;
  final DateTime? lockedUntil;

  bool get succeeded => status == PasswordRecoveryStatus.success;
}

class RecoveryQuestion {
  const RecoveryQuestion({required this.id, required this.prompt});

  final String id;
  final String prompt;
}

class RecoveryQuestionCatalog {
  const RecoveryQuestionCatalog._();

  static const all = <RecoveryQuestion>[
    RecoveryQuestion(
      id: 'family_nickname',
      prompt: 'What nickname does your family call you?',
    ),
    RecoveryQuestion(
      id: 'first_pet',
      prompt: "What was your first pet's name?",
    ),
    RecoveryQuestion(
      id: 'childhood_best_friend',
      prompt: 'Who was your childhood best friend?',
    ),
    RecoveryQuestion(
      id: 'childhood_snack',
      prompt: 'What was your favorite childhood snack?',
    ),
    RecoveryQuestion(
      id: 'first_school',
      prompt: 'What was your first school called?',
    ),
    RecoveryQuestion(
      id: 'first_product_sold',
      prompt: 'What was the first product you sold?',
    ),
    RecoveryQuestion(
      id: 'home_cooked_food',
      prompt: 'What home-cooked food do you remember most?',
    ),
    RecoveryQuestion(
      id: 'private_word',
      prompt: 'What private word is easy for you to remember?',
    ),
  ];

  static const requiredCount = 3;

  static RecoveryQuestion byId(String id) {
    for (final question in all) {
      if (question.id == id) {
        return question;
      }
    }
    throw StateError('Unknown recovery question.');
  }

  static String normalizeAnswer(String answer) {
    return answer.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }
}
