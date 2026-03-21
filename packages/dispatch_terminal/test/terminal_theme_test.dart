import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_terminal/src/terminal_theme.dart';
import 'dart:ui';

void main() {
  group('TerminalTheme', () {
    test('dark theme has expected background color', () {
      expect(TerminalTheme.dark.background, const Color(0xFF0A0A1A));
    });

    test('dark theme has 16 ANSI colors', () {
      expect(TerminalTheme.dark.ansiColors.length, 16);
    });

    test('intToColor converts ARGB int to Color', () {
      expect(TerminalTheme.intToColor(0xFFFF0000), const Color(0xFFFF0000));
    });
  });
}
