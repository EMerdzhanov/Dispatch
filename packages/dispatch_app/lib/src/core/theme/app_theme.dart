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

  static const tabTrack = Color(0xFF060612);
  static const tabTrackBorder = Color(0xFF1A1A2A);

  static const fontStack = 'JetBrains Mono, Fira Code, SF Mono, Menlo, Monaco, Courier New, monospace';

  // Animation durations & curves
  static const hoverDuration = Duration(milliseconds: 120);
  static const animDuration = Duration(milliseconds: 200);
  static const animFastDuration = Duration(milliseconds: 150);
  static const animCurve = Curves.easeOut;
  static const animCurveIn = Curves.easeIn;

  // Spacing constants
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 24;
  static const double radius = 6;
  static const double tabBarHeight = 32;
  static const double terminalHeaderHeight = 24;
  static const double sidebarWidth = 240;
  static const double borderWidth = 0.5;

  // Text style presets
  static const labelStyle = TextStyle(
    color: textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );

  static const bodyStyle = TextStyle(
    color: textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const titleStyle = TextStyle(
    color: textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const dimStyle = TextStyle(
    color: textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  // Overlay decoration helper
  static BoxDecoration get overlayDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border, width: borderWidth),
    boxShadow: const [
      BoxShadow(color: Color(0x80000000), blurRadius: 32, offset: Offset(0, 8)),
    ],
  );

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      surface: surface,
      primary: accentBlue,
      error: accentRed,
    ),
    fontFamily: fontStack,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w400),
      titleSmall: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
    ),
    dividerColor: border,
    iconTheme: const IconThemeData(color: textSecondary, size: 16),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(4),
      radius: const Radius.circular(2),
      thumbColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.2)),
      trackColor: WidgetStateProperty.all(Colors.transparent),
      thumbVisibility: WidgetStateProperty.all(false),
    ),
  );
}
