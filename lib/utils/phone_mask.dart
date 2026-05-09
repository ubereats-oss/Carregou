import 'package:flutter/services.dart';

String formatBrazilPhone(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';

  final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
  if (limited.length <= 2) return '($limited';
  if (limited.length <= 7) {
    return '(${limited.substring(0, 2)})${limited.substring(2)}';
  }
  return '(${limited.substring(0, 2)})${limited.substring(2, 7)}-${limited.substring(7)}';
}

class BrazilPhoneInputFormatter extends TextInputFormatter {
  const BrazilPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatBrazilPhone(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
