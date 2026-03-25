import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'grace_types.dart';
import 'agents_state.dart';
import '../terminal/terminal_provider.dart';

/// Background terminal monitor that watches Grace-spawned terminals.
/// Event-driven via SessionRegistry output callbacks + 30s poll fallback.
/// Debounces alerts: same terminal + classification, max 1 per 5 minutes.
class MonitorSkill {
  final Ref ref;
  final AgentsState agentsState;
  final void Function(GraceChatEvent event) onEvent;

  Timer? _pollTimer;
  final Map<String, DateTime> _lastAlerts = {};

  MonitorSkill({
    required this.ref,
    required this.agentsState,
    required this.onEvent,
  });

  void start() {
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void onTerminalOutput(String terminalId, String output) {
    _updateHeartbeat(terminalId);
    _classify(terminalId, output);
  }

  Future<void> _poll() async {
    final state = await agentsState.readState();
    final agents = (state['agents'] as Map<String, dynamic>?) ?? {};

    for (final entry in agents.entries) {
      final agent = entry.value as Map<String, dynamic>;
      if (agent['status'] != 'working') continue;

      final isAgent = (agent['is_agent'] as bool?) ??
          entry.key.endsWith('-grace') ||
          entry.key.endsWith('-grace') ||
          entry.key.endsWith('-mcp');
      if (!isAgent) continue;

      final heartbeat =
          DateTime.tryParse(agent['last_heartbeat'] as String? ?? '');
      if (heartbeat != null &&
          DateTime.now().toUtc().difference(heartbeat).inSeconds > 120) {
        _emitDebounced(
          entry.key,
          'stuck',
          GraceChatEvent.grace(
              '⚠️ ${entry.key} appears stuck — no output for 2+ minutes.'),
        );
      }
    }

    await agentsState.cleanupStale();
  }

  void _updateHeartbeat(String terminalId) {
    agentsState.updateAgent(terminalId);
  }

  static final _ansiPattern = RegExp(
      r'\x1B\[[0-9;]*[A-Za-z]|\x1B\][^\x07]*\x07|\x1B[()][A-B012]');

  // ---------------------------------------------------------------------------
  // Approval waiting patterns
  // Claude Code uses › (U+203A) not ❯ (U+276F) for the selection arrow.
  // The prompt format is: "Do you want to X?\n › 1. Yes\n   2. Yes, allow all\n   3. No"
  // ---------------------------------------------------------------------------
  static final _approvalPatterns = [
    // Claude Code numbered choice prompt — matches › 1. Yes or ❯ 1. Yes
    RegExp(r'[❯›]\s*1\.\s*Yes', caseSensitive: false),
    // Claude Code "Do you want to..." prompt
    RegExp(r'Do you want to (create|edit|delete|write|run|execute|make)',
        caseSensitive: false),
    // Generic approval prompts
    RegExp(r'Allow this tool call', caseSensitive: false),
    RegExp(r'Allow\s+bash\b', caseSensitive: false),
    RegExp(r'\(y/n\)\s*$', multiLine: true, caseSensitive: false),
    RegExp(r'\[y/N\]\s*$', multiLine: true),
    RegExp(r'\[Y/n\]\s*$', multiLine: true),
    RegExp(r'Do you want to proceed', caseSensitive: false),
    RegExp(r'Press Enter to confirm', caseSensitive: false),
    RegExp(r'Is this OK\?', caseSensitive: false),
    RegExp(r'Continue\? \(Y/n\)', caseSensitive: false),
    // Esc to cancel line — only shown when Claude Code is waiting for input
    RegExp(r'Esc to cancel\s+·\s+Tab to amend', caseSensitive: false),
  ];

  // ---------------------------------------------------------------------------
  // False positive patterns — skip alerting
  // ---------------------------------------------------------------------------
  static final _falsePositivePatterns = [
    RegExp(r'EADDRINUSE'),
    RegExp(r'error\b.*\bhandled\b', caseSensitive: false),
    RegExp(r'error\b.*\bfixed\b', caseSensitive: false),
    RegExp(r'error\b.*\balready\b', caseSensitive: false),
    RegExp(r'error\b.*\bresolved\b', caseSensitive: false),
    RegExp(r'^\s*[+\-]\s'),
    RegExp(r'^\s*//'),
    RegExp(r'^\s*\*'),
    RegExp(r'try\s*\{'),
    RegExp(r'catch\s*\('),
    RegExp(r'throw\s+new'),
    RegExp(r'npm warn', caseSensitive: false),
    RegExp(r'deprecated', caseSensitive: false),
    RegExp(r'⏺'),
    RegExp(r'bypass permissions on\s*\(shift'),
  ];

  // ---------------------------------------------------------------------------
  // Real error patterns — must appear at line start
  // ---------------------------------------------------------------------------
  static final _realErrorPatterns = [
    RegExp(r'^\s*(Error|TypeError|ReferenceError|SyntaxError|RangeError):',
        multiLine: true),
    RegExp(r'^\s*FAILED\b', multiLine: true, caseSensitive: false),
    RegExp(r'^\s*fatal:', multiLine: true, caseSensitive: false),
    RegExp(r'^\s*panic:', multiLine: true, caseSensitive: false),
    RegExp(r'^\s*Unhandled', multiLine: true),
    RegExp(r'Process exited with code [^0]', caseSensitive: false),
    RegExp(r'npm ERR!', caseSensitive: false),
    RegExp(r'✗.*failed', caseSensitive: false),
  ];

  void _classify(String terminalId, String output) {
    final stripped = output.replaceAll(_ansiPattern, '');

    // --- Approval detection (highest priority) ---
    final needsApproval = _approvalPatterns.any((p) => p.hasMatch(stripped));
    if (needsApproval) {
      ref.read(terminalsProvider.notifier).setWaitingApproval(
            terminalId,
            waiting: true,
          );

      final lines = stripped
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final hint = lines.length > 2 ? lines[lines.length - 2] : '';
      _emitDebounced(
        terminalId,
        'approval',
        GraceChatEvent.grace(
          '⏸ $terminalId is waiting for your approval'
          '${hint.isNotEmpty ? ' — $hint' : ''}. '
          'Switch to that terminal and approve.',
        ),
      );
      return;
    }

    // Clear badge when prompt is gone
    final currentState = ref.read(terminalsProvider);
    if (currentState.waitingApproval.contains(terminalId)) {
      ref.read(terminalsProvider.notifier).setWaitingApproval(
            terminalId,
            waiting: false,
          );
    }

    // --- False positive check ---
    if (_falsePositivePatterns.any((p) => p.hasMatch(stripped))) return;

    // --- Real error check ---
    final hasRealError = _realErrorPatterns.any((p) => p.hasMatch(stripped));
    if (!hasRealError) return;

    _emitDebounced(
      terminalId,
      'error',
      GraceChatEvent.grace('💥 Error detected in $terminalId'),
    );
  }

  void _emitDebounced(
      String terminalId, String classification, GraceChatEvent event) {
    final key = '$terminalId:$classification';
    final last = _lastAlerts[key];
    if (last != null && DateTime.now().difference(last).inMinutes < 5) return;
    _lastAlerts[key] = DateTime.now();
    onEvent(event);
  }
}
