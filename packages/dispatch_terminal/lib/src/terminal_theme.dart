import 'dart:ui';

class TerminalTheme {
  final Color background;
  final Color foreground;
  final Color cursor;
  final Color selection;
  final List<Color> ansiColors;

  const TerminalTheme({
    required this.background,
    required this.foreground,
    required this.cursor,
    required this.selection,
    required this.ansiColors,
  });

  static Color intToColor(int argb) => Color(argb);

  static const dark = TerminalTheme(
    background: Color(0xFF0A0A1A),
    foreground: Color(0xFFCCCCCC),
    cursor: Color(0x80FFFFFF),
    selection: Color(0x403A6FD6),
    ansiColors: [
      Color(0xFF000000), // 0: black
      Color(0xFFCD0000), // 1: red
      Color(0xFF00CD00), // 2: green
      Color(0xFFCDCD00), // 3: yellow
      Color(0xFF0000EE), // 4: blue
      Color(0xFFCD00CD), // 5: magenta
      Color(0xFF00CDCD), // 6: cyan
      Color(0xFFE5E5E5), // 7: white
      Color(0xFF7F7F7F), // 8: bright black
      Color(0xFFFF0000), // 9: bright red
      Color(0xFF00FF00), // 10: bright green
      Color(0xFFFFFF00), // 11: bright yellow
      Color(0xFF5C5CFF), // 12: bright blue
      Color(0xFFFF00FF), // 13: bright magenta
      Color(0xFF00FFFF), // 14: bright cyan
      Color(0xFFFFFFFF), // 15: bright white
    ],
  );
}
