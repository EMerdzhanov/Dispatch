# Terminal Engine (`dispatch_terminal`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone Flutter terminal emulation package with VT parser, screen buffer, PTY FFI bridge, canvas renderer, and public terminal widget.

**Architecture:** A Dart/Flutter package (`dispatch_terminal`) in a Melos monorepo. The VT parser and screen buffer are pure Dart (no Flutter dependency) for maximum testability. The PTY bridge uses `dart:ffi` to call POSIX `forkpty()`/`read()`/`write()` on a background isolate. The renderer is a `CustomPainter` that draws the screen buffer. The public API is a `TerminalView` widget.

**Tech Stack:** Dart 3.x, Flutter (stable), `dart:ffi`, `dart:isolate`, Melos, `flutter_test`

**Spec:** `docs/superpowers/specs/2026-03-21-flutter-rebuild-design.md`

---

## File Structure

```
dispatch/
├── melos.yaml
├── packages/
│   └── dispatch_terminal/
│       ├── pubspec.yaml
│       ├── lib/
│       │   ├── dispatch_terminal.dart          # Barrel export
│       │   └── src/
│       │       ├── vt_parser.dart              # ANSI/VT escape sequence state machine
│       │       ├── screen_buffer.dart          # Character grid + scrollback
│       │       ├── cell.dart                   # Cell data model (char, colors, attrs)
│       │       ├── terminal.dart               # Terminal controller (wires parser + buffer)
│       │       ├── pty_ffi.dart                # dart:ffi bindings for forkpty/read/write
│       │       ├── pty_manager.dart            # PTY lifecycle + isolate management
│       │       ├── terminal_renderer.dart      # CustomPainter for screen buffer
│       │       ├── terminal_widget.dart        # Public TerminalView StatefulWidget
│       │       └── terminal_theme.dart         # Color scheme for terminal rendering
│       ├── src/
│       │   └── native/
│       │       └── pty_native.c                # Thin C wrapper for forkpty (if needed)
│       └── test/
│           ├── vt_parser_test.dart
│           ├── screen_buffer_test.dart
│           ├── cell_test.dart
│           ├── terminal_test.dart
│           ├── pty_ffi_test.dart
│           ├── pty_manager_test.dart
│           ├── terminal_renderer_test.dart
│           └── terminal_widget_test.dart
```

---

### Task 1: Monorepo Scaffold

**Files:**
- Create: `melos.yaml`
- Create: `packages/dispatch_terminal/pubspec.yaml`
- Create: `packages/dispatch_terminal/lib/dispatch_terminal.dart`
- Create: `packages/dispatch_terminal/lib/src/.gitkeep`
- Create: `packages/dispatch_terminal/test/.gitkeep`

- [ ] **Step 1: Create Melos config**

```yaml
# melos.yaml
name: dispatch
packages:
  - packages/*

scripts:
  test:
    run: melos exec -- flutter test
  analyze:
    run: melos exec -- dart analyze
```

- [ ] **Step 2: Create package pubspec**

```yaml
# packages/dispatch_terminal/pubspec.yaml
name: dispatch_terminal
description: Terminal emulation engine with VT parser, screen buffer, and PTY management.
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.0.0
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter
  ffi: ^2.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
```

- [ ] **Step 3: Create barrel export**

```dart
// packages/dispatch_terminal/lib/dispatch_terminal.dart
library dispatch_terminal;

// Exports will be added as components are built.
```

- [ ] **Step 4: Create placeholder files**

Create empty `.gitkeep` in `lib/src/` and `test/`.

- [ ] **Step 5: Bootstrap and verify**

Run:
```bash
cd dispatch
dart pub global activate melos
melos bootstrap
```
Expected: "SUCCESS" — packages linked.

- [ ] **Step 6: Commit**

```bash
git add melos.yaml packages/
git commit -m "chore: scaffold Melos monorepo with dispatch_terminal package"
```

---

### Task 2: Cell Data Model

**Files:**
- Create: `packages/dispatch_terminal/lib/src/cell.dart`
- Create: `packages/dispatch_terminal/test/cell_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// packages/dispatch_terminal/test/cell_test.dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/dispatch_terminal && flutter test test/cell_test.dart`
Expected: FAIL — cannot find `cell.dart`

- [ ] **Step 3: Implement Cell**

```dart
// packages/dispatch_terminal/lib/src/cell.dart

/// A single character cell in the terminal screen buffer.
class Cell {
  static const int defaultFg = 0xFFCCCCCC; // light gray
  static const int defaultBg = 0xFF0A0A1A; // dark background

  final int char;
  final int fg;
  final int bg;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool inverse;
  final bool strikethrough;
  final bool blink;

  const Cell({
    this.char = 0x20, // space
    this.fg = defaultFg,
    this.bg = defaultBg,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.inverse = false,
    this.strikethrough = false,
    this.blink = false,
  });

  Cell reset() => const Cell();

  Cell copyWith({
    int? char,
    int? fg,
    int? bg,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? inverse,
    bool? strikethrough,
    bool? blink,
  }) {
    return Cell(
      char: char ?? this.char,
      fg: fg ?? this.fg,
      bg: bg ?? this.bg,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      inverse: inverse ?? this.inverse,
      strikethrough: strikethrough ?? this.strikethrough,
      blink: blink ?? this.blink,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/dispatch_terminal && flutter test test/cell_test.dart`
Expected: All 4 tests PASS

- [ ] **Step 5: Export from barrel**

Add to `packages/dispatch_terminal/lib/dispatch_terminal.dart`:
```dart
export 'src/cell.dart';
```

- [ ] **Step 6: Commit**

```bash
git add packages/dispatch_terminal/lib/src/cell.dart packages/dispatch_terminal/test/cell_test.dart packages/dispatch_terminal/lib/dispatch_terminal.dart
git commit -m "feat(terminal): add Cell data model with attributes and colors"
```

---

### Task 3: Screen Buffer

**Files:**
- Create: `packages/dispatch_terminal/lib/src/screen_buffer.dart`
- Create: `packages/dispatch_terminal/test/screen_buffer_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/dispatch_terminal && flutter test test/screen_buffer_test.dart`
Expected: FAIL — cannot find `screen_buffer.dart`

- [ ] **Step 3: Implement ScreenBuffer**

```dart
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
    final blank = const Cell();
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
    final blank = const Cell();
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
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/dispatch_terminal && flutter test test/screen_buffer_test.dart`
Expected: All 12 tests PASS

- [ ] **Step 5: Export from barrel**

Add to `packages/dispatch_terminal/lib/dispatch_terminal.dart`:
```dart
export 'src/screen_buffer.dart';
```

- [ ] **Step 6: Commit**

```bash
git add packages/dispatch_terminal/lib/src/screen_buffer.dart packages/dispatch_terminal/test/screen_buffer_test.dart packages/dispatch_terminal/lib/dispatch_terminal.dart
git commit -m "feat(terminal): add ScreenBuffer with scrollback, erase, resize, alt screen"
```

---

### Task 4: VT Parser

