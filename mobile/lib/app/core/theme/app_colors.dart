import 'package:flutter/material.dart';

/// Single source of truth for colour. Never hard-code a [Color] in a view.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1E5EFF);
  static const Color primaryDark = Color(0xFF1442B8);
  static const Color accent = Color(0xFF00B894);

  /// Money in (sales, payments received).
  static const Color credit = Color(0xFF14A44D);

  /// Money out (purchases, payments made).
  static const Color debit = Color(0xFFE23D3D);

  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF3498DB);

  static const Color background = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE3E6EF);

  static const Color textPrimary = Color(0xFF1A1D2B);
  static const Color textSecondary = Color(0xFF6B7185);
  static const Color textDisabled = Color(0xFFA0A5B8);

  static const Color darkBackground = Color(0xFF12141C);
  static const Color darkSurface = Color(0xFF1B1E29);
  static const Color darkBorder = Color(0xFF2A2E3D);
}
