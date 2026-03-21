// packages/dispatch_terminal/test/integration_test.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_terminal/dispatch_terminal.dart';

void main() {
  group('Integration: Terminal Engine', () {
    testWidgets('full pipeline: data → parser → buffer → renderer', (tester) async {
      final terminal = Terminal(cols: 80, rows: 24);
      final dataController = StreamController<String>.broadcast();
      final inputBuffer = <String>[];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 400,
            child: TerminalView(
              terminal: terminal,
              dataStream: dataController.stream,
              onInput: inputBuffer.add,
              fontSize: 13,
              fontFamily: 'monospace',
              theme: TerminalTheme.dark,
            ),
          ),
        ),
      ));

      // Simulate shell output with colors and cursor movement
      dataController.add('Hello, \x1b[1;32mWorld\x1b[0m!\r\n');
      dataController.add('\x1b[31mError:\x1b[0m something failed\r\n');
      dataController.add('\$ '); // prompt
      await tester.pump();

      // Verify text was written to buffer
      // "Hello, " starts at col 0
      expect(terminal.buffer.cellAt(0, 0).char, 0x48); // H
      expect(terminal.buffer.cellAt(0, 6).char, 0x20); // space

      // "World" has bold + green
      expect(terminal.buffer.cellAt(0, 7).char, 0x57); // W
      expect(terminal.buffer.cellAt(0, 7).bold, true);

      // Second line "Error:" is red
      expect(terminal.buffer.cellAt(1, 0).char, 0x45); // E
      expect(terminal.buffer.cellAt(1, 0).fg, Terminal.ansiColors[1]); // red

      // Third line has prompt
      expect(terminal.buffer.cellAt(2, 0).char, 0x24); // $

      await dataController.close();
    });

    test('terminal controller round-trip: write text, read back cells', () {
      final terminal = Terminal(cols: 40, rows: 10);

      terminal.write('Line 1\r\n');
      terminal.write('Line 2\r\n');
      terminal.write('\x1b[1;1H'); // move to top-left
      terminal.write('X'); // overwrite

      expect(terminal.buffer.cellAt(0, 0).char, 0x58); // X (overwritten)
      expect(terminal.buffer.cellAt(0, 1).char, 0x69); // i (from "Line 1")
      expect(terminal.buffer.cellAt(1, 0).char, 0x4C); // L (from "Line 2")
    });
  });
}
