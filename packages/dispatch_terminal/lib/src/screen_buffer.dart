// packages/dispatch_terminal/lib/src/screen_buffer.dart
import 'cell.dart';

class ScreenBuffer {
  int _cols;
  int _rows;
  final int maxScrollback;

  int get cols => _cols;
  int get rows => _rows;

  int cursorRow = 0;
  int cursorCol = 0;

  /// Current pen attributes — applied to new characters.
  Cell pen = const Cell();

  late List<List<Cell>> _lines;
  List<List<Cell>> _altLines = [];
  bool _isAltScreen = false;

  /// Scrollback buffer — oldest lines first.
  final List<List<Cell>> scrollback = [];

  ScreenBuffer({
    required int cols,
    required int rows,
    this.maxScrollback = 5000,
  })  : _cols = cols,
        _rows = rows {
    _lines = _createGrid(cols, rows);
  }

  List<List<Cell>> _createGrid(int cols, int rows) {
    return List.generate(rows, (_) => List.generate(cols, (_) => const Cell()));
  }

  Cell cellAt(int row, int col) {
    if (row < 0 || row >= _rows || col < 0 || col >= _cols) return const Cell();
    return _lines[row][col];
  }

  void writeChar(int codepoint) {
    if (cursorCol >= _cols) {
      cursorCol = 0;
      _advanceRow();
    }
    _lines[cursorRow][cursorCol] = pen.copyWith(char: codepoint);
    cursorCol++;
    if (cursorCol >= _cols) {
      cursorCol = 0;
      _advanceRow();
    }
  }

  void _advanceRow() {
    cursorRow++;
    if (cursorRow >= _rows) {
      scrollUp(1);
      cursorRow = _rows - 1;
    }
  }

  void moveCursorTo(int row, int col) {
    cursorRow = row.clamp(0, _rows - 1);
    cursorCol = col.clamp(0, _cols - 1);
  }

  void moveCursorRelative(int dRow, int dCol) {
    moveCursorTo(cursorRow + dRow, cursorCol + dCol);
  }

  /// Erase in line. mode: 0=cursor to end, 1=start to cursor, 2=entire line.
  void eraseInLine(int mode) {
    const blank = Cell();
    switch (mode) {
      case 0: // cursor to end
        for (int c = cursorCol; c < _cols; c++) {
          _lines[cursorRow][c] = blank;
        }
        break;
      case 1: // start to cursor
        for (int c = 0; c <= cursorCol; c++) {
          _lines[cursorRow][c] = blank;
        }
        break;
      case 2: // entire line
        for (int c = 0; c < _cols; c++) {
          _lines[cursorRow][c] = blank;
        }
        break;
    }
  }

  /// Erase in display. mode: 0=cursor to end, 1=start to cursor, 2=entire display.
  void eraseInDisplay(int mode) {
    const blank = Cell();
    switch (mode) {
      case 0: // cursor to end of display
        eraseInLine(0);
        for (int r = cursorRow + 1; r < _rows; r++) {
          for (int c = 0; c < _cols; c++) {
            _lines[r][c] = blank;
          }
        }
        break;
      case 1: // start to cursor
        for (int r = 0; r < cursorRow; r++) {
          for (int c = 0; c < _cols; c++) {
            _lines[r][c] = blank;
          }
        }
        eraseInLine(1);
        break;
      case 2: // entire display
        for (int r = 0; r < _rows; r++) {
          for (int c = 0; c < _cols; c++) {
            _lines[r][c] = blank;
          }
        }
        break;
    }
  }

  void scrollUp(int count) {
    for (int i = 0; i < count; i++) {
      if (!_isAltScreen) {
        scrollback.add(List.of(_lines[0]));
        if (scrollback.length > maxScrollback) {
          scrollback.removeAt(0);
        }
      }
      _lines.removeAt(0);
      _lines.add(List.generate(_cols, (_) => const Cell()));
    }
  }

  void scrollDown(int count) {
    for (int i = 0; i < count; i++) {
      _lines.removeLast();
      _lines.insert(0, List.generate(_cols, (_) => const Cell()));
    }
  }

  void resize(int newCols, int newRows) {
    final newLines = _createGrid(newCols, newRows);
    final copyRows = newRows < _rows ? newRows : _rows;
    final copyCols = newCols < _cols ? newCols : _cols;
    for (int r = 0; r < copyRows; r++) {
      for (int c = 0; c < copyCols; c++) {
        newLines[r][c] = _lines[r][c];
      }
    }
    _lines = newLines;
    _cols = newCols;
    _rows = newRows;
    cursorRow = cursorRow.clamp(0, _rows - 1);
    cursorCol = cursorCol.clamp(0, _cols - 1);
  }

  void switchToAlternateScreen() {
    if (_isAltScreen) return;
    _altLines = _lines;
    _lines = _createGrid(_cols, _rows);
    _isAltScreen = true;
  }

  void switchToPrimaryScreen() {
    if (!_isAltScreen) return;
    _lines = _altLines;
    _altLines = [];
    _isAltScreen = false;
  }

  bool get isAlternateScreen => _isAltScreen;

  /// Extracts text from the active buffer in the given cell range (inclusive).
  String getTextInRange(int startRow, int startCol, int endRow, int endCol) {
    final buf = StringBuffer();
    for (int r = startRow; r <= endRow; r++) {
      if (r < 0 || r >= _rows) continue;
      final cStart = r == startRow ? startCol : 0;
      final cEnd = r == endRow ? endCol : _cols - 1;
      for (int c = cStart; c <= cEnd; c++) {
        if (c < 0 || c >= _cols) continue;
        buf.writeCharCode(_lines[r][c].char);
      }
      if (r < endRow) buf.writeln();
    }
    return buf.toString().trimRight();
  }
}
