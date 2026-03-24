import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alfa_types.dart';
import 'agents_state.dart';

/// Background terminal monitor that watches Alfa-spawned terminals.
/// Event-driven via SessionRegistry output callbacks + 30s poll fallback.
/// Debounces alerts: same terminal + classification, max 1 per 5 minutes.
class MonitorSkill {
  final Ref ref;
  final AgentsState agentsState;
  final void Function(AlfaChatEvent event) onEvent;

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
          entry.key.endsWith('-alfa') ||
          entry.key.endsWith('-mcp');
      if (!isAgent) continue;

      final heartbeat =
          DateTime.tryParse(agent['last_heartbeat'] as String? ?? '');
      if (heartbeat != null &&
          DateTime.now().toUtc().difference(heartbeat).inSeconds > 120) {
        _emitDebounced(
          entry.key,
          'stuck',
          AlfaChatEvent.alfa(
              '⚠️ Agent ${entry.key} appears stuck — no output for 2+ minutes.'),
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

  // Patterns that look like errors but are NOT actionable:
  // - Claude Code conversational text containing "error" or "exception"
  // - npm/node standard output (EADDRINUSE etc already handled by the agent)
  // - Lines that are inside code blocks or diffs
  static final _falsePositivePatterns = [
    RegExp(r'EADDRINUSE'),                         // port conflict — agent handles it
    RegExp(r'error\b.*\bhandled\b', caseSensitive: false),
    RegExp(r'error\b.*\bfixed\b', caseSensitive: false),
    RegExp(r'error\b.*\balready\b', caseSensitive: false),
    RegExp(r'error\b.*\bresolved\b', caseSensitive: false),
    RegExp(r'^\s*[+\-]\s'),                        // diff lines
    RegExp(r'^\s*//'),                             // code comments
    RegExp(r'^\s*\*'),                             // JSDoc/block comments
    RegExp(r'try\s*\{'),                           // try/catch blocks
    RegExp(r'catch\s*\('),
    RegExp(r'throw\s+new'),
    RegExp(r'npm warn', caseSensitive: false),
    RegExp(r'deprecated', caseSensitive: false),
    RegExp(r'⏺'),                                  // Claude Code response marker
  ];

  // Real error patterns — must appear at the START of a line
  // to distinguish from conversational mentions of "error"
  static final _realErrorPatterns = [
    RegExp(r'^\s*(Error|TypeError|ReferenceError|SyntaxError|RangeError):', multiLine: true),
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

    // Skip if any false-positive pattern matches
    if (_falsePositivePatterns.any((p) => p.hasMatch(stripped))) return;

    // Only alert if a REAL error pattern matches at line start
    final hasRealError = _realErrorPatterns.any((p) => p.hasMatch(stripped));
    if (!hasRealError) return;

    _emitDebounced(
      terminalId,
      'error',
      AlfaChatEvent.alfa('💥 Error detected in $terminalId'),
    );
  }

  // Debounce: 5 minutes per terminal+classification (was 60s — too aggressive)
  void _emitDebounced(
      String terminalId, String classification, AlfaChatEvent event) {
    final key = '$terminalId:$classification';
    final last = _lastAlerts[key];
    if (last != null && DateTime.now().difference(last).inMinutes < 5) return;
    _lastAlerts[key] = DateTime.now();
    onEvent(event);
  }
}
