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
