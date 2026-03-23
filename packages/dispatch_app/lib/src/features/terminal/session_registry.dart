import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart' as xterm;
import 'package:dispatch_terminal/dispatch_terminal.dart';

/// Metadata about a terminal session, updated by TerminalMonitor via callback.
class TerminalSessionMeta {
  final DateTime? lastActivityTime;
  final String? activityStatus; // 'idle', 'running', 'success', 'error'

  const TerminalSessionMeta({this.lastActivityTime, this.activityStatus});

  int? get idleDurationMs {
    if (lastActivityTime == null || activityStatus != 'idle') return null;
    return DateTime.now().difference(lastActivityTime!).inMilliseconds;
  }
}

/// All data associated with a terminal session.
class TerminalSessionRecord {
  final PtySession? session;
  final Pty? pty;
  final xterm.Terminal? terminal;
  final Queue<String> outputBuffer;
  final TerminalSessionMeta meta;

  TerminalSessionRecord({
    this.session,
    this.pty,
    this.terminal,
    Queue<String>? outputBuffer,
    this.meta = const TerminalSessionMeta(),
  }) : outputBuffer = outputBuffer ?? Queue<String>();
}

/// Global registry of active PTY sessions, keyed by terminal ID.
/// Owns PTY and xterm.Terminal lifecycle — widgets are thin views.
class SessionRegistry extends Notifier<Map<String, TerminalSessionRecord>> {
  static const int maxOutputLines = 10000;

  /// Optional callback invoked on every output line appended to any terminal.
  /// MonitorSkill registers here for event-driven monitoring.
  void Function(String terminalId, String output)? onOutputCallback;

  @override
  Map<String, TerminalSessionRecord> build() => {};

  void register(String id, {PtySession? session, Pty? pty, xterm.Terminal? terminal}) {
    final updated = Map<String, TerminalSessionRecord>.from(state);
    final existing = updated[id];
    updated[id] = TerminalSessionRecord(
      session: session ?? existing?.session,
      pty: pty ?? existing?.pty,
      terminal: terminal ?? existing?.terminal,
      outputBuffer: existing?.outputBuffer,
      meta: existing?.meta ?? const TerminalSessionMeta(),
    );
    state = updated;
  }

  /// Spawn a PTY for a terminal and register it. If a PTY already exists
  /// for this ID, return the existing one (idempotent).
  Pty? spawnPty(String id, {
    required String shell,
    required String cwd,
    String? command,
    void Function(String data)? onOutput,
    void Function(int exitCode)? onExit,
  }) {
    // If already spawned, return existing
    final existing = state[id];
    if (existing?.pty != null) return existing!.pty;

    final pty = Pty.start(
      shell,
      arguments: ['--login'],
      environment: {
        ...Platform.environment,
        'TERM': 'xterm-256color',
        'COLORTERM': 'truecolor',
      },
      workingDirectory: cwd,
    );

    // Ensure terminal exists
    final terminal = existing?.terminal ?? xterm.Terminal(maxLines: 10000);

    // Register PTY + terminal in state BEFORE wiring listeners
    // to avoid race where appendOutput runs before state is set.
    final updated = Map<String, TerminalSessionRecord>.from(state);
    updated[id] = TerminalSessionRecord(
      session: existing?.session,
      pty: pty,
      terminal: terminal,
      outputBuffer: existing?.outputBuffer,
      meta: existing?.meta ?? const TerminalSessionMeta(),
    );
    state = updated;

    // Wire PTY output → terminal + callback
    pty.output.cast<List<int>>().transform(const Utf8Decoder()).listen((data) {
      terminal.write(data);
      Future.delayed(Duration.zero, () => appendOutput(id, data));
      onOutput?.call(data);
    });

    // Wire terminal input → PTY
    terminal.onOutput = (data) {
      pty.write(const Utf8Encoder().convert(data));
    };

    // Wire resize
    terminal.onResize = (w, h, pw, ph) {
      pty.resize(h, w);
    };

    // Handle PTY exit
    pty.exitCode.then((code) {
      onExit?.call(code);
    });

    // Type command into shell after brief delay
    if (command != null && command != '\$SHELL' && command.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 200), () {
        pty.write(const Utf8Encoder().convert('$command\r'));
      });
    }

    return pty;
  }

  /// Get the Pty handle for a terminal (for writing commands / killing).
  Pty? getPty(String id) => state[id]?.pty;

  /// Get the xterm.Terminal for a session.
  xterm.Terminal? getTerminal(String id) => state[id]?.terminal;

  void unregister(String id) {
    state = Map<String, TerminalSessionRecord>.from(state)..remove(id);
  }

  /// Kill the PTY (if any) and remove the session entry entirely.
  void killAndUnregister(String id) {
    final record = state[id];
    if (record != null) {
      record.pty?.kill();
    }
    unregister(id);
  }

  PtySession? getSession(String id) => state[id]?.session;

  /// Append output lines to the terminal's rolling buffer.
  void appendOutput(String id, String data) {
    final record = state[id];
    if (record == null) return;
    final newBuffer = Queue<String>.of(record.outputBuffer);
    for (final line in data.split('\n')) {
      newBuffer.addLast(line);
      while (newBuffer.length > maxOutputLines) {
        newBuffer.removeFirst();
      }
    }
    final updated = Map<String, TerminalSessionRecord>.from(state);
    updated[id] = TerminalSessionRecord(
      session: record.session,
      pty: record.pty,
      terminal: record.terminal,
      outputBuffer: newBuffer,
      meta: record.meta,
    );
    state = updated;
    if (onOutputCallback != null) {
      onOutputCallback!(id, data);
    }
  }

  /// Read the last N lines from a terminal's output buffer.
  String readOutput(String id, {int lines = 100}) {
    final record = state[id];
    if (record == null) return '';
    final asList = record.outputBuffer.toList();
    final start = asList.length > lines ? asList.length - lines : 0;
    return asList.sublist(start).join('\n');
  }

  /// Update activity metadata for a terminal.
  void updateMeta(String id, {String? activityStatus}) {
    final record = state[id];
    if (record == null) return;

    final updated = Map<String, TerminalSessionRecord>.from(state);
    updated[id] = TerminalSessionRecord(
      session: record.session,
      pty: record.pty,
      terminal: record.terminal,
      outputBuffer: record.outputBuffer,
      meta: TerminalSessionMeta(
        lastActivityTime: DateTime.now(),
        activityStatus: activityStatus,
      ),
    );
    state = updated;
  }

  /// Get metadata for a terminal.
  TerminalSessionMeta? getMeta(String id) => state[id]?.meta;
}

final sessionRegistryProvider =
    NotifierProvider<SessionRegistry, Map<String, TerminalSessionRecord>>(
        SessionRegistry.new);
