import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../terminal/session_registry.dart';
import '../terminal/terminal_provider.dart';

/// Standalone approval watcher — no AI, no tokens, no Grace required.
/// Runs a simple timer every 3 seconds, scans all terminal output,
/// and sets the UI badge directly via terminalsProvider.
///
/// Completely mechanical — reads PTY output, matches patterns, sets state.
class ApprovalWatcher {
  final Ref ref;
  Timer? _timer;

  ApprovalWatcher(this.ref);

  static final _ansiRe = RegExp(
      r'\x1B\[[0-9;]*[A-Za-z]|\x1B\][^\x07]*\x07|\x1B[()][A-B012]');

  // These patterns are highly specific to interactive approval prompts.
  // They won't match normal output.
  static final _approvalPatterns = [
    // Claude Code numbered choice menu with selection cursor
    RegExp(r'[❯›]\s*1\.\s*Yes', caseSensitive: false),
    // Claude Code "Do you want to X?" question
    RegExp(r'Do you want to (create|edit|delete|write|run|execute|make)',
        caseSensitive: false),
    // The "Esc to cancel" footer — only shown during approval prompts
    RegExp(r'Esc to cancel\s*[·•]\s*Tab to amend', caseSensitive: false),
    // Generic y/n prompts
    RegExp(r'\(y/n\)\s*$', multiLine: true, caseSensitive: false),
    RegExp(r'\[Y/n\]\s*$', multiLine: true),
    RegExp(r'\[y/N\]\s*$', multiLine: true),
    // npm / git confirmation
    RegExp(r'Is this OK\?', caseSensitive: false),
    RegExp(r'Continue\? \(Y/n\)', caseSensitive: false),
  ];

  void start() {
    // Poll every 3 seconds — fast enough to feel responsive, cheap enough to run always
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _scan());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _scan() {
    final registry = ref.read(sessionRegistryProvider);
    final notifier = ref.read(terminalsProvider.notifier);

    for (final entry in registry.entries) {
      final id = entry.key;
      final record = entry.value;

      final output = record.outputBuffer.toList();
      if (output.isEmpty) continue;

      // Only look at the last 30 lines — approval prompts are always recent
      final tail = output
          .skip(output.length > 30 ? output.length - 30 : 0)
          .join('\n')
          .replaceAll(_ansiRe, '');

      final needsApproval = _approvalPatterns.any((p) => p.hasMatch(tail));
      notifier.setWaitingApproval(id, waiting: needsApproval);
    }
  }
}

final approvalWatcherProvider = Provider<ApprovalWatcher>((ref) {
  final watcher = ApprovalWatcher(ref);
  watcher.start();
  ref.onDispose(watcher.stop);
  return watcher;
});