**Files:**
- Create: `packages/dispatch_terminal/lib/src/vt_parser.dart`
- Create: `packages/dispatch_terminal/test/vt_parser_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// packages/dispatch_terminal/test/vt_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_terminal/src/vt_parser.dart';

void main() {
  group('VtParser', () {
    late VtParser parser;
    late List<VtAction> actions;

    setUp(() {
      actions = [];
      parser = VtParser(onAction: actions.add);
    });

    test('printable ASCII emits Print actions', () {
      parser.feed('Hello'.codeUnits);
      expect(actions.length, 5);
      expect(actions[0], isA<PrintAction>());
      expect((actions[0] as PrintAction).codepoint, 0x48); // H
    });

    test('newline emits Linefeed', () {
      parser.feed([0x0A]); // \n
      expect(actions.length, 1);
      expect(actions[0], isA<LinefeedAction>());
    });

    test('carriage return emits CarriageReturn', () {
      parser.feed([0x0D]); // \r
      expect(actions.length, 1);
      expect(actions[0], isA<CarriageReturnAction>());
    });

    test('backspace emits Backspace', () {
      parser.feed([0x08]);
      expect(actions.length, 1);
      expect(actions[0], isA<BackspaceAction>());
    });

    test('tab emits Tab', () {
      parser.feed([0x09]);
      expect(actions.length, 1);
      expect(actions[0], isA<TabAction>());
    });

    test('bell emits Bell', () {
      parser.feed([0x07]);
      expect(actions.length, 1);
      expect(actions[0], isA<BellAction>());
    });

    test('CSI cursor up: ESC[A', () {
      parser.feed([0x1B, 0x5B, 0x41]); // \e[A
      expect(actions.length, 1);
      expect(actions[0], isA<CsiAction>());
      final csi = actions[0] as CsiAction;
      expect(csi.finalByte, 0x41); // 'A'
      expect(csi.params, []);
    });

    test('CSI cursor up with count: ESC[5A', () {
      parser.feed([0x1B, 0x5B, 0x35, 0x41]); // \e[5A
      final csi = actions[0] as CsiAction;
      expect(csi.finalByte, 0x41);
      expect(csi.params, [5]);
    });

    test('CSI with multiple params: ESC[10;20H', () {
      // \e[10;20H — cursor position
      parser.feed([0x1B, 0x5B, 0x31, 0x30, 0x3B, 0x32, 0x30, 0x48]);
      final csi = actions[0] as CsiAction;
      expect(csi.finalByte, 0x48); // 'H'
      expect(csi.params, [10, 20]);
    });

    test('SGR reset: ESC[0m', () {
      parser.feed([0x1B, 0x5B, 0x30, 0x6D]); // \e[0m
      final csi = actions[0] as CsiAction;
      expect(csi.finalByte, 0x6D); // 'm'
      expect(csi.params, [0]);
    });

    test('SGR multiple: ESC[1;31m (bold + red fg)', () {
      parser.feed([0x1B, 0x5B, 0x31, 0x3B, 0x33, 0x31, 0x6D]);
      final csi = actions[0] as CsiAction;
      expect(csi.finalByte, 0x6D);
      expect(csi.params, [1, 31]);
    });

    test('OSC window title: ESC]0;title BEL', () {
      // \e]0;My Title\x07
      parser.feed([0x1B, 0x5D, 0x30, 0x3B, ...('My Title'.codeUnits), 0x07]);
      expect(actions.length, 1);
      expect(actions[0], isA<OscAction>());
      final osc = actions[0] as OscAction;
      expect(osc.params, '0;My Title');
    });

    test('OSC terminated by ST (ESC \\)', () {
      parser.feed([0x1B, 0x5D, 0x30, 0x3B, ...('Title'.codeUnits), 0x1B, 0x5C]);
      expect(actions.length, 1);
      expect(actions[0], isA<OscAction>());
    });

    test('partial sequence: split across feeds', () {
      parser.feed([0x1B]); // just ESC
      expect(actions.length, 0); // waiting for more
      parser.feed([0x5B, 0x41]); // [A
      expect(actions.length, 1);
      expect(actions[0], isA<CsiAction>());
    });

    test('UTF-8 multibyte character', () {
      // '€' = U+20AC = 0xE2 0x82 0xAC in UTF-8
      parser.feed([0xE2, 0x82, 0xAC]);
      expect(actions.length, 1);
      expect(actions[0], isA<PrintAction>());
      expect((actions[0] as PrintAction).codepoint, 0x20AC);
    });

    test('alternate screen on: ESC[?1049h', () {
      parser.feed([0x1B, 0x5B, 0x3F, 0x31, 0x30, 0x34, 0x39, 0x68]);
      expect(actions.length, 1);
      expect(actions[0], isA<DecPrivateAction>());
      final dec = actions[0] as DecPrivateAction;
      expect(dec.mode, 1049);
      expect(dec.set, true);
    });

    test('alternate screen off: ESC[?1049l', () {
      parser.feed([0x1B, 0x5B, 0x3F, 0x31, 0x30, 0x34, 0x39, 0x6C]);
      final dec = actions[0] as DecPrivateAction;
      expect(dec.mode, 1049);
      expect(dec.set, false);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/dispatch_terminal && flutter test test/vt_parser_test.dart`
Expected: FAIL — cannot find `vt_parser.dart`

- [ ] **Step 3: Implement VtParser**

```dart
// packages/dispatch_terminal/lib/src/vt_parser.dart

/// Actions emitted by the VT parser.
sealed class VtAction {}

class PrintAction extends VtAction {
  final int codepoint;
  PrintAction(this.codepoint);
}

class LinefeedAction extends VtAction {}
class CarriageReturnAction extends VtAction {}
class BackspaceAction extends VtAction {}
class TabAction extends VtAction {}
class BellAction extends VtAction {}

class CsiAction extends VtAction {
  final int finalByte;
  final List<int> params;
  CsiAction(this.finalByte, this.params);
}

class OscAction extends VtAction {
  final String params;
  OscAction(this.params);
}

class DecPrivateAction extends VtAction {
  final int mode;
  final bool set;
  DecPrivateAction(this.mode, this.set);
}

class EscAction extends VtAction {
  final int finalByte;
  EscAction(this.finalByte);
}

enum _State {
  ground,
  escape,
  csiEntry,
  csiParam,
  oscString,
  utf8,
}

/// VT100/xterm escape sequence parser.
///
/// Feed bytes in, get structured [VtAction]s out via the [onAction] callback.
class VtParser {
  final void Function(VtAction action) onAction;

  _State _state = _State.ground;
  final List<int> _paramBuffer = [];
  final List<int> _oscBuffer = [];
  bool _csiPrivate = false;

  // UTF-8 decoding state
  int _utf8Codepoint = 0;
  int _utf8Remaining = 0;

  VtParser({required this.onAction});

  void feed(List<int> bytes) {
    for (final byte in bytes) {
      _process(byte);
    }
  }

  void _process(int byte) {
    // Handle UTF-8 continuation bytes in ground state
    if (_state == _State.utf8) {
      if ((byte & 0xC0) == 0x80) {
        _utf8Codepoint = (_utf8Codepoint << 6) | (byte & 0x3F);
        _utf8Remaining--;
        if (_utf8Remaining == 0) {
          onAction(PrintAction(_utf8Codepoint));
          _state = _State.ground;
        }
        return;
      } else {
        // Invalid continuation — reset and reprocess
        _state = _State.ground;
      }
    }

    switch (_state) {
      case _State.ground:
        _processGround(byte);
      case _State.escape:
        _processEscape(byte);
      case _State.csiEntry:
      case _State.csiParam:
        _processCsi(byte);
      case _State.oscString:
        _processOsc(byte);
      case _State.utf8:
        break; // handled above
    }
  }

  void _processGround(int byte) {
    if (byte == 0x1B) {
      _state = _State.escape;
    } else if (byte == 0x0A || byte == 0x0B || byte == 0x0C) {
      onAction(LinefeedAction());
    } else if (byte == 0x0D) {
      onAction(CarriageReturnAction());
    } else if (byte == 0x08) {
      onAction(BackspaceAction());
    } else if (byte == 0x09) {
      onAction(TabAction());
    } else if (byte == 0x07) {
      onAction(BellAction());
    } else if (byte >= 0x20 && byte < 0x7F) {
      onAction(PrintAction(byte));
    } else if ((byte & 0xE0) == 0xC0) {
      // 2-byte UTF-8
      _utf8Codepoint = byte & 0x1F;
      _utf8Remaining = 1;
      _state = _State.utf8;
    } else if ((byte & 0xF0) == 0xE0) {
      // 3-byte UTF-8
      _utf8Codepoint = byte & 0x0F;
      _utf8Remaining = 2;
      _state = _State.utf8;
    } else if ((byte & 0xF8) == 0xF0) {
      // 4-byte UTF-8
      _utf8Codepoint = byte & 0x07;
      _utf8Remaining = 3;
      _state = _State.utf8;
    }
    // Other C0 controls silently ignored
  }

  void _processEscape(int byte) {
    if (byte == 0x5B) {
      // ESC [ → CSI
      _state = _State.csiEntry;
      _paramBuffer.clear();
      _csiPrivate = false;
    } else if (byte == 0x5D) {
      // ESC ] → OSC
      _state = _State.oscString;
      _oscBuffer.clear();
    } else if (byte == 0x5C) {
      // ESC \ → ST (string terminator) — no-op if not in string
      _state = _State.ground;
    } else if (byte >= 0x40 && byte < 0x7F) {
      // ESC + final byte
      onAction(EscAction(byte));
      _state = _State.ground;
    } else {
      // Unknown — return to ground
      _state = _State.ground;
    }
  }

  void _processCsi(int byte) {
    if (byte == 0x3F && _state == _State.csiEntry) {
      // '?' private mode indicator
      _csiPrivate = true;
      _state = _State.csiParam;
    } else if (byte >= 0x30 && byte <= 0x39) {
      // Digit — accumulate param
      _paramBuffer.add(byte);
      _state = _State.csiParam;
    } else if (byte == 0x3B) {
      // ';' — param separator
      _paramBuffer.add(byte);
      _state = _State.csiParam;
    } else if (byte >= 0x40 && byte <= 0x7E) {
      // Final byte
      final params = _parseParams();

      if (_csiPrivate) {
        final mode = params.isNotEmpty ? params[0] : 0;
        final set = byte == 0x68; // 'h' = set, 'l' = reset
        onAction(DecPrivateAction(mode, set));
      } else {
        onAction(CsiAction(byte, params));
      }
      _state = _State.ground;
    } else {
      // Intermediate byte or unknown — stay in CSI
      _state = _State.csiParam;
    }
  }

  List<int> _parseParams() {
    if (_paramBuffer.isEmpty) return [];
    final str = String.fromCharCodes(_paramBuffer);
    return str.split(';').map((s) => int.tryParse(s) ?? 0).toList();
  }

  void _processOsc(int byte) {
    if (byte == 0x07) {
      // BEL terminates OSC
      onAction(OscAction(String.fromCharCodes(_oscBuffer)));
      _state = _State.ground;
    } else if (byte == 0x1B) {
      // Might be ESC \ (ST)
      // Peek ahead: if next byte is \, terminate. For now, emit and go to escape.
      onAction(OscAction(String.fromCharCodes(_oscBuffer)));
      _state = _State.escape;
    } else {
      _oscBuffer.add(byte);
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/dispatch_terminal && flutter test test/vt_parser_test.dart`
Expected: All 16 tests PASS

