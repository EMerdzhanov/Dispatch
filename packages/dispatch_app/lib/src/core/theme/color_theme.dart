import 'package:flutter/material.dart';

class ColorTheme {
  final String id;
  final String name;

  // Terminal colors
  final Color foreground;
  final Color background;
  final Color cursor;
  final Color selection;
  final Color black;
  final Color red;
  final Color green;
  final Color yellow;
  final Color blue;
  final Color magenta;
  final Color cyan;
  final Color white;
  final Color brightBlack;
  final Color brightRed;
  final Color brightGreen;
  final Color brightYellow;
  final Color brightBlue;
  final Color brightMagenta;
  final Color brightCyan;
  final Color brightWhite;
  final Color searchHitBackground;
  final Color searchHitBackgroundCurrent;
  final Color searchHitForeground;

  // UI chrome colors
  final Color uiBackground;
  final Color uiSurface;
  final Color uiSurfaceLight;
  final Color uiBorder;
  final Color uiTextPrimary;
  final Color uiTextSecondary;
  final Color uiAccent;
  final Color uiAccentRed;
  final Color uiAccentGreen;
  final Color uiAccentYellow;
  final Color uiTabTrack;
  final Color uiTabTrackBorder;

  const ColorTheme({
    required this.id,
    required this.name,
    required this.foreground,
    required this.background,
    required this.cursor,
    required this.selection,
    required this.black,
    required this.red,
    required this.green,
    required this.yellow,
    required this.blue,
    required this.magenta,
    required this.cyan,
    required this.white,
    required this.brightBlack,
    required this.brightRed,
    required this.brightGreen,
    required this.brightYellow,
    required this.brightBlue,
    required this.brightMagenta,
    required this.brightCyan,
    required this.brightWhite,
    required this.searchHitBackground,
    required this.searchHitBackgroundCurrent,
    required this.searchHitForeground,
    required this.uiBackground,
    required this.uiSurface,
    required this.uiSurfaceLight,
    required this.uiBorder,
    required this.uiTextPrimary,
    required this.uiTextSecondary,
    required this.uiAccent,
    required this.uiAccentRed,
    required this.uiAccentGreen,
    required this.uiAccentYellow,
    required this.uiTabTrack,
    required this.uiTabTrackBorder,
  });

  /// Look up a theme by id. Returns Dispatch Dark if not found.
  static ColorTheme fromId(String id) {
    return builtIn.firstWhere((t) => t.id == id, orElse: () => dispatchDark);
  }

  static const builtIn = [dispatchDark, monokai, dracula, espresso, carbon, githubDark];

