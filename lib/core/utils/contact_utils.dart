String? normalizeContactNumber(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  final hasPlus = trimmed.startsWith('+');
  final clean = trimmed.replaceAll(RegExp(r'[\s\-()]'), '');

  final buffer = StringBuffer();
  if (hasPlus) {
    buffer.write('+');
  }

  final startIndex = hasPlus ? 1 : 0;
  for (int i = startIndex; i < clean.length; i++) {
    final char = clean[i];
    if (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {
      buffer.write(char);
    }
  }

  final result = buffer.toString();
  if (result.isEmpty || result == '+') {
    return null;
  }
  return result;
}
