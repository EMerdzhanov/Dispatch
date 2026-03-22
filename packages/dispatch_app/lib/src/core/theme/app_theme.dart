import 'package:flutter/material.dart';

import 'color_theme.dart';

class AppTheme {
  final ColorTheme colors;

  const AppTheme(this.colors);

  // Color accessors — map old static names to ColorTheme fields
  Color get background => colors.uiBackground;
  Color get surface => colors.uiSurface;
  Color get surfaceLight => colors.uiSurfaceLight;
  Color get border => colors.uiBorder;
  Color get textPrimary => colors.uiTextPrimary;
  Color get textSecondary => colors.uiTextSecondary;
  Color get accentBlue => colors.uiAccent;
  Color get accentRed => colors.uiAccentRed;
  Color get accentGreen => colors.uiAccentGreen;
  Color get accentYellow => colors.uiAccentYellow;
  Color get tabTrack => colors.uiTabTrack;
  Color get tabTrackBorder => colors.uiTabTrackBorder;

  // Non-color constants remain static
  static const fontStack = 'JetBrains Mono, Fira Code, SF Mono, Menlo, Monaco, Courier New, monospace';

  static const hoverDuration = Duration(milliseconds: 120);
  static const animDuration = Duration(milliseconds: 200);
  static const animFastDuration = Duration(milliseconds: 150);
  static const animCurve = Curves.easeOut;
  static const animCurveIn = Curves.easeIn;

  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 24;
  static const double radius = 6;
  static const double tabBarHeight = 32;
  static const double terminalHeaderHeight = 24;
  static const double sidebarWidth = 180;
  static const double borderWidth = 0.5;

  // Text style presets — now instance getters since they use colors
  TextStyle get labelStyle => TextStyle(
    color: textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );

  TextStyle get bodyStyle => TextStyle(
    color: textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  TextStyle get titleStyle => TextStyle(
    color: textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  TextStyle get dimStyle => TextStyle(
    color: textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  BoxDecoration get overlayDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border, width: borderWidth),
    boxShadow: const [
      BoxShadow(color: Color(0x80000000), blurRadius: 32, offset: Offset(0, 8)),
    ],
  );

  ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.dark(
      surface: surface,
      primary: accentBlue,
      error: accentRed,
    ),
    fontFamily: fontStack,
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w400),
      titleSmall: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
    ),
    dividerColor: border,
    iconTheme: IconThemeData(color: textSecondary, size: 16),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(4),
      radius: const Radius.circular(2),
      thumbColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.2)),
      trackColor: WidgetStateProperty.all(Colors.transparent),
      thumbVisibility: WidgetStateProperty.all(false),
    ),
  );
}
