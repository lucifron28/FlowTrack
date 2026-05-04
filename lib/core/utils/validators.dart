class Validators {
  const Validators._();

  static String? requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  static String? nonNegativeNumber(String? value, String label) {
    final parsed = num.tryParse(value?.trim() ?? '');
    if (parsed == null) {
      return 'Enter a valid $label.';
    }
    if (parsed < 0) {
      return '$label cannot be negative.';
    }
    return null;
  }

  static String? positiveNumber(String? value, String label) {
    final parsed = num.tryParse(value?.trim() ?? '');
    if (parsed == null) {
      return 'Enter a valid $label.';
    }
    if (parsed <= 0) {
      return '$label must be greater than 0.';
    }
    return null;
  }
}