- [ ] **Step 5: Export from barrel**

Add to `packages/dispatch_terminal/lib/dispatch_terminal.dart`:
```dart
export 'src/vt_parser.dart';
```

- [ ] **Step 6: Commit**

```bash
git add packages/dispatch_terminal/lib/src/vt_parser.dart packages/dispatch_terminal/test/vt_parser_test.dart packages/dispatch_terminal/lib/dispatch_terminal.dart
git commit -m "feat(terminal): add VT parser with CSI, OSC, DEC private mode, UTF-8"
```

---

### Task 5: Terminal Controller

**Files:**
- Create: `packages/dispatch_terminal/lib/src/terminal.dart`
- Create: `packages/dispatch_terminal/test/terminal_test.dart`

The Terminal controller wires the VT parser to the screen buffer — it interprets parsed actions and applies them to the buffer.

- [ ] **Step 1: Write failing tests**

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/dispatch_terminal && flutter test test/terminal_test.dart`
Expected: FAIL — cannot find `terminal.dart`

- [ ] **Step 3: Implement Terminal controller**

```dart
// packages/dispatch_terminal/lib/src/terminal.dart
import 'dart:convert';
import 'cell.dart';
import 'screen_buffer.dart';
import 'vt_parser.dart';

class Terminal {
  final ScreenBuffer buffer;
  late final VtParser _parser;
  final void Function(String title)? onTitle;
  final void Function()? onBell;

  /// Standard 8 ANSI colors (normal intensity).
  static const List<int> ansiColors = [
    0xFF000000, // 0: black
    0xFFCD0000, // 1: red
    0xFF00CD00, // 2: green
    0xFFCDCD00, // 3: yellow
    0xFF0000EE, // 4: blue
    0xFFCD00CD, // 5: magenta
    0xFF00CDCD, // 6: cyan
    0xFFE5E5E5, // 7: white
  ];

  /// Bright ANSI colors.
  static const List<int> ansiBrightColors = [
    0xFF7F7F7F, // 8: bright black
    0xFFFF0000, // 9: bright red
    0xFF00FF00, // 10: bright green
    0xFFFFFF00, // 11: bright yellow
    0xFF5C5CFF, // 12: bright blue
    0xFFFF00FF, // 13: bright magenta
    0xFF00FFFF, // 14: bright cyan
    0xFFFFFFFF, // 15: bright white
  ];

  Terminal({
    required int cols,
    required int rows,
    this.onTitle,
    this.onBell,
    int maxScrollback = 5000,
  }) : buffer = ScreenBuffer(cols: cols, rows: rows, maxScrollback: maxScrollback) {
    _parser = VtParser(onAction: _handleAction);
  }

  /// Feed raw text (as from a PTY) into the terminal.
  void write(String data) {
    _parser.feed(utf8.encode(data));
  }

  /// Feed raw bytes into the terminal.
  void writeBytes(List<int> bytes) {
    _parser.feed(bytes);
  }

  void resize(int cols, int rows) {
    buffer.resize(cols, rows);
  }

  void _handleAction(VtAction action) {
    switch (action) {
      case PrintAction(:final codepoint):
        buffer.writeChar(codepoint);

      case LinefeedAction():
        if (buffer.cursorRow >= buffer.rows - 1) {
          buffer.scrollUp(1);
        } else {
          buffer.moveCursorRelative(1, 0);
        }

      case CarriageReturnAction():
        buffer.moveCursorTo(buffer.cursorRow, 0);

      case BackspaceAction():
        if (buffer.cursorCol > 0) {
          buffer.moveCursorRelative(0, -1);
        }

      case TabAction():
        final nextTab = ((buffer.cursorCol ~/ 8) + 1) * 8;
        buffer.moveCursorTo(buffer.cursorRow, nextTab.clamp(0, buffer.cols - 1));

      case BellAction():
        onBell?.call();

      case CsiAction(:final finalByte, :final params):
        _handleCsi(finalByte, params);

      case OscAction(:final params):
        _handleOsc(params);

      case DecPrivateAction(:final mode, :final set):
        _handleDecPrivate(mode, set);

      case EscAction(:final finalByte):
        _handleEsc(finalByte);
    }
  }

