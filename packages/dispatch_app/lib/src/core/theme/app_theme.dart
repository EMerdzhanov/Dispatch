import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFF0A0A1A);
  static const surface = Color(0xFF12122A);
  static const surfaceLight = Color(0xFF1A1A3A);
  static const border = Color(0xFF2A2A4A);
  static const textPrimary = Color(0xFFCCCCCC);
  static const textSecondary = Color(0xFF888888);
  static const accentBlue = Color(0xFF3A6FD6);
  static const accentRed = Color(0xFFE94560);
  static const accentGreen = Color(0xFF00CD00);
  static const accentYellow = Color(0xFFF5A623);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      surface: surface,
      primary: accentBlue,
      error: accentRed,
    ),
    fontFamily: '.AppleSystemUIFont',
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: textPrimary, fontSize: 13),
      bodySmall: TextStyle(color: textSecondary, fontSize: 12),
      titleSmall: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
    ),
    dividerColor: border,
    iconTheme: const IconThemeData(color: textSecondary, size: 16),
  );
}
