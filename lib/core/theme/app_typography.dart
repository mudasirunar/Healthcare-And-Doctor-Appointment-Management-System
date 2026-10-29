import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Crisp typography definitions aligned with DESIGN.md specifications.
class AppTypography {
  AppTypography._();

  static const TextStyle display = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 32 / 24,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 20 / 15,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 14 / 11,
    color: AppColors.textMuted,
    letterSpacing: 0.2,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 20 / 15,
    color: Colors.white,
    letterSpacing: 0.1,
  );
}
