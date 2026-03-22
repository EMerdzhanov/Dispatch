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

  @override
  Map<String, TerminalSessionRecord> build() => {};

  void register(String terminalId, {PtySession? session, Pty? pty}) {
    state = {
      ...state,
      terminalId: TerminalSessionRecord(session: session, pty: pty),
    };
  }

  /// Get the Pty handle for a terminal (for writing commands / killing).
  Pty? getPty(String terminalId) => state[terminalId]?.pty;

  void unregister(String terminalId) {
    state = Map.of(state)..remove(terminalId);
  }

  PtySession? getSession(String terminalId) => state[terminalId]?.session;

  /// Append output lines to the terminal's rolling buffer.
  void appendOutput(String terminalId, String data) {
    final record = state[terminalId];
    if (record == null) return;

    final lines = data.split('\n');
    for (final line in lines) {
      record.outputBuffer.addLast(line);
      while (record.outputBuffer.length > maxOutputLines) {
        record.outputBuffer.removeFirst();
      }
    }
    // Trigger state update for listeners
    state = Map.of(state);
  }

  /// Read the last N lines from a terminal's output buffer.
  String readOutput(String terminalId, {int lines = 100}) {
    final record = state[terminalId];
    if (record == null) return '';
    final asList = record.outputBuffer.toList();
    final start = asList.length > lines ? asList.length - lines : 0;
    return asList.sublist(start).join('\n');
  }

  /// Update activity metadata for a terminal.
  void updateMeta(String terminalId, {String? activityStatus}) {
    final record = state[terminalId];
    if (record == null) return;

    state = {
      ...state,
      terminalId: TerminalSessionRecord(
        session: record.session,
        pty: record.pty,
        outputBuffer: record.outputBuffer,
        meta: TerminalSessionMeta(
          lastActivityTime: DateTime.now(),
          activityStatus: activityStatus,
        ),
      ),
    };
  }

  /// Get metadata for a terminal.
  TerminalSessionMeta? getMeta(String terminalId) => state[terminalId]?.meta;
}

final sessionRegistryProvider =
    NotifierProvider<SessionRegistry, Map<String, TerminalSessionRecord>>(
        SessionRegistry.new);