  static const dispatchDark = ColorTheme(
    id: 'dispatch-dark',
    name: 'Dispatch Dark',
    foreground: Color(0xFFCCCCCC),
    background: Color(0xFF0A0A1A),
    cursor: Color(0xFFCCCCCC),
    selection: Color(0x603A6FD6),
    black: Color(0xFF0A0A1A),
    red: Color(0xFFE94560),
    green: Color(0xFF4CAF50),
    yellow: Color(0xFFF5A623),
    blue: Color(0xFF53A8FF),
    magenta: Color(0xFFC678DD),
    cyan: Color(0xFF56B6C2),
    white: Color(0xFFCCCCCC),
    brightBlack: Color(0xFF555555),
    brightRed: Color(0xFFFF6B81),
    brightGreen: Color(0xFF69F0AE),
    brightYellow: Color(0xFFFFD740),
    brightBlue: Color(0xFF82B1FF),
    brightMagenta: Color(0xFFE1ACFF),
    brightCyan: Color(0xFF84FFFF),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFF444444),
    searchHitBackgroundCurrent: Color(0xFFFFFF00),
    searchHitForeground: Color(0xFF000000),
    uiBackground: Color(0xFF0A0A1A),
    uiSurface: Color(0xFF12122A),
    uiSurfaceLight: Color(0xFF1A1A3A),
    uiBorder: Color(0xFF2A2A4A),
    uiTextPrimary: Color(0xFFCCCCCC),
    uiTextSecondary: Color(0xFF888888),
    uiAccent: Color(0xFF3A6FD6),
    uiAccentRed: Color(0xFFE94560),
    uiAccentGreen: Color(0xFF00CD00),
    uiAccentYellow: Color(0xFFF5A623),
    uiTabTrack: Color(0xFF060612),
    uiTabTrackBorder: Color(0xFF1A1A2A),
  );

  static const monokai = ColorTheme(
    id: 'monokai',
    name: 'Monokai',
    foreground: Color(0xFFF8F8F2),
    background: Color(0xFF272822),
    cursor: Color(0xFFF8F8F0),
    selection: Color(0x6049483E),
    black: Color(0xFF272822),
    red: Color(0xFFF92672),
    green: Color(0xFFA6E22E),
    yellow: Color(0xFFE6DB74),
    blue: Color(0xFF66D9EF),
    magenta: Color(0xFFAE81FF),
    cyan: Color(0xFFA1EFE4),
    white: Color(0xFFF8F8F2),
    brightBlack: Color(0xFF75715E),
    brightRed: Color(0xFFF44747),
    brightGreen: Color(0xFFB5F76C),
    brightYellow: Color(0xFFF3EDA5),
    brightBlue: Color(0xFF8DE8FC),
    brightMagenta: Color(0xFFC7A5FF),
    brightCyan: Color(0xFFB5F7EF),
    brightWhite: Color(0xFFF9F8F5),
    searchHitBackground: Color(0xFF444444),
    searchHitBackgroundCurrent: Color(0xFFE6DB74),
    searchHitForeground: Color(0xFF272822),
    uiBackground: Color(0xFF1E1F1C),
    uiSurface: Color(0xFF272822),
    uiSurfaceLight: Color(0xFF3E3D32),
    uiBorder: Color(0xFF49483E),
    uiTextPrimary: Color(0xFFF8F8F2),
    uiTextSecondary: Color(0xFF75715E),
    uiAccent: Color(0xFFF92672),
    uiAccentRed: Color(0xFFF92672),
    uiAccentGreen: Color(0xFFA6E22E),
    uiAccentYellow: Color(0xFFE6DB74),
    uiTabTrack: Color(0xFF1A1B18),
    uiTabTrackBorder: Color(0xFF272822),
  );

  static const dracula = ColorTheme(
    id: 'dracula',
    name: 'Dracula',
    foreground: Color(0xFFF8F8F2),
    background: Color(0xFF282A36),
    cursor: Color(0xFFF8F8F2),
    selection: Color(0x6044475A),
    black: Color(0xFF282A36),
    red: Color(0xFFFF5555),
    green: Color(0xFF50FA7B),
    yellow: Color(0xFFF1FA8C),
    blue: Color(0xFFBD93F9),
    magenta: Color(0xFFFF79C6),
    cyan: Color(0xFF8BE9FD),
    white: Color(0xFFF8F8F2),
    brightBlack: Color(0xFF6272A4),
    brightRed: Color(0xFFFF6E6E),
    brightGreen: Color(0xFF69FF94),
    brightYellow: Color(0xFFFFFFA5),
    brightBlue: Color(0xFFD6ACFF),
    brightMagenta: Color(0xFFFF92DF),
    brightCyan: Color(0xFFA4FFFF),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFF444444),
    searchHitBackgroundCurrent: Color(0xFFF1FA8C),
    searchHitForeground: Color(0xFF282A36),
    uiBackground: Color(0xFF21222C),
    uiSurface: Color(0xFF282A36),
    uiSurfaceLight: Color(0xFF343746),
    uiBorder: Color(0xFF44475A),
    uiTextPrimary: Color(0xFFF8F8F2),
    uiTextSecondary: Color(0xFF6272A4),
    uiAccent: Color(0xFFBD93F9),
    uiAccentRed: Color(0xFFFF5555),
    uiAccentGreen: Color(0xFF50FA7B),
    uiAccentYellow: Color(0xFFF1FA8C),
    uiTabTrack: Color(0xFF1D1E28),
    uiTabTrackBorder: Color(0xFF282A36),
  );

  static const espresso = ColorTheme(
    id: 'espresso',
    name: 'Espresso',
    foreground: Color(0xFFB09880),
    background: Color(0xFF0D0B0A),
    cursor: Color(0xFFD4A96A),
    selection: Color(0x602E2925),
    black: Color(0xFF0D0B0A),
    red: Color(0xFFD47766),
    green: Color(0xFF9AA86B),
    yellow: Color(0xFFD4A96A),
    blue: Color(0xFF7A9BB5),
    magenta: Color(0xFFB08AA6),
    cyan: Color(0xFF8AB5A3),
    white: Color(0xFFB09880),
    brightBlack: Color(0xFF6B6460),
    brightRed: Color(0xFFE09988),
    brightGreen: Color(0xFFB0BC85),
    brightYellow: Color(0xFFE0BE84),
    brightBlue: Color(0xFF94B5CF),
    brightMagenta: Color(0xFFCAA4C0),
    brightCyan: Color(0xFFA4CFBD),
    brightWhite: Color(0xFFD5C4B0),
    searchHitBackground: Color(0xFF3A3530),
    searchHitBackgroundCurrent: Color(0xFFD4A96A),
    searchHitForeground: Color(0xFF0D0B0A),
    uiBackground: Color(0xFF1C1917),
    uiSurface: Color(0xFF201C19),
    uiSurfaceLight: Color(0xFF231F1C),
    uiBorder: Color(0xFF2E2925),
    uiTextPrimary: Color(0xFFB09880),
    uiTextSecondary: Color(0xFF6B6460),
    uiAccent: Color(0xFFD4A96A),
    uiAccentRed: Color(0xFFD47766),
    uiAccentGreen: Color(0xFF9AA86B),
    uiAccentYellow: Color(0xFFD4A96A),
    uiTabTrack: Color(0xFF171412),
    uiTabTrackBorder: Color(0xFF201C19),
  );

  static const carbon = ColorTheme(
    id: 'carbon',
    name: 'Carbon',
    foreground: Color(0xFFCCCCCC),
    background: Color(0xFF080808),
    cursor: Color(0xFFFFFFFF),
    selection: Color(0x60333333),
    black: Color(0xFF080808),
    red: Color(0xFFB55A5A),
    green: Color(0xFF7A9B6E),
    yellow: Color(0xFFB5A05A),
    blue: Color(0xFF5A7FB5),
    magenta: Color(0xFF9B6E9B),
    cyan: Color(0xFF5AB5B5),
    white: Color(0xFFCCCCCC),
    brightBlack: Color(0xFF444444),
    brightRed: Color(0xFFD07070),
    brightGreen: Color(0xFF95B585),
    brightYellow: Color(0xFFD0BB70),
    brightBlue: Color(0xFF7599D0),
    brightMagenta: Color(0xFFB585B5),
    brightCyan: Color(0xFF70D0D0),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFF333333),
    searchHitBackgroundCurrent: Color(0xFFB5A05A),
    searchHitForeground: Color(0xFF080808),
    uiBackground: Color(0xFF111111),
    uiSurface: Color(0xFF141414),
    uiSurfaceLight: Color(0xFF161616),
    uiBorder: Color(0xFF222222),
    uiTextPrimary: Color(0xFFCCCCCC),
    uiTextSecondary: Color(0xFF444444),
    uiAccent: Color(0xFF888888),
    uiAccentRed: Color(0xFFB55A5A),
    uiAccentGreen: Color(0xFF7A9B6E),
    uiAccentYellow: Color(0xFFB5A05A),
    uiTabTrack: Color(0xFF0C0C0C),
    uiTabTrackBorder: Color(0xFF141414),
  );

  static const githubDark = ColorTheme(
    id: 'github-dark',
    name: 'GitHub Dark',
    foreground: Color(0xFFE6EDF3),
    background: Color(0xFF0D1117),
    cursor: Color(0xFFE6EDF3),
    selection: Color(0x6030363D),
    black: Color(0xFF0D1117),
    red: Color(0xFFFF7B72),
    green: Color(0xFF7EE787),
    yellow: Color(0xFFE3B341),
    blue: Color(0xFF79C0FF),
    magenta: Color(0xFFD2A8FF),
    cyan: Color(0xFF56D4DD),
    white: Color(0xFFE6EDF3),
    brightBlack: Color(0xFF484F58),
    brightRed: Color(0xFFFFA198),
    brightGreen: Color(0xFFA5F0B2),
    brightYellow: Color(0xFFEAC55F),
    brightBlue: Color(0xFFA5D6FF),
    brightMagenta: Color(0xFFE2C5FF),
    brightCyan: Color(0xFF76E3EA),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFF444444),
    searchHitBackgroundCurrent: Color(0xFFE3B341),
    searchHitForeground: Color(0xFF0D1117),
    uiBackground: Color(0xFF010409),
    uiSurface: Color(0xFF0D1117),
    uiSurfaceLight: Color(0xFF161B22),
    uiBorder: Color(0xFF30363D),
    uiTextPrimary: Color(0xFFE6EDF3),
    uiTextSecondary: Color(0xFF8B949E),
    uiAccent: Color(0xFF58A6FF),
    uiAccentRed: Color(0xFFFF7B72),
    uiAccentGreen: Color(0xFF7EE787),
    uiAccentYellow: Color(0xFFE3B341),
    uiTabTrack: Color(0xFF080B10),
    uiTabTrackBorder: Color(0xFF0D1117),
  );
}