  void _handleCsi(int finalByte, List<int> params) {
    int param(int index, [int defaultValue = 1]) =>
        (index < params.length && params[index] > 0) ? params[index] : defaultValue;

    switch (finalByte) {
      case 0x41: // 'A' — cursor up
        buffer.moveCursorRelative(-param(0), 0);
      case 0x42: // 'B' — cursor down
        buffer.moveCursorRelative(param(0), 0);
      case 0x43: // 'C' — cursor forward
        buffer.moveCursorRelative(0, param(0));
      case 0x44: // 'D' — cursor back
        buffer.moveCursorRelative(0, -param(0));
      case 0x48: // 'H' — cursor position
      case 0x66: // 'f' — cursor position (alternate)
        buffer.moveCursorTo(param(0) - 1, param(1) - 1);
      case 0x4A: // 'J' — erase in display
        buffer.eraseInDisplay(param(0, 0));
      case 0x4B: // 'K' — erase in line
        buffer.eraseInLine(param(0, 0));
      case 0x53: // 'S' — scroll up
        buffer.scrollUp(param(0));
      case 0x54: // 'T' — scroll down
        buffer.scrollDown(param(0));
      case 0x6D: // 'm' — SGR (select graphic rendition)
        _handleSgr(params);
      case 0x64: // 'd' — line position absolute
        buffer.moveCursorTo(param(0) - 1, buffer.cursorCol);
      case 0x47: // 'G' — cursor horizontal absolute
        buffer.moveCursorTo(buffer.cursorRow, param(0) - 1);
      case 0x45: // 'E' — cursor next line
        buffer.moveCursorTo(buffer.cursorRow + param(0), 0);
      case 0x46: // 'F' — cursor previous line
        buffer.moveCursorTo(buffer.cursorRow - param(0), 0);
    }
  }

  void _handleSgr(List<int> params) {
    if (params.isEmpty) params = [0];

    int i = 0;
    while (i < params.length) {
      final p = params[i];
      switch (p) {
        case 0: // reset
          buffer.pen = const Cell();
        case 1: // bold
          buffer.pen = buffer.pen.copyWith(bold: true);
        case 3: // italic
          buffer.pen = buffer.pen.copyWith(italic: true);
        case 4: // underline
          buffer.pen = buffer.pen.copyWith(underline: true);
        case 5: // blink
          buffer.pen = buffer.pen.copyWith(blink: true);
        case 7: // inverse
          buffer.pen = buffer.pen.copyWith(inverse: true);
        case 9: // strikethrough
          buffer.pen = buffer.pen.copyWith(strikethrough: true);
        case 22: // normal intensity (not bold)
          buffer.pen = buffer.pen.copyWith(bold: false);
        case 23: // not italic
          buffer.pen = buffer.pen.copyWith(italic: false);
        case 24: // not underlined
          buffer.pen = buffer.pen.copyWith(underline: false);
        case 25: // not blinking
          buffer.pen = buffer.pen.copyWith(blink: false);
        case 27: // not inverse
          buffer.pen = buffer.pen.copyWith(inverse: false);
        case 29: // not strikethrough
          buffer.pen = buffer.pen.copyWith(strikethrough: false);
        case >= 30 && <= 37: // foreground 8-color
          buffer.pen = buffer.pen.copyWith(fg: ansiColors[p - 30]);
        case 38: // extended foreground
          i = _parseSgrExtendedColor(params, i, isForeground: true);
        case 39: // default foreground
          buffer.pen = buffer.pen.copyWith(fg: Cell.defaultFg);
        case >= 40 && <= 47: // background 8-color
          buffer.pen = buffer.pen.copyWith(bg: ansiColors[p - 40]);
        case 48: // extended background
          i = _parseSgrExtendedColor(params, i, isForeground: false);
        case 49: // default background
          buffer.pen = buffer.pen.copyWith(bg: Cell.defaultBg);
        case >= 90 && <= 97: // bright foreground
          buffer.pen = buffer.pen.copyWith(fg: ansiBrightColors[p - 90]);
        case >= 100 && <= 107: // bright background
          buffer.pen = buffer.pen.copyWith(bg: ansiBrightColors[p - 100]);
      }
      i++;
    }
  }

  int _parseSgrExtendedColor(List<int> params, int i, {required bool isForeground}) {
    if (i + 1 >= params.length) return i;

    if (params[i + 1] == 5 && i + 2 < params.length) {
      // 256-color: 38;5;N or 48;5;N
      final colorIndex = params[i + 2];
      final color = _color256(colorIndex);
      if (isForeground) {
        buffer.pen = buffer.pen.copyWith(fg: color);
      } else {
        buffer.pen = buffer.pen.copyWith(bg: color);
      }
      return i + 2;
    } else if (params[i + 1] == 2 && i + 4 < params.length) {
      // 24-bit: 38;2;R;G;B or 48;2;R;G;B
      final r = params[i + 2].clamp(0, 255);
      final g = params[i + 3].clamp(0, 255);
      final b = params[i + 4].clamp(0, 255);
      final color = 0xFF000000 | (r << 16) | (g << 8) | b;
      if (isForeground) {
        buffer.pen = buffer.pen.copyWith(fg: color);
      } else {
        buffer.pen = buffer.pen.copyWith(bg: color);
      }
      return i + 4;
    }
    return i;
  }

  int _color256(int index) {
    if (index < 8) return ansiColors[index];
    if (index < 16) return ansiBrightColors[index - 8];
    if (index < 232) {
      // 216-color cube: 16 + 36*r + 6*g + b
      final i = index - 16;
      final r = (i ~/ 36) * 51;
      final g = ((i % 36) ~/ 6) * 51;
      final b = (i % 6) * 51;
      return 0xFF000000 | (r << 16) | (g << 8) | b;
    }
    // Grayscale: 232-255 → 8 to 238 in steps of 10
    final gray = 8 + (index - 232) * 10;
    return 0xFF000000 | (gray << 16) | (gray << 8) | gray;
  }

  void _handleOsc(String params) {
    // OSC 0;title — set window title
    // OSC 2;title — set window title
    final semicolon = params.indexOf(';');
    if (semicolon == -1) return;
    final code = int.tryParse(params.substring(0, semicolon));
    final value = params.substring(semicolon + 1);
    if (code == 0 || code == 2) {
      onTitle?.call(value);
    }
  }

  void _handleDecPrivate(int mode, bool set) {
    switch (mode) {
      case 1049: // alternate screen
        if (set) {
          buffer.switchToAlternateScreen();
        } else {
          buffer.switchToPrimaryScreen();
        }
      case 25: // cursor visibility — tracked but not rendered yet
        break;
    }
  }

