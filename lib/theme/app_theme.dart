import 'package:flutter/material.dart';
import '../models/group.dart';

class AppTheme {
  static const Color defaultPrimary = Color(0xFF2E7D32);

  static Color primary(Group? group) {
    if (group == null) return defaultPrimary;
    try {
      final hex = group.primaryColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return defaultPrimary;
    }
  }

  static ThemeData theme(Group? group) {
    final color = primary(group);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: color,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
