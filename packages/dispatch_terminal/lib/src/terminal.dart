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
        break;
      case 0x38: // ESC 8 — restore cursor
        break;
    }
  }
}
