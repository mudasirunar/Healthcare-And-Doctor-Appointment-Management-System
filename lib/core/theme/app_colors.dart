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

  // Surfaces & Backgrounds (Light)
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  // Surfaces & Backgrounds (Dark)
  static const Color darkBackground = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF151F32);
  static const Color darkSurfaceVariant = Color(0xFF1E293B);

  // Typography (Light)
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // Typography (Dark)
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color darkBorder = Color(0xFF283548);
  static const Color borderFocus = Color(0xFF0A66C2);

  // Status & Feedback Tokens
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color darkErrorLight = Color(0xFF31151B);

  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color darkWarningLight = Color(0xFF33240F);

  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFF0FDF4);
  static const Color darkSuccessLight = Color(0xFF0E2E1F);

  // Soft shadows
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x08000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  // Context-aware adaptive getters
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? darkBackground : background;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color surfaceVariantOf(BuildContext context) =>
      isDark(context) ? darkSurfaceVariant : surfaceVariant;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color textMutedOf(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;

  static Color borderOf(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static Color primaryLightOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF132D4E) : primaryLight;

  static Color secondaryLightOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF113537) : secondaryLight;

  static Color successLightOf(BuildContext context) =>
      isDark(context) ? darkSuccessLight : successLight;

  static Color warningLightOf(BuildContext context) =>
      isDark(context) ? darkWarningLight : warningLight;

  static Color errorLightOf(BuildContext context) =>
      isDark(context) ? darkErrorLight : errorLight;
}
