// packages/dispatch_terminal/test/terminal_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_terminal/src/terminal.dart';

void main() {
  group('Terminal', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
    });

    test('write plain text', () {
      terminal.write('Hello');
      expect(terminal.buffer.cellAt(0, 0).char, 0x48); // H
      expect(terminal.buffer.cellAt(0, 4).char, 0x6F); // o
      expect(terminal.buffer.cursorCol, 5);
    });

    test('newline and carriage return', () {
      terminal.write('AB\r\nCD');
      expect(terminal.buffer.cellAt(0, 0).char, 0x41); // A
      expect(terminal.buffer.cellAt(0, 1).char, 0x42); // B
      expect(terminal.buffer.cellAt(1, 0).char, 0x43); // C
      expect(terminal.buffer.cellAt(1, 1).char, 0x44); // D
    });

    test('cursor up: ESC[A', () {
      terminal.write('A\n');
      terminal.write('\x1b[A');
      expect(terminal.buffer.cursorRow, 0);
    });

    test('cursor down: ESC[B', () {
      terminal.write('\x1b[B');
      expect(terminal.buffer.cursorRow, 1);
    });

    test('cursor forward: ESC[C', () {
      terminal.write('\x1b[3C');
      expect(terminal.buffer.cursorCol, 3);
    });

    test('cursor back: ESC[D', () {
      terminal.write('ABCDE');
      terminal.write('\x1b[2D');
      expect(terminal.buffer.cursorCol, 3);
    });

    test('cursor position: ESC[row;colH', () {
      terminal.write('\x1b[5;10H');
      expect(terminal.buffer.cursorRow, 4); // 1-based to 0-based
      expect(terminal.buffer.cursorCol, 9);
    });

    test('erase to end of line: ESC[K', () {
      terminal.write('ABCDE');
      terminal.write('\x1b[3D'); // back 3
      terminal.write('\x1b[K');  // erase to end
      expect(terminal.buffer.cellAt(0, 0).char, 0x41); // A
      expect(terminal.buffer.cellAt(0, 1).char, 0x42); // B
      expect(terminal.buffer.cellAt(0, 2).char, 0x20); // erased
      expect(terminal.buffer.cellAt(0, 3).char, 0x20); // erased
    });

    test('SGR bold: ESC[1m', () {
      terminal.write('\x1b[1mA');
      expect(terminal.buffer.cellAt(0, 0).bold, true);
    });

    test('SGR reset: ESC[0m', () {
      terminal.write('\x1b[1m\x1b[0mA');
      expect(terminal.buffer.cellAt(0, 0).bold, false);
    });

    test('SGR foreground color 8-color: ESC[31m', () {
      terminal.write('\x1b[31mA');
      final cell = terminal.buffer.cellAt(0, 0);
      // Red foreground (ANSI color 1)
      expect(cell.fg, Terminal.ansiColors[1]);
    });

    test('SGR 256-color: ESC[38;5;196m', () {
      terminal.write('\x1b[38;5;196mA');
      final cell = terminal.buffer.cellAt(0, 0);
      expect(cell.fg, isNot(equals(0xFFCCCCCC))); // not default
    });

    test('alternate screen on/off: ESC[?1049h / ESC[?1049l', () {
      terminal.write('A');
      terminal.write('\x1b[?1049h'); // switch to alt
      expect(terminal.buffer.isAlternateScreen, true);
      expect(terminal.buffer.cellAt(0, 0).char, 0x20); // alt is blank
      terminal.write('\x1b[?1049l'); // back to primary
      expect(terminal.buffer.isAlternateScreen, false);
      expect(terminal.buffer.cellAt(0, 0).char, 0x41); // A restored
    });

    test('OSC title change triggers callback', () {
      String? title;
      terminal = Terminal(cols: 80, rows: 24, onTitle: (t) => title = t);
      terminal.write('\x1b]0;My Terminal\x07');
      expect(title, 'My Terminal');
    });

    test('backspace moves cursor left', () {
      terminal.write('AB\x08');
      expect(terminal.buffer.cursorCol, 1);
    });

    test('tab advances to next tab stop', () {
      terminal.write('A\t');
      expect(terminal.buffer.cursorCol, 8); // default tab stop at 8
    });

    test('erase display: ESC[2J', () {
      terminal.write('Hello');
      terminal.write('\x1b[2J');
      expect(terminal.buffer.cellAt(0, 0).char, 0x20);
    });

    test('resize', () {
      terminal.write('Hello');
      terminal.resize(40, 12);
      expect(terminal.buffer.cols, 40);
      expect(terminal.buffer.rows, 12);
      expect(terminal.buffer.cellAt(0, 0).char, 0x48);
    });
  });
}