  void _handleEsc(int finalByte) {
    switch (finalByte) {
      case 0x37: // ESC 7 — save cursor
        break; // TODO: implement cursor save/restore
      case 0x38: // ESC 8 — restore cursor
        break;
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/dispatch_terminal && flutter test test/terminal_test.dart`
Expected: All 17 tests PASS

- [ ] **Step 5: Export from barrel**

Add to `packages/dispatch_terminal/lib/dispatch_terminal.dart`:
```dart
export 'src/terminal.dart';
```

- [ ] **Step 6: Commit**

```bash
git add packages/dispatch_terminal/lib/src/terminal.dart packages/dispatch_terminal/test/terminal_test.dart packages/dispatch_terminal/lib/dispatch_terminal.dart
git commit -m "feat(terminal): add Terminal controller wiring VT parser to screen buffer"
```

---

### Task 6: PTY FFI Bridge

**Files:**
- Create: `packages/dispatch_terminal/lib/src/pty_ffi.dart`
- Create: `packages/dispatch_terminal/test/pty_ffi_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// packages/dispatch_terminal/test/pty_ffi_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_terminal/src/pty_ffi.dart';
import 'dart:io';

void main() {
  group('PtyFfi', () {
    test('spawn creates a PTY and returns valid fd and pid', () {
      final result = PtyFfi.spawn(
        executable: Platform.environment['SHELL'] ?? '/bin/sh',
        args: [],
        cwd: Directory.systemTemp.path,
        env: {'TERM': 'xterm-256color'},
        rows: 24,
        cols: 80,
      );
      expect(result.masterFd, greaterThan(0));
      expect(result.pid, greaterThan(0));

      // Clean up
      PtyFfi.kill(result.pid, 15); // SIGTERM
      PtyFfi.close(result.masterFd);
    });

    test('write and read from PTY', () async {
      final result = PtyFfi.spawn(
        executable: '/bin/sh',
        args: [],
        cwd: Directory.systemTemp.path,
        env: {'TERM': 'xterm-256color'},
        rows: 24,
        cols: 80,
      );

      // Write a command
      PtyFfi.write(result.masterFd, 'echo hello_pty_test\n');

      // Give the shell time to process
      await Future.delayed(const Duration(milliseconds: 200));

      // Read response
      final output = PtyFfi.read(result.masterFd);
      expect(output, isNotNull);
      expect(output!, contains('hello_pty_test'));

      PtyFfi.kill(result.pid, 15);
      PtyFfi.close(result.masterFd);
    });

    test('resize PTY', () {
      final result = PtyFfi.spawn(
        executable: '/bin/sh',
        args: [],
        cwd: Directory.systemTemp.path,
        env: {'TERM': 'xterm-256color'},
        rows: 24,
        cols: 80,
      );

      // Should not throw
      PtyFfi.resize(result.masterFd, rows: 40, cols: 120);

      PtyFfi.kill(result.pid, 15);
      PtyFfi.close(result.masterFd);
    });

    test('waitpid detects exit', () async {
      final result = PtyFfi.spawn(
        executable: '/bin/sh',
        args: ['-c', 'exit 0'],
        cwd: Directory.systemTemp.path,
        env: {'TERM': 'xterm-256color'},
        rows: 24,
        cols: 80,
      );

      // Wait for child to exit
      await Future.delayed(const Duration(milliseconds: 300));
      final status = PtyFfi.waitpid(result.pid, noHang: true);
      expect(status, isNotNull);

      PtyFfi.close(result.masterFd);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/dispatch_terminal && flutter test test/pty_ffi_test.dart`
Expected: FAIL — cannot find `pty_ffi.dart`

- [ ] **Step 3: Implement PtyFfi**

```dart
// packages/dispatch_terminal/lib/src/pty_ffi.dart
import 'dart:ffi';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

/// Result of spawning a PTY.
class PtySpawnResult {
  final int masterFd;
  final int pid;
  PtySpawnResult({required this.masterFd, required this.pid});
}

/// Result of waitpid.
class WaitResult {
  final int pid;
  final int status;
  WaitResult({required this.pid, required this.status});
}

// POSIX typedefs
typedef _ForkptyNative = Int32 Function(
  Pointer<Int32> masterFd,
  Pointer<Void> name,
  Pointer<Void> termp,
  Pointer<Void> winp,
);
typedef _ForkptyDart = int Function(
  Pointer<Int32> masterFd,
  Pointer<Void> name,
  Pointer<Void> termp,
  Pointer<Void> winp,
);

typedef _ReadNative = Int64 Function(Int32 fd, Pointer<Void> buf, Int64 count);
typedef _ReadDart = int Function(int fd, Pointer<Void> buf, int count);

typedef _WriteNative = Int64 Function(Int32 fd, Pointer<Void> buf, Int64 count);
typedef _WriteDart = int Function(int fd, Pointer<Void> buf, int count);

typedef _CloseNative = Int32 Function(Int32 fd);
typedef _CloseDart = int Function(int fd);

typedef _KillNative = Int32 Function(Int32 pid, Int32 sig);
typedef _KillDart = int Function(int pid, int sig);

typedef _IoctlNative = Int32 Function(Int32 fd, Int64 request, Pointer<Void> arg);
typedef _IoctlDart = int Function(int fd, int request, Pointer<Void> arg);

typedef _WaitpidNative = Int32 Function(Int32 pid, Pointer<Int32> status, Int32 options);
typedef _WaitpidDart = int Function(int pid, Pointer<Int32> status, int options);

typedef _ExecvpeNative = Int32 Function(
  Pointer<Utf8> file,
  Pointer<Pointer<Utf8>> argv,
  Pointer<Pointer<Utf8>> envp,
);

typedef _SetenvNative = Int32 Function(Pointer<Utf8> name, Pointer<Utf8> value, Int32 overwrite);
typedef _SetenvDart = int Function(Pointer<Utf8> name, Pointer<Utf8> value, int overwrite);

typedef _ChdirNative = Int32 Function(Pointer<Utf8> path);
typedef _ChdirDart = int Function(Pointer<Utf8> path);

// winsize struct for TIOCSWINSZ
final class Winsize extends Struct {
  @Uint16()
  external int wsRow;

  @Uint16()
  external int wsCol;

  @Uint16()
  external int wsXpixel;

  @Uint16()
  external int wsYpixel;
}

/// Low-level PTY operations via dart:ffi.
class PtyFfi {
  static final DynamicLibrary _util = DynamicLibrary.process();

  static final _forkpty = _util.lookupFunction<_ForkptyNative, _ForkptyDart>('forkpty');
  static final _read = _util.lookupFunction<_ReadNative, _ReadDart>('read');
  static final _write = _util.lookupFunction<_WriteNative, _WriteDart>('write');
  static final _close = _util.lookupFunction<_CloseNative, _CloseDart>('close');
  static final _kill = _util.lookupFunction<_KillNative, _KillDart>('kill');
  static final _ioctl = _util.lookupFunction<_IoctlNative, _IoctlDart>('ioctl');
  static final _waitpid = _util.lookupFunction<_WaitpidNative, _WaitpidDart>('waitpid');
  static final _setenv = _util.lookupFunction<_SetenvNative, _SetenvDart>('setenv');
  static final _chdir = _util.lookupFunction<_ChdirNative, _ChdirDart>('chdir');
  static final _execvp = _util.lookupFunction<
      Int32 Function(Pointer<Utf8>, Pointer<Pointer<Utf8>>),
      int Function(Pointer<Utf8>, Pointer<Pointer<Utf8>>)>('execvp');

  // TIOCSWINSZ on macOS
  static const int _TIOCSWINSZ = 0x80087467;
  // WNOHANG for waitpid
  static const int _WNOHANG = 1;

  /// Spawn a new PTY with the given shell.
  static PtySpawnResult spawn({
    required String executable,
    required List<String> args,
    required String cwd,
    required Map<String, String> env,
    required int rows,
    required int cols,
  }) {
    // Set up winsize
    final winp = calloc<Winsize>();
    winp.ref.wsRow = rows;
    winp.ref.wsCol = cols;
    winp.ref.wsXpixel = 0;
    winp.ref.wsYpixel = 0;

    final masterFdPtr = calloc<Int32>();

    final pid = _forkpty(
      masterFdPtr,
      nullptr,
      nullptr,
      winp.cast(),
    );

    if (pid < 0) {
      calloc.free(masterFdPtr);
      calloc.free(winp);
      throw OSError('forkpty failed');
    }

    if (pid == 0) {
      // Child process
      // Set environment
      for (final entry in env.entries) {
        final key = entry.key.toNativeUtf8();
        final val = entry.value.toNativeUtf8();
        _setenv(key, val, 1);
        calloc.free(key);
        calloc.free(val);
      }

      // Change directory
      final cwdNative = cwd.toNativeUtf8();
      _chdir(cwdNative);
      calloc.free(cwdNative);

      // Build argv
      final allArgs = [executable, ...args];
      final argv = calloc<Pointer<Utf8>>(allArgs.length + 1);
      for (var i = 0; i < allArgs.length; i++) {
        argv[i] = allArgs[i].toNativeUtf8();
      }
      argv[allArgs.length] = nullptr;

      final execPath = executable.toNativeUtf8();
      _execvp(execPath, argv);

      // If exec fails, exit
      exit(1);
    }

    // Parent process
    final masterFd = masterFdPtr.value;
    calloc.free(masterFdPtr);
    calloc.free(winp);

    return PtySpawnResult(masterFd: masterFd, pid: pid);
  }

  /// Read available data from the PTY. Returns null if no data available.
  static String? read(int fd) {
    final buf = calloc<Uint8>(4096);
    final n = _read(fd, buf.cast(), 4096);
    if (n <= 0) {
      calloc.free(buf);
      return null;
    }
    final bytes = Uint8List(n);
    for (var i = 0; i < n; i++) {
      bytes[i] = buf[i];
    }
    calloc.free(buf);
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Read raw bytes from PTY. Returns null if no data.
  static Uint8List? readBytes(int fd) {
    final buf = calloc<Uint8>(4096);
    final n = _read(fd, buf.cast(), 4096);
    if (n <= 0) {
      calloc.free(buf);
      return null;
    }
    final bytes = Uint8List(n);
    for (var i = 0; i < n; i++) {
      bytes[i] = buf[i];
    }
    calloc.free(buf);
    return bytes;
  }

  /// Write data to the PTY.
  static void write(int fd, String data) {
    final bytes = utf8.encode(data);
    final buf = calloc<Uint8>(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      buf[i] = bytes[i];
    }
    _write(fd, buf.cast(), bytes.length);
    calloc.free(buf);
  }

  /// Write raw bytes to the PTY.
  static void writeBytes(int fd, Uint8List bytes) {
    final buf = calloc<Uint8>(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      buf[i] = bytes[i];
    }
    _write(fd, buf.cast(), bytes.length);
    calloc.free(buf);
  }

  /// Resize the PTY.
  static void resize(int fd, {required int rows, required int cols}) {
    final winp = calloc<Winsize>();
    winp.ref.wsRow = rows;
    winp.ref.wsCol = cols;
    winp.ref.wsXpixel = 0;
    winp.ref.wsYpixel = 0;
    _ioctl(fd, _TIOCSWINSZ, winp.cast());
    calloc.free(winp);
  }

  /// Send a signal to the child process.
  static void kill(int pid, int signal) {
    _kill(pid, signal);
  }

  /// Close a file descriptor.
  static void close(int fd) {
    _close(fd);
  }

  /// Check if child has exited. Returns WaitResult if exited, null if still running.
  static WaitResult? waitpid(int pid, {bool noHang = false}) {
    final statusPtr = calloc<Int32>();
    final result = _waitpid(pid, statusPtr, noHang ? _WNOHANG : 0);
    final status = statusPtr.value;
    calloc.free(statusPtr);
    if (result <= 0) return null;
    return WaitResult(pid: result, status: status);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/dispatch_terminal && flutter test test/pty_ffi_test.dart`
Expected: All 4 tests PASS

Note: These are integration tests that spawn real shells. They may need a small timeout adjustment. If `forkpty` is not directly available via `DynamicLibrary.process()` on macOS, you may need to load `libutil.dylib` instead:
```dart
static final DynamicLibrary _util = DynamicLibrary.open('libutil.dylib');
```

- [ ] **Step 5: Export from barrel**

Add to `packages/dispatch_terminal/lib/dispatch_terminal.dart`:
```dart
export 'src/pty_ffi.dart';
```

- [ ] **Step 6: Commit**

```bash
git add packages/dispatch_terminal/lib/src/pty_ffi.dart packages/dispatch_terminal/test/pty_ffi_test.dart packages/dispatch_terminal/lib/dispatch_terminal.dart
git commit -m "feat(terminal): add PTY FFI bridge with forkpty, read, write, resize"
```

---

### Task 7: PTY Manager (Isolate)

**Files:**
- Create: `packages/dispatch_terminal/lib/src/pty_manager.dart`
- Create: `packages/dispatch_terminal/test/pty_manager_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// packages/dispatch_terminal/test/pty_manager_test.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_terminal/src/pty_manager.dart';

void main() {
  group('PtyManager', () {
    late PtyManager manager;

    setUp(() {
      manager = PtyManager();
    });

    tearDown(() {
      manager.disposeAll();
    });

    test('spawn returns a PtySession with valid id', () async {
      final session = await manager.spawn(
        executable: Platform.environment['SHELL'] ?? '/bin/sh',
        cwd: Directory.systemTemp.path,
        cols: 80,
        rows: 24,
      );
      expect(session.id, isNotEmpty);
      session.dispose();
    });

    test('session emits data on stdout', () async {
      final session = await manager.spawn(
        executable: '/bin/sh',
        cwd: Directory.systemTemp.path,
        cols: 80,
        rows: 24,
      );

      final completer = Completer<String>();
      final buffer = StringBuffer();
      final sub = session.dataStream.listen((data) {
        buffer.write(data);
        if (buffer.toString().contains('pty_test_output')) {
          if (!completer.isCompleted) completer.complete(buffer.toString());
        }
      });

      session.write('echo pty_test_output\n');

      final output = await completer.timeout(const Duration(seconds: 3));
      expect(output, contains('pty_test_output'));

      await sub.cancel();
      session.dispose();
    });

    test('session emits exit event', () async {
      final session = await manager.spawn(
        executable: '/bin/sh',
        args: ['-c', 'exit 42'],
        cwd: Directory.systemTemp.path,
        cols: 80,
        rows: 24,
      );

      final exitCode = await session.exitCode.timeout(const Duration(seconds: 3));
      expect(exitCode, isNotNull);
    });

    test('resize does not throw', () async {
      final session = await manager.spawn(
        executable: '/bin/sh',
        cwd: Directory.systemTemp.path,
        cols: 80,
        rows: 24,
      );

      expect(() => session.resize(120, 40), returnsNormally);
      session.dispose();
    });

    test('disposeAll cleans up all sessions', () async {
      await manager.spawn(
        executable: '/bin/sh',
        cwd: Directory.systemTemp.path,
        cols: 80,
        rows: 24,
      );
      await manager.spawn(
        executable: '/bin/sh',
        cwd: Directory.systemTemp.path,
        cols: 80,
        rows: 24,
      );

      expect(manager.sessionCount, 2);
      manager.disposeAll();
      expect(manager.sessionCount, 0);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/dispatch_terminal && flutter test test/pty_manager_test.dart`
Expected: FAIL — cannot find `pty_manager.dart`

- [ ] **Step 3: Implement PtyManager**

```dart
// packages/dispatch_terminal/lib/src/pty_manager.dart
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'pty_ffi.dart';

/// Messages sent from main isolate to PTY isolate.
sealed class _PtyCommand {}

class _WriteCommand extends _PtyCommand {
  final String data;
  _WriteCommand(this.data);
}

class _ResizeCommand extends _PtyCommand {
  final int cols;
  final int rows;
  _ResizeCommand(this.cols, this.rows);
}

class _DisposeCommand extends _PtyCommand {}

/// Messages sent from PTY isolate to main isolate.
sealed class _PtyEvent {}

class _DataEvent extends _PtyEvent {
  final String data;
  _DataEvent(this.data);
}

class _ExitEvent extends _PtyEvent {
  final int exitCode;
  _ExitEvent(this.exitCode);
}

class _ErrorEvent extends _PtyEvent {
  final String message;
  _ErrorEvent(this.message);
}

/// Init message sent to the PTY isolate.
class _PtyInit {
  final SendPort sendPort;
  final String executable;
  final List<String> args;
  final String cwd;
  final Map<String, String> env;
  final int cols;
  final int rows;

  _PtyInit({
    required this.sendPort,
    required this.executable,
    required this.args,
    required this.cwd,
    required this.env,
    required this.cols,
    required this.rows,
  });
}

/// A live PTY session managed by a background isolate.
class PtySession {
  final String id;
  final Stream<String> dataStream;
  final Future<int> exitCode;
  final SendPort _commandPort;
  final Isolate _isolate;

  PtySession({
    required this.id,
    required this.dataStream,
    required this.exitCode,
    required SendPort commandPort,
    required Isolate isolate,
  })  : _commandPort = commandPort,
        _isolate = isolate;

  void write(String data) {
    _commandPort.send(_WriteCommand(data));
  }

  void resize(int cols, int rows) {
    _commandPort.send(_ResizeCommand(cols, rows));
  }

  void dispose() {
    _commandPort.send(_DisposeCommand());
  }
}

/// Manages PTY sessions on background isolates.
class PtyManager {
  final Map<String, PtySession> _sessions = {};

  int get sessionCount => _sessions.length;

  Future<PtySession> spawn({
    required String executable,
    List<String> args = const [],
    required String cwd,
    Map<String, String> env = const {},
    required int cols,
    required int rows,
    String? command,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
        _sessions.length.toString();

    final receivePort = ReceivePort();
    final completer = Completer<SendPort>();
    final dataController = StreamController<String>.broadcast();
    final exitCompleter = Completer<int>();

    final fullEnv = {
      'TERM': 'xterm-256color',
      'COLORTERM': 'truecolor',
      ...env,
    };

    final isolate = await Isolate.spawn(
      _ptyIsolateEntry,
      _PtyInit(
        sendPort: receivePort.sendPort,
        executable: executable,
        args: args,
        cwd: cwd,
        env: fullEnv,
        cols: cols,
        rows: rows,
      ),
    );

    receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is _DataEvent) {
        dataController.add(message.data);
      } else if (message is _ExitEvent) {
        if (!exitCompleter.isCompleted) exitCompleter.complete(message.exitCode);
        _sessions.remove(id);
        dataController.close();
        receivePort.close();
      } else if (message is _ErrorEvent) {
        if (!exitCompleter.isCompleted) exitCompleter.complete(-1);
        _sessions.remove(id);
        dataController.close();
        receivePort.close();
      }
    });

    final commandPort = await completer.future;

    // If a command needs to be typed (e.g. 'claude'), send it after a delay
    if (command != null && command != '\$SHELL') {
      Future.delayed(const Duration(milliseconds: 150), () {
        commandPort.send(_WriteCommand('$command\n'));
      });
    }

    final session = PtySession(
      id: id,
      dataStream: dataController.stream,
      exitCode: exitCompleter.future,
      commandPort: commandPort,
      isolate: isolate,
    );

    _sessions[id] = session;
    return session;
  }

  void disposeAll() {
    for (final session in _sessions.values.toList()) {
      session.dispose();
    }
    _sessions.clear();
  }

  static void _ptyIsolateEntry(_PtyInit init) {
    final commandPort = ReceivePort();
    init.sendPort.send(commandPort.sendPort);

    late PtySpawnResult ptyResult;
    try {
      ptyResult = PtyFfi.spawn(
        executable: init.executable,
        args: init.args,
        cwd: init.cwd,
        env: init.env,
        rows: init.rows,
        cols: init.cols,
      );
    } catch (e) {
      init.sendPort.send(_ErrorEvent('Failed to spawn PTY: $e'));
      return;
    }

    bool running = true;

    // Read loop
    Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (!running) {
        timer.cancel();
        return;
      }

      final data = PtyFfi.read(ptyResult.masterFd);
      if (data != null) {
        init.sendPort.send(_DataEvent(data));
      }

      // Check if child exited
      final wait = PtyFfi.waitpid(ptyResult.pid, noHang: true);
      if (wait != null) {
        running = false;
        timer.cancel();
        PtyFfi.close(ptyResult.masterFd);
        init.sendPort.send(_ExitEvent(wait.status));
      }
    });

    // Command listener
    commandPort.listen((message) {
      if (!running) return;
      if (message is _WriteCommand) {
        PtyFfi.write(ptyResult.masterFd, message.data);
      } else if (message is _ResizeCommand) {
        PtyFfi.resize(ptyResult.masterFd, rows: message.rows, cols: message.cols);
      } else if (message is _DisposeCommand) {
        running = false;
        PtyFfi.kill(ptyResult.pid, 15); // SIGTERM
        Future.delayed(const Duration(milliseconds: 100), () {
          PtyFfi.close(ptyResult.masterFd);
          init.sendPort.send(_ExitEvent(0));
          commandPort.close();
        });
      }
    });
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/dispatch_terminal && flutter test test/pty_manager_test.dart`
Expected: All 5 tests PASS

- [ ] **Step 5: Export from barrel**

Add to `packages/dispatch_terminal/lib/dispatch_terminal.dart`:
```dart
export 'src/pty_manager.dart';
```

- [ ] **Step 6: Commit**

```bash
git add packages/dispatch_terminal/lib/src/pty_manager.dart packages/dispatch_terminal/test/pty_manager_test.dart packages/dispatch_terminal/lib/dispatch_terminal.dart
git commit -m "feat(terminal): add PtyManager with isolate-per-session architecture"
```

---

### Task 8: Terminal Theme

**Files:**
- Create: `packages/dispatch_terminal/lib/src/terminal_theme.dart`
- Create: `packages/dispatch_terminal/test/terminal_theme_test.dart` (minimal — this is data)

- [ ] **Step 1: Write failing test**

```dart
// packages/dispatch_terminal/test/terminal_theme_test.dart (minimal)
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/dispatch_terminal && flutter test test/terminal_theme_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement TerminalTheme**

```dart
// packages/dispatch_terminal/lib/src/terminal_theme.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/dispatch_terminal && flutter test test/terminal_theme_test.dart`
Expected: All 3 tests PASS

- [ ] **Step 5: Export from barrel**

Add to `packages/dispatch_terminal/lib/dispatch_terminal.dart`:
```dart
export 'src/terminal_theme.dart';
```

- [ ] **Step 6: Commit**

```bash
git add packages/dispatch_terminal/lib/src/terminal_theme.dart packages/dispatch_terminal/test/terminal_theme_test.dart packages/dispatch_terminal/lib/dispatch_terminal.dart
git commit -m "feat(terminal): add TerminalTheme with dark theme and ANSI colors"
```

---

### Task 9: Terminal Renderer

**Files:**
- Create: `packages/dispatch_terminal/lib/src/terminal_renderer.dart`
- Create: `packages/dispatch_terminal/test/terminal_renderer_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
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
      expect(find.byType(CustomPaint), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/dispatch_terminal && flutter test test/terminal_renderer_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement TerminalRenderer**

```dart
// packages/dispatch_terminal/lib/src/terminal_renderer.dart
import 'dart:ui' as ui;
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

        // Skip if off-screen
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/dispatch_terminal && flutter test test/terminal_renderer_test.dart`
Expected: All 5 tests PASS

- [ ] **Step 5: Export from barrel**

Add to `packages/dispatch_terminal/lib/dispatch_terminal.dart`:
```dart
export 'src/terminal_renderer.dart';
```

- [ ] **Step 6: Commit**

```bash
git add packages/dispatch_terminal/lib/src/terminal_renderer.dart packages/dispatch_terminal/test/terminal_renderer_test.dart packages/dispatch_terminal/lib/dispatch_terminal.dart
git commit -m "feat(terminal): add TerminalRenderer CustomPainter with cursor and attributes"
```

---

### Task 10: Terminal Widget (Public API)

**Files:**
- Create: `packages/dispatch_terminal/lib/src/terminal_widget.dart`
- Create: `packages/dispatch_terminal/test/terminal_widget_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// packages/dispatch_terminal/test/terminal_widget_test.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_terminal/src/terminal_widget.dart';
import 'package:dispatch_terminal/src/terminal.dart';
import 'package:dispatch_terminal/src/terminal_theme.dart';

void main() {
  group('TerminalView', () {
    late Terminal terminal;
    late StreamController<String> dataController;
    late List<String> writtenData;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
      dataController = StreamController<String>.broadcast();
      writtenData = [];
    });

    tearDown(() {
      dataController.close();
    });

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal: terminal,
            dataStream: dataController.stream,
            onInput: (data) => writtenData.add(data),
            fontSize: 13,
            fontFamily: 'monospace',
            theme: TerminalTheme.dark,
          ),
        ),
      ));

      expect(find.byType(TerminalView), findsOneWidget);
    });

    testWidgets('processes incoming data stream', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal: terminal,
            dataStream: dataController.stream,
            onInput: (data) => writtenData.add(data),
            fontSize: 13,
            fontFamily: 'monospace',
            theme: TerminalTheme.dark,
          ),
        ),
      ));

      dataController.add('Hello');
      await tester.pump();

      expect(terminal.buffer.cellAt(0, 0).char, 0x48); // H
    });

    testWidgets('keyboard input calls onInput', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal: terminal,
            dataStream: dataController.stream,
            onInput: (data) => writtenData.add(data),
            fontSize: 13,
            fontFamily: 'monospace',
            theme: TerminalTheme.dark,
            autofocus: true,
          ),
        ),
      ));
      await tester.pump();

      // Focus the widget
      await tester.tap(find.byType(TerminalView));
      await tester.pump();

      // Type a character
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(writtenData, contains('a'));
    });

    testWidgets('onTitle callback fires on OSC title', (tester) async {
      String? receivedTitle;
      final t = Terminal(
        cols: 80,
        rows: 24,
        onTitle: (title) => receivedTitle = title,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal: t,
            dataStream: dataController.stream,
            onInput: (_) {},
            fontSize: 13,
            fontFamily: 'monospace',
            theme: TerminalTheme.dark,
          ),
        ),
      ));

      dataController.add('\x1b]0;Test Title\x07');
      await tester.pump();

      expect(receivedTitle, 'Test Title');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/dispatch_terminal && flutter test test/terminal_widget_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement TerminalView**

```dart
// packages/dispatch_terminal/lib/src/terminal_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'terminal.dart';
import 'terminal_renderer.dart';
import 'terminal_theme.dart';

class TerminalView extends StatefulWidget {
  final Terminal terminal;
  final Stream<String> dataStream;
  final void Function(String data) onInput;
  final double fontSize;
  final String fontFamily;
  final TerminalTheme theme;
  final bool autofocus;
  final void Function(int cols, int rows)? onResize;

  const TerminalView({
    super.key,
    required this.terminal,
    required this.dataStream,
    required this.onInput,
    this.fontSize = 13,
    this.fontFamily = 'JetBrains Mono',
    this.theme = TerminalTheme.dark,
    this.autofocus = false,
    this.onResize,
  });

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  final FocusNode _focusNode = FocusNode();
  StreamSubscription<String>? _dataSub;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _dataSub = widget.dataStream.listen(_onData);
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataStream != widget.dataStream) {
      _dataSub?.cancel();
      _dataSub = widget.dataStream.listen(_onData);
    }
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onData(String data) {
    widget.terminal.write(data);
    setState(() {
      _generation++;
    });
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final key = event.logicalKey;
    final String data;

    // Map special keys to escape sequences
    if (key == LogicalKeyboardKey.enter) {
      data = '\r';
    } else if (key == LogicalKeyboardKey.backspace) {
      data = '\x7f';
    } else if (key == LogicalKeyboardKey.tab) {
      data = '\t';
    } else if (key == LogicalKeyboardKey.escape) {
      data = '\x1b';
    } else if (key == LogicalKeyboardKey.arrowUp) {
      data = '\x1b[A';
    } else if (key == LogicalKeyboardKey.arrowDown) {
      data = '\x1b[B';
    } else if (key == LogicalKeyboardKey.arrowRight) {
      data = '\x1b[C';
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      data = '\x1b[D';
    } else if (key == LogicalKeyboardKey.home) {
      data = '\x1b[H';
    } else if (key == LogicalKeyboardKey.end) {
      data = '\x1b[F';
    } else if (key == LogicalKeyboardKey.delete) {
      data = '\x1b[3~';
    } else if (key == LogicalKeyboardKey.pageUp) {
      data = '\x1b[5~';
    } else if (key == LogicalKeyboardKey.pageDown) {
      data = '\x1b[6~';
    } else if (event.character != null && event.character!.isNotEmpty) {
      // Handle Ctrl+key combinations
      if (HardwareKeyboard.instance.isControlPressed) {
        final char = event.character!.codeUnitAt(0);
        if (char >= 0x61 && char <= 0x7A) {
          // a-z → Ctrl+A-Z (0x01-0x1A)
          data = String.fromCharCode(char - 0x60);
        } else {
          data = event.character!;
        }
      } else {
        data = event.character!;
      }
    } else {
      return;
    }

    widget.onInput(data);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) {
        _onKey(event);
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _handleResize(constraints);
            return CustomPaint(
              painter: TerminalRenderer(
                buffer: widget.terminal.buffer,
                theme: widget.theme,
                fontSize: widget.fontSize,
                fontFamily: widget.fontFamily,
                generation: _generation,
                showCursor: _focusNode.hasFocus,
              ),
              size: Size(constraints.maxWidth, constraints.maxHeight),
            );
          },
        ),
      ),
    );
  }

  void _handleResize(BoxConstraints constraints) {
    final renderer = TerminalRenderer(
      buffer: widget.terminal.buffer,
      theme: widget.theme,
      fontSize: widget.fontSize,
      fontFamily: widget.fontFamily,
    );

    final newCols = (constraints.maxWidth / renderer.cellWidth).floor();
    final newRows = (constraints.maxHeight / renderer.cellHeight).floor();

    if (newCols > 0 &&
        newRows > 0 &&
        (newCols != widget.terminal.buffer.cols ||
            newRows != widget.terminal.buffer.rows)) {
      widget.terminal.resize(newCols, newRows);
      widget.onResize?.call(newCols, newRows);
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/dispatch_terminal && flutter test test/terminal_widget_test.dart`
Expected: All 4 tests PASS

