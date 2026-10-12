import 'package:flutter/material.dart';

/// Centralized color palette for ChatFlow.
/// Never hardcode colors in widgets — always reference these.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF4F46E5);
  static const Color secondary = Color(0xFF7C3AED);
  static const Color accent = Color(0xFF06B6D4);

  // Light theme
  static const Color lightBackground = Color(0xFFE9EBF4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1A1C1E);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightDivider = Color(0xFFE5E7EB);

  // Dark theme
  static const Color darkBackground = Color(0xFF121214);
  static const Color darkSurface = Color(0xFF1E1F22);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkDivider = Color(0xFF2E2F33);

  // Semantic
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
}