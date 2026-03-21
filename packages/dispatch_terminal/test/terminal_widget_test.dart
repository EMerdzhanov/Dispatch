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
