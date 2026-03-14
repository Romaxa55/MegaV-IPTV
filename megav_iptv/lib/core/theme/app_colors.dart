import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFFA78BFA);
  static const Color primaryDark = Color(0xFF4F46E5);

  static const Color accent = Color(0xFF00CEC9);
  static const Color accentLight = Color(0xFF81ECEC);

  static const Color background = Color(0xFF08080F);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFF252542);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0C8);
  static const Color textHint = Color(0xFF6C6C8A);

  static const Color error = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFDCB6E);

  static const Color liveBadge = Color(0xFFEF4444);
  static const Color soonBadge = Color(0xFFF59E0B);

  static const Color focusBorder = Color(0xFF6366F1);
  static const Color cardBorder = Color(0xFF2D2D4A);

  static Color get glassBg => Colors.white.withValues(alpha: 0.03);
  static Color get glassBorder => Colors.white.withValues(alpha: 0.06);
  static Color get glassButtonBg => Colors.white.withValues(alpha: 0.10);
}
