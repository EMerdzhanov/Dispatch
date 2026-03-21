import 'dart:io';
import 'dart:typed_data';

import 'package:dispatch_terminal/src/pty_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

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

    test('readBytes returns raw bytes', () async {
      final result = PtyFfi.spawn(
        executable: '/bin/sh',
        args: [],
        cwd: Directory.systemTemp.path,
        env: {'TERM': 'xterm-256color'},
        rows: 24,
        cols: 80,
      );

      PtyFfi.write(result.masterFd, 'echo bytes_test\n');
      await Future.delayed(const Duration(milliseconds: 200));

      final bytes = PtyFfi.readBytes(result.masterFd);
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(0));

      PtyFfi.kill(result.pid, 15);
      PtyFfi.close(result.masterFd);
    });

    test('writeBytes sends raw bytes', () async {
      final result = PtyFfi.spawn(
        executable: '/bin/sh',
        args: [],
        cwd: Directory.systemTemp.path,
        env: {'TERM': 'xterm-256color'},
        rows: 24,
        cols: 80,
      );

      // Write "echo wb_test\n" as bytes
      final cmd = 'echo wb_test\n';
      PtyFfi.writeBytes(result.masterFd, Uint8List.fromList(cmd.codeUnits));
      await Future.delayed(const Duration(milliseconds: 200));

      final output = PtyFfi.read(result.masterFd);
      expect(output, isNotNull);
      expect(output!, contains('wb_test'));

      PtyFfi.kill(result.pid, 15);
      PtyFfi.close(result.masterFd);
    });
  });
}