- [ ] **Step 5: Export from barrel (final)**

Final `packages/dispatch_terminal/lib/dispatch_terminal.dart`:
```dart
library dispatch_terminal;

export 'src/cell.dart';
export 'src/screen_buffer.dart';
export 'src/vt_parser.dart';
export 'src/terminal.dart';
export 'src/pty_ffi.dart';
export 'src/pty_manager.dart';
export 'src/terminal_theme.dart';
export 'src/terminal_renderer.dart';
export 'src/terminal_widget.dart';
```

- [ ] **Step 6: Commit**

```bash
git add packages/dispatch_terminal/lib/src/terminal_widget.dart packages/dispatch_terminal/test/terminal_widget_test.dart packages/dispatch_terminal/lib/dispatch_terminal.dart
git commit -m "feat(terminal): add TerminalView widget — public API for the terminal engine"
```

---

### Task 11: Integration Smoke Test

**Files:**
- Create: `packages/dispatch_terminal/test/integration_test.dart`

A final integration test that wires everything together: Terminal + mock data stream + widget.

- [ ] **Step 1: Write integration test**

```dart
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
```

- [ ] **Step 2: Run integration test**

Run: `cd packages/dispatch_terminal && flutter test test/integration_test.dart`
Expected: All 2 tests PASS

- [ ] **Step 3: Run full test suite**

Run: `cd packages/dispatch_terminal && flutter test`
Expected: All tests across all files PASS

- [ ] **Step 4: Commit**

```bash
git add packages/dispatch_terminal/test/integration_test.dart
git commit -m "test(terminal): add integration smoke test for full terminal pipeline"
```

---

## Summary

| Task | Component | Tests |
|------|-----------|-------|
| 1 | Monorepo scaffold | — |
| 2 | Cell data model | 4 |
| 3 | Screen buffer | 12 |
| 4 | VT parser | 16 |
| 5 | Terminal controller | 17 |
| 6 | PTY FFI bridge | 4 |
| 7 | PTY Manager (isolate) | 5 |
| 8 | Terminal theme | 3 |
| 9 | Terminal renderer | 5 |
| 10 | Terminal widget | 4 |
| 11 | Integration smoke test | 2 |
| **Total** | **11 tasks** | **72 tests** |

After this plan is complete, the `dispatch_terminal` package is a fully functional, standalone terminal emulation engine ready to be composed into the app shell (Plan 2).
