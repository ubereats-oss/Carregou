String normalizeAccessCode(String value) {
  return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

String formatAccessCode(String value) {
  final code = normalizeAccessCode(value);
  if (code.isEmpty) return '';

  final buffer = StringBuffer();
  for (var i = 0; i < code.length; i++) {
    if (i > 0 && i % 4 == 0) {
      buffer.write('-');
    }
    buffer.write(code[i]);
  }
  return buffer.toString();
}
