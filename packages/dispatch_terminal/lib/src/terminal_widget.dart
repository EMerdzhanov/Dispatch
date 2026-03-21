// packages/dispatch_terminal/lib/src/terminal_widget.dart
import 'dart:async';
import 'package:flutter/gestures.dart';
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
  int _scrollOffset = 0;
  bool _wasAtBottom = true;

  // Selection state (row, col)
  (int, int)? _selectionStart;
  (int, int)? _selectionEnd;
  bool _isDragging = false;

  bool get _hasSelection =>
      _selectionStart != null && _selectionEnd != null &&
      (_selectionStart!.$1 != _selectionEnd!.$1 ||
       _selectionStart!.$2 != _selectionEnd!.$2);

  // Cached cell metrics for hit testing
  double _cellWidth = 8;
  double _cellHeight = 16;

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
      // If user was at the bottom, stay at the bottom after new data
      if (_wasAtBottom) {
        _scrollOffset = 0;
      }
      _generation++;
    });
  }

  void _onScroll(PointerScrollEvent event) {
    final maxOffset = widget.terminal.buffer.scrollback.length;
    setState(() {
      if (event.scrollDelta.dy < 0) {
        // Scroll up (into history)
        _scrollOffset = (_scrollOffset + 3).clamp(0, maxOffset);
      } else {
        // Scroll down (toward present)
        _scrollOffset = (_scrollOffset - 3).clamp(0, maxOffset);
      }
      _wasAtBottom = _scrollOffset == 0;
    });
  }

  (int, int) _hitTest(Offset position) {
    final col = (position.dx / _cellWidth).floor().clamp(0, widget.terminal.buffer.cols - 1);
    final row = (position.dy / _cellHeight).floor().clamp(0, widget.terminal.buffer.rows - 1);
    return (row, col);
  }

  void _onPanStart(DragStartDetails details) {
    final pos = _hitTest(details.localPosition);
    setState(() {
      _selectionStart = pos;
      _selectionEnd = pos;
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final pos = _hitTest(details.localPosition);
    setState(() {
      _selectionEnd = pos;
      _generation++; // force repaint
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
  }

  /// Returns the normalized selection range (start <= end).
  ((int, int), (int, int))? get _normalizedSelection {
    if (_selectionStart == null || _selectionEnd == null) return null;
    final s = _selectionStart!;
    final e = _selectionEnd!;
    if (s.$1 < e.$1 || (s.$1 == e.$1 && s.$2 <= e.$2)) {
      return (s, e);
    }
    return (e, s);
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final key = event.logicalKey;

    // Handle Cmd+C (copy) and Cmd+V (paste) on macOS
    if (HardwareKeyboard.instance.isMetaPressed) {
      if (key == LogicalKeyboardKey.keyC && _hasSelection) {
        final sel = _normalizedSelection;
        if (sel != null) {
          final text = widget.terminal.buffer.getTextInRange(
            sel.$1.$1, sel.$1.$2, sel.$2.$1, sel.$2.$2,
          );
          Clipboard.setData(ClipboardData(text: text));
        }
        return;
      }
      if (key == LogicalKeyboardKey.keyV) {
        Clipboard.getData('text/plain').then((data) {
          if (data?.text != null) widget.onInput(data!.text!);
        });
        return;
      }
    }

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

    // Clear selection on any input
    if (_hasSelection) {
      setState(() {
        _selectionStart = null;
        _selectionEnd = null;
      });
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
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            _onScroll(event);
          }
        },
        child: GestureDetector(
          onTap: () {
            _focusNode.requestFocus();
            // Clear selection on tap
            setState(() {
              _selectionStart = null;
              _selectionEnd = null;
            });
          },
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _handleResize(constraints);
              final sel = _normalizedSelection;
              return CustomPaint(
                painter: TerminalRenderer(
                  buffer: widget.terminal.buffer,
                  theme: widget.theme,
                  fontSize: widget.fontSize,
                  fontFamily: widget.fontFamily,
                  generation: _generation,
                  showCursor: _focusNode.hasFocus && _scrollOffset == 0,
                  scrollOffset: _scrollOffset,
                  selectionStart: sel?.$1,
                  selectionEnd: sel?.$2,
                ),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              );
            },
          ),
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

    _cellWidth = renderer.cellWidth;
    _cellHeight = renderer.cellHeight;

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
