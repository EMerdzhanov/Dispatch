import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_terminal/src/cell.dart';

void main() {
  group('Cell', () {
    test('default cell has space character and default colors', () {
      final cell = Cell();
      expect(cell.char, 0x20); // space
      expect(cell.fg, Cell.defaultFg);
      expect(cell.bg, Cell.defaultBg);
      expect(cell.bold, false);
      expect(cell.italic, false);
      expect(cell.underline, false);
      expect(cell.inverse, false);
      expect(cell.strikethrough, false);
    });

    test('cell with character and attributes', () {
      final cell = Cell(
        char: 0x41, // 'A'
        fg: 0xFFFF0000,
        bg: 0xFF000000,
        bold: true,
        underline: true,
      );
      expect(cell.char, 0x41);
      expect(cell.fg, 0xFFFF0000);
      expect(cell.bg, 0xFF000000);
      expect(cell.bold, true);
      expect(cell.underline, true);
      expect(cell.italic, false);
    });

    test('reset returns default cell', () {
      final cell = Cell(char: 0x41, fg: 0xFFFF0000, bold: true);
      final reset = cell.reset();
      expect(reset.char, 0x20);
      expect(reset.fg, Cell.defaultFg);
      expect(reset.bold, false);
    });

    test('copyWith overrides specified fields', () {
      final cell = Cell(char: 0x41, bold: true);
      final copy = cell.copyWith(char: 0x42, italic: true);
      expect(copy.char, 0x42);
      expect(copy.bold, true); // preserved
      expect(copy.italic, true); // overridden
    });
  });
}
