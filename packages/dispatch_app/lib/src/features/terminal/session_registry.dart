import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pty/flutter_pty.dart';
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
  final Queue<String> outputBuffer;
  final TerminalSessionMeta meta;

  TerminalSessionRecord({
    this.session,
    this.pty,
    Queue<String>? outputBuffer,
    this.meta = const TerminalSessionMeta(),
  }) : outputBuffer = outputBuffer ?? Queue<String>();
}

/// Global registry of active PTY sessions, keyed by terminal ID.
/// Holds PTY sessions, rolling output buffers, and activity metadata.
class SessionRegistry extends Notifier<Map<String, TerminalSessionRecord>> {
  static const int maxOutputLines = 10000;

  /// Optional callback invoked on every output line appended to any terminal.
  /// MonitorSkill registers here for event-driven monitoring.
  void Function(String terminalId, String output)? onOutputCallback;

  @override
  Map<String, TerminalSessionRecord> build() => {};

  void register(String id, {PtySession? session, Pty? pty}) {
    final updated = Map<String, TerminalSessionRecord>.from(state);
    updated[id] = TerminalSessionRecord(session: session, pty: pty);
    state = updated;
  }

  /// Get the Pty handle for a terminal (for writing commands / killing).
  Pty? getPty(String id) => state[id]?.pty;

  void unregister(String id) {
    state = Map<String, TerminalSessionRecord>.from(state)..remove(id);
  }

  PtySession? getSession(String id) => state[id]?.session;

  /// Append output lines to the terminal's rolling buffer.
  void appendOutput(String id, String data) {
    final record = state[id];
    if (record == null) return;
    final newBuffer = Queue<String>.of(record.outputBuffer);
    for (final line in data.split('\n')) {
      newBuffer.addLast(line);
      while (newBuffer.length > maxOutputLines) newBuffer.removeFirst();
    }
    final updated = Map<String, TerminalSessionRecord>.from(state);
    updated[id] = TerminalSessionRecord(
      session: record.session,
      pty: record.pty,
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
