import 'dart:async';
import 'dart:io';

import 'package:dispatch_terminal/src/pty_manager.dart';
import 'package:flutter_test/flutter_test.dart';

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

      final output =
          await completer.future.timeout(const Duration(seconds: 3));
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

      final exitCode =
          await session.exitCode.timeout(const Duration(seconds: 3));
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

    test('command parameter types initial input after spawn', () async {
      final session = await manager.spawn(
        executable: '/bin/sh',
        cwd: Directory.systemTemp.path,
        cols: 80,
        rows: 24,
        command: 'echo cmd_from_spawn',
      );

      final completer = Completer<String>();
      final buffer = StringBuffer();
      final sub = session.dataStream.listen((data) {
        buffer.write(data);
        if (buffer.toString().contains('cmd_from_spawn')) {
          if (!completer.isCompleted) completer.complete(buffer.toString());
        }
      });

      final output =
          await completer.future.timeout(const Duration(seconds: 5));
      expect(output, contains('cmd_from_spawn'));

      await sub.cancel();
      session.dispose();
    });

    test('sessionCount tracks active sessions', () async {
      expect(manager.sessionCount, 0);

      final s1 = await manager.spawn(
        executable: '/bin/sh',
        cwd: Directory.systemTemp.path,
        cols: 80,
        rows: 24,
      );
      expect(manager.sessionCount, 1);

      final s2 = await manager.spawn(
        executable: '/bin/sh',
        cwd: Directory.systemTemp.path,
        cols: 80,
        rows: 24,
      );
      expect(manager.sessionCount, 2);

      s1.dispose();
      // Give time for cleanup message to propagate
      await Future.delayed(const Duration(milliseconds: 100));
      expect(manager.sessionCount, 1);

      s2.dispose();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(manager.sessionCount, 0);
    });
  });
}
