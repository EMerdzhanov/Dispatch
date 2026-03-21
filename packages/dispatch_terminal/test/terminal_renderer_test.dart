// packages/dispatch_terminal/test/terminal_renderer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_terminal/src/terminal_renderer.dart';
import 'package:dispatch_terminal/src/screen_buffer.dart';
import 'package:dispatch_terminal/src/terminal_theme.dart';

void main() {
  group('TerminalRenderer', () {
    test('creates CustomPainter without error', () {
      final buffer = ScreenBuffer(cols: 80, rows: 24);
      final renderer = TerminalRenderer(
        buffer: buffer,
        theme: TerminalTheme.dark,
        fontSize: 13,
        fontFamily: 'monospace',
      );
      expect(renderer, isNotNull);
    });

    test('shouldRepaint returns true when buffer changes', () {
      final buffer = ScreenBuffer(cols: 80, rows: 24);
      final r1 = TerminalRenderer(
        buffer: buffer,
        theme: TerminalTheme.dark,
        fontSize: 13,
        fontFamily: 'monospace',
        generation: 0,
      );
      final r2 = TerminalRenderer(
        buffer: buffer,
        theme: TerminalTheme.dark,
        fontSize: 13,
        fontFamily: 'monospace',
        generation: 1,
      );
      expect(r2.shouldRepaint(r1), true);
    });

    test('shouldRepaint returns false when nothing changes', () {
      final buffer = ScreenBuffer(cols: 80, rows: 24);
      final r1 = TerminalRenderer(
        buffer: buffer,
        theme: TerminalTheme.dark,
        fontSize: 13,
        fontFamily: 'monospace',
        generation: 5,
      );
      final r2 = TerminalRenderer(
        buffer: buffer,
        theme: TerminalTheme.dark,
        fontSize: 13,
        fontFamily: 'monospace',
        generation: 5,
      );
      expect(r2.shouldRepaint(r1), false);
    });

    test('calculates cell size', () {
      final buffer = ScreenBuffer(cols: 80, rows: 24);
      final renderer = TerminalRenderer(
        buffer: buffer,
        theme: TerminalTheme.dark,
        fontSize: 13,
        fontFamily: 'monospace',
      );
      expect(renderer.cellWidth, greaterThan(0));
      expect(renderer.cellHeight, greaterThan(0));
    });

    testWidgets('renders in a CustomPaint widget', (tester) async {
      final buffer = ScreenBuffer(cols: 80, rows: 24);
      buffer.writeChar(0x41); // A

      await tester.pumpWidget(MaterialApp(
        home: CustomPaint(
          painter: TerminalRenderer(
            buffer: buffer,
            theme: TerminalTheme.dark,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
          size: const Size(800, 400),
        ),
      ));

      // Just verify it renders without error
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });
  });
}
