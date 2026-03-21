// packages/dispatch_terminal/lib/src/terminal_renderer.dart
import 'package:flutter/material.dart';
import 'cell.dart';
import 'screen_buffer.dart';
import 'terminal_theme.dart';

class TerminalRenderer extends CustomPainter {
  final ScreenBuffer buffer;
  final TerminalTheme theme;
  final double fontSize;
  final String fontFamily;
  final int generation;
  final int? cursorRow;
  final int? cursorCol;
  final bool showCursor;

  late final double cellWidth;
  late final double cellHeight;

  TerminalRenderer({
    required this.buffer,
    required this.theme,
    required this.fontSize,
    required this.fontFamily,
    this.generation = 0,
    this.cursorRow,
    this.cursorCol,
    this.showCursor = true,
  }) {
    // Measure cell size using a reference character
    final tp = TextPainter(
      text: TextSpan(
        text: 'M',
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: fontFamily,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    cellWidth = tp.width;
    cellHeight = tp.height;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = theme.background,
    );

    final cRow = cursorRow ?? buffer.cursorRow;
    final cCol = cursorCol ?? buffer.cursorCol;

    for (int row = 0; row < buffer.rows; row++) {
      for (int col = 0; col < buffer.cols; col++) {
        final cell = buffer.cellAt(row, col);
        final x = col * cellWidth;
        final y = row * cellHeight;

        if (x > size.width || y > size.height) continue;

        final isInverse = cell.inverse;
        final fgColor = isInverse
            ? TerminalTheme.intToColor(cell.bg)
            : TerminalTheme.intToColor(cell.fg);
        final bgColor = isInverse
            ? TerminalTheme.intToColor(cell.fg)
            : TerminalTheme.intToColor(cell.bg);

        // Draw cell background if not default
        if (bgColor != theme.background) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, cellWidth, cellHeight),
            Paint()..color = bgColor,
          );
        }

        // Draw character
        if (cell.char != 0x20) {
          final style = TextStyle(
            fontSize: fontSize,
            fontFamily: fontFamily,
            color: fgColor,
            fontWeight: cell.bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: cell.italic ? FontStyle.italic : FontStyle.normal,
            decoration: _buildDecoration(cell),
            height: 1.2,
          );

          final tp = TextPainter(
            text: TextSpan(text: String.fromCharCode(cell.char), style: style),
            textDirection: TextDirection.ltr,
          )..layout();

          tp.paint(canvas, Offset(x, y));
        }
      }
    }

    // Draw cursor
    if (showCursor && cRow < buffer.rows && cCol < buffer.cols) {
      final cx = cCol * cellWidth;
      final cy = cRow * cellHeight;
      canvas.drawRect(
        Rect.fromLTWH(cx, cy, cellWidth, cellHeight),
        Paint()
          ..color = theme.cursor
          ..style = PaintingStyle.fill,
      );
    }
  }

  TextDecoration? _buildDecoration(Cell cell) {
    final decorations = <TextDecoration>[];
    if (cell.underline) decorations.add(TextDecoration.underline);
    if (cell.strikethrough) decorations.add(TextDecoration.lineThrough);
    if (decorations.isEmpty) return null;
    return TextDecoration.combine(decorations);
  }

  @override
  bool shouldRepaint(covariant TerminalRenderer oldDelegate) {
    return generation != oldDelegate.generation ||
        fontSize != oldDelegate.fontSize ||
        fontFamily != oldDelegate.fontFamily;
  }
}
