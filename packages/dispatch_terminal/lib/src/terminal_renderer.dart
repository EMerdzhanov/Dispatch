// packages/dispatch_terminal/lib/src/terminal_renderer.dart
import 'package:flutter/material.dart';
import 'cell.dart';
import 'screen_buffer.dart';
import 'terminal_theme.dart';

/// Cached glyph store shared across renderer instances with the same
/// font configuration. Using a static cache avoids re-creating TextPainter
/// objects every frame.
final Map<int, TextPainter> _glyphCache = {};

class TerminalRenderer extends CustomPainter {
  final ScreenBuffer buffer;
  final TerminalTheme theme;
  final double fontSize;
  final String fontFamily;
  final int generation;
  final int? cursorRow;
  final int? cursorCol;
  final bool showCursor;
  final int scrollOffset;
  final (int, int)? selectionStart;
  final (int, int)? selectionEnd;

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
    this.scrollOffset = 0,
    this.selectionStart,
    this.selectionEnd,
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

  /// Returns a cached TextPainter for the given codepoint and style.
  TextPainter _getGlyph(int codepoint, TextStyle style) {
    final key = codepoint ^ style.hashCode;
    return _glyphCache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(text: String.fromCharCode(codepoint), style: style),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  /// Retrieves the cell for a given visible [row], accounting for [scrollOffset].
  Cell _cellForVisibleRow(int visibleRow, int col) {
    if (scrollOffset == 0) {
      return buffer.cellAt(visibleRow, col);
    }

    final scrollbackLen = buffer.scrollback.length;
    final scrollbackRow = scrollbackLen - scrollOffset + visibleRow;
    if (scrollbackRow >= 0 && scrollbackRow < scrollbackLen) {
      final line = buffer.scrollback[scrollbackRow];
      if (col < line.length) return line[col];
      return const Cell();
    }
    final bufferRow = visibleRow - scrollOffset;
    if (bufferRow >= 0) {
      return buffer.cellAt(bufferRow, col);
    }
    return const Cell();
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

    // ---- Pass 1: Batch background drawing ----
    // For each row, collect contiguous runs of the same non-default bg color.
    for (int row = 0; row < buffer.rows; row++) {
      final y = row * cellHeight;
      if (y > size.height) break;

      Color? runColor;
      int runStart = 0;

      for (int col = 0; col <= buffer.cols; col++) {
        Color bgColor;
        if (col < buffer.cols) {
          final cell = _cellForVisibleRow(row, col);
          final isInverse = cell.inverse;
          bgColor = isInverse
              ? TerminalTheme.intToColor(cell.fg)
              : TerminalTheme.intToColor(cell.bg);
          if (bgColor == theme.background) {
            bgColor = theme.background; // normalize
          }
        } else {
          bgColor = theme.background; // sentinel to flush last run
        }

        if (bgColor != runColor) {
          // Flush the previous run if it was non-default
          if (runColor != null && runColor != theme.background) {
            final x = runStart * cellWidth;
            final w = (col - runStart) * cellWidth;
            canvas.drawRect(
              Rect.fromLTWH(x, y, w, cellHeight),
              Paint()..color = runColor,
            );
          }
          runColor = bgColor;
          runStart = col;
        }
      }
    }

    // ---- Pass 2: Draw characters (skip spaces) ----
    for (int row = 0; row < buffer.rows; row++) {
      final y = row * cellHeight;
      if (y > size.height) break;

      for (int col = 0; col < buffer.cols; col++) {
        final cell = _cellForVisibleRow(row, col);

        // Skip empty cells (space characters have no visible glyph)
        if (cell.char == 0x20 || cell.char == 0) continue;

        final x = col * cellWidth;
        if (x > size.width) break;

        final isInverse = cell.inverse;
        final fgColor = isInverse
            ? TerminalTheme.intToColor(cell.bg)
            : TerminalTheme.intToColor(cell.fg);

        final style = TextStyle(
          fontSize: fontSize,
          fontFamily: fontFamily,
          color: fgColor,
          fontWeight: cell.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: cell.italic ? FontStyle.italic : FontStyle.normal,
          decoration: _buildDecoration(cell),
          height: 1.2,
        );

        final tp = _getGlyph(cell.char, style);
        tp.paint(canvas, Offset(x, y));
      }
    }

    // ---- Pass 3: Draw selection highlight ----
    if (selectionStart != null && selectionEnd != null) {
      final selPaint = Paint()..color = theme.selection;
      final sRow = selectionStart!.$1;
      final sCol = selectionStart!.$2;
      final eRow = selectionEnd!.$1;
      final eCol = selectionEnd!.$2;

      for (int row = sRow; row <= eRow; row++) {
        if (row < 0 || row >= buffer.rows) continue;
        final colStart = row == sRow ? sCol : 0;
        final colEnd = row == eRow ? eCol : buffer.cols - 1;
        final x = colStart * cellWidth;
        final y = row * cellHeight;
        final w = (colEnd - colStart + 1) * cellWidth;
        canvas.drawRect(Rect.fromLTWH(x, y, w, cellHeight), selPaint);
      }
    }

    // ---- Pass 4: Draw cursor ----
    if (showCursor && scrollOffset == 0 && cRow < buffer.rows && cCol < buffer.cols) {
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
        fontFamily != oldDelegate.fontFamily ||
        scrollOffset != oldDelegate.scrollOffset ||
        selectionStart != oldDelegate.selectionStart ||
        selectionEnd != oldDelegate.selectionEnd;
  }
}
