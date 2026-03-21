// packages/dispatch_terminal/test/screen_buffer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_terminal/src/screen_buffer.dart';
import 'package:dispatch_terminal/src/cell.dart';

void main() {
  group('ScreenBuffer', () {
    late ScreenBuffer buffer;

    setUp(() {
      buffer = ScreenBuffer(cols: 80, rows: 24);
    });

    test('initial state has correct dimensions', () {
      expect(buffer.cols, 80);
      expect(buffer.rows, 24);
      expect(buffer.cursorRow, 0);
      expect(buffer.cursorCol, 0);
    });

    test('write character at cursor position', () {
      buffer.writeChar(0x41); // 'A'
      expect(buffer.cellAt(0, 0).char, 0x41);
      expect(buffer.cursorCol, 1); // cursor advances
    });

    test('write wraps at end of line', () {
      for (int i = 0; i < 80; i++) {
        buffer.writeChar(0x41);
      }
      expect(buffer.cursorRow, 1);
      expect(buffer.cursorCol, 0);
    });

    test('cursor movement', () {
      buffer.moveCursorTo(5, 10);
      expect(buffer.cursorRow, 5);
      expect(buffer.cursorCol, 10);
    });

    test('cursor clamps to bounds', () {
      buffer.moveCursorTo(100, 200);
      expect(buffer.cursorRow, 23);
      expect(buffer.cursorCol, 79);
    });

    test('erase line from cursor to end', () {
      buffer.writeChar(0x41);
      buffer.writeChar(0x42);
      buffer.writeChar(0x43);
      buffer.moveCursorTo(0, 1);
      buffer.eraseInLine(0); // cursor to end
      expect(buffer.cellAt(0, 0).char, 0x41); // preserved
      expect(buffer.cellAt(0, 1).char, 0x20); // erased
      expect(buffer.cellAt(0, 2).char, 0x20); // erased
    });

    test('erase line from start to cursor', () {
      buffer.writeChar(0x41);
      buffer.writeChar(0x42);
      buffer.writeChar(0x43);
      buffer.moveCursorTo(0, 1);
      buffer.eraseInLine(1); // start to cursor
      expect(buffer.cellAt(0, 0).char, 0x20); // erased
      expect(buffer.cellAt(0, 1).char, 0x20); // erased
      expect(buffer.cellAt(0, 2).char, 0x43); // preserved
    });

    test('erase entire line', () {
      buffer.writeChar(0x41);
      buffer.writeChar(0x42);
      buffer.eraseInLine(2); // entire line
      expect(buffer.cellAt(0, 0).char, 0x20);
      expect(buffer.cellAt(0, 1).char, 0x20);
    });

    test('scroll up adds to scrollback', () {
      // Fill first line
      for (int i = 0; i < 5; i++) {
        buffer.writeChar(0x41 + i);
      }
      buffer.scrollUp(1);
      // First line should now be empty (scrolled out)
      expect(buffer.cellAt(0, 0).char, 0x20);
      // Scrollback should have the old first line
      expect(buffer.scrollback.length, 1);
      expect(buffer.scrollback[0][0].char, 0x41);
    });

    test('scrollback trims at max limit', () {
      final small = ScreenBuffer(cols: 80, rows: 24, maxScrollback: 2);
      small.scrollUp(1);
      small.scrollUp(1);
      small.scrollUp(1);
      expect(small.scrollback.length, 2); // trimmed to max
    });

    test('erase display below cursor', () {
      buffer.writeChar(0x41);
      buffer.moveCursorTo(1, 0);
      buffer.writeChar(0x42);
      buffer.moveCursorTo(0, 0);
      buffer.eraseInDisplay(0); // cursor to end of display
      expect(buffer.cellAt(0, 0).char, 0x20);
      expect(buffer.cellAt(1, 0).char, 0x20);
    });

    test('resize preserves content', () {
      buffer.writeChar(0x41);
      buffer.writeChar(0x42);
      buffer.resize(40, 12);
      expect(buffer.cols, 40);
      expect(buffer.rows, 12);
      expect(buffer.cellAt(0, 0).char, 0x41);
      expect(buffer.cellAt(0, 1).char, 0x42);
    });

    test('alternate screen buffer', () {
      buffer.writeChar(0x41);
      buffer.switchToAlternateScreen();
      expect(buffer.cellAt(0, 0).char, 0x20); // alt screen is blank
      buffer.writeChar(0x42);
      buffer.switchToPrimaryScreen();
      expect(buffer.cellAt(0, 0).char, 0x41); // primary restored
    });
  });
}
