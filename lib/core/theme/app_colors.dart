import 'package:flutter/material.dart';

/// Semantic color palette for Healthcare App as specified in DESIGN.md.
/// Medical calm, high-contrast, trustworthy clinical palette.
class AppColors {
  AppColors._();

  // Primary brand (Medical Blue)
  static const Color primary = Color(0xFF0A66C2);
  static const Color primaryDark = Color(0xFF084E96);
  static const Color primaryLight = Color(0xFFE8F2FC);

  // Secondary brand (Teal / Emerald)
  static const Color secondary = Color(0xFF0D9488);
  static const Color secondaryDark = Color(0xFF0F766E);
  static const Color secondaryLight = Color(0xFFF0FDFA);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  // Typography
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocus = Color(0xFF0A66C2);

  // Status & Feedback Tokens
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEF2F2);

  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFFBEB);

  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFF0FDF4);

  // Soft shadows
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x08000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
}
