import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart' as xterm;
import 'package:dispatch_terminal/dispatch_terminal.dart';

import 'smart_naming.dart';
import 'terminal_provider.dart';

/// Metadata about a terminal session, updated by TerminalMonitor via callback.
class TerminalSessionMeta {
  final DateTime? lastActivityTime;
  final String? activityStatus;

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

// ---------------------------------------------------------------------------
// Mechanical approval detector — no AI, no tokens, pure string matching.
// Runs on every line of output from every terminal.
// Detects Claude Code / Codex approval prompts and updates the UI badge.
// ---------------------------------------------------------------------------
final _ansiStripper = RegExp(
    r'\x1B\[[0-9;]*[A-Za-z]|\x1B\][^\x07]*\x07|\x1B[()][A-B012]');

// These strings appear ONLY when a terminal is waiting for user approval.
// Chosen to be extremely specific — zero false positives in normal output.
const _approvalSignals = [
  'Esc to cancel',          // Claude Code approval prompt footer
  'Do you want to create',  // Claude Code write prompt
  'Do you want to edit',    // Claude Code edit prompt
  'Do you want to delete',  // Claude Code delete prompt
  'Do you want to run',     // Claude Code bash prompt
  'Do you want to execute', // Codex
  'Allow this tool call',   // Generic agent prompt
  '(y/n)',                  // CLI prompts
  '[Y/n]',                  // CLI prompts
  '[y/N]',                  // CLI prompts
  'Is this OK?',            // npm prompts
];

bool _detectsApproval(String rawOutput) {
  final stripped = rawOutput.replaceAll(_ansiStripper, '');
  for (final signal in _approvalSignals) {
    if (stripped.contains(signal)) return true;
  }
  return false;
}

/// Global registry of active PTY sessions, keyed by terminal ID.
class SessionRegistry extends Notifier<Map<String, TerminalSessionRecord>> {
  static const int maxOutputLines = 10000;

  /// Terminal IDs that have already been auto-named (only name once).
  final Set<String> _autoNamed = {};

  /// Optional callback invoked on every output chunk appended to any terminal.
  /// Grace/MonitorSkill registers here for event-driven monitoring.
  void Function(String terminalId, String output)? onOutputCallback;

  // Ref is available via the Notifier base class
  TerminalsNotifier? get _terminalsNotifier {
    try {
      return ref.read(terminalsProvider.notifier);
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, TerminalSessionRecord> build() => {};

  void register(String id,
      {PtySession? session, Pty? pty, xterm.Terminal? terminal}) {
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

  Pty? spawnPty(
    String id, {
    required String shell,
    required String cwd,
    String? command,
    void Function(String data)? onOutput,
    void Function(int exitCode)? onExit,
  }) {
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

    final terminal =
        existing?.terminal ?? xterm.Terminal(maxLines: 10000);

    final updated = Map<String, TerminalSessionRecord>.from(state);
    updated[id] = TerminalSessionRecord(
      session: existing?.session,
      pty: pty,
      terminal: terminal,
      outputBuffer: existing?.outputBuffer,
      meta: existing?.meta ?? const TerminalSessionMeta(),
    );
    state = updated;

    pty.output.cast<List<int>>().transform(const Utf8Decoder()).listen((data) {
      terminal.write(data);
      Future.delayed(Duration.zero, () => appendOutput(id, data));
      onOutput?.call(data);
    });

    terminal.onOutput = (data) {
      pty.write(const Utf8Encoder().convert(data));
    };

    terminal.onResize = (w, h, pw, ph) {
      pty.resize(h, w);
    };

    pty.exitCode.then((code) {
      onExit?.call(code);
    });

    if (command != null && command != r'$SHELL' && command.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 200), () {
        pty.write(const Utf8Encoder().convert('$command\r'));
      });
    }

    return pty;
  }

  Pty? getPty(String id) => state[id]?.pty;
  xterm.Terminal? getTerminal(String id) => state[id]?.terminal;

  void unregister(String id) {
    state = Map<String, TerminalSessionRecord>.from(state)..remove(id);
  }

  void killAndUnregister(String id) {
    state[id]?.pty?.kill();
    unregister(id);
  }

  PtySession? getSession(String id) => state[id]?.session;

  /// Append output to buffer, fire callback, and mechanically check for
  /// approval prompts — no AI needed, pure string matching.
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

    // --- Mechanical approval detection ---
    // Read the last 20 lines to check for approval prompt
    final tail = newBuffer.toList().reversed.take(20).toList().reversed.join('\n');
    final waiting = _detectsApproval(tail);
    _terminalsNotifier?.setWaitingApproval(id, waiting: waiting);

    // --- Smart terminal naming (once per terminal) ---
    if (!_autoNamed.contains(id)) {
      final stripped = data.replaceAll(_ansiStripper, '');
      final name = detectTerminalName(stripped);
      if (name != null) {
        _autoNamed.add(id);
        _terminalsNotifier?.setAutoLabel(id, name);
      }
    }

    // Fire Grace/MonitorSkill callback
    onOutputCallback?.call(id, data);
  }

  String readOutput(String id, {int lines = 100}) {
    final record = state[id];
    if (record == null) return '';
    final asList = record.outputBuffer.toList();
    final start = asList.length > lines ? asList.length - lines : 0;
    return asList.sublist(start).join('\n');
  }

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

  TerminalSessionMeta? getMeta(String id) => state[id]?.meta;
}

final sessionRegistryProvider =
    NotifierProvider<SessionRegistry, Map<String, TerminalSessionRecord>>(
        SessionRegistry.new);
