import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alfa_orchestrator.dart';
import 'agents_state.dart';

/// Background terminal monitor that watches Alfa-spawned terminals.
/// Event-driven via SessionRegistry output callbacks + 30s poll fallback.
/// Debounces alerts: same terminal + classification, max 1 per 60s.
class MonitorSkill {
  final Ref ref;
  final AgentsState agentsState;
  final void Function(AlfaChatEvent event) onEvent;

  Timer? _pollTimer;
  final Map<String, DateTime> _lastAlerts = {}; // key: "$terminalId:$classification"

  MonitorSkill({
    required this.ref,
    required this.agentsState,
    required this.onEvent,
  });

  void start() {
    // Poll fallback every 30s
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Called when terminal output arrives (event-driven path).
  void onTerminalOutput(String terminalId, String output) {
    _updateHeartbeat(terminalId);
    _classify(terminalId, output);
  }

  /// Poll all Alfa terminals for status.
  /// NOTE: poll does NOT update heartbeats — only onTerminalOutput() does.
  Future<void> _poll() async {
    final state = await agentsState.readState();
    final agents = (state['agents'] as Map<String, dynamic>?) ?? {};

    for (final entry in agents.entries) {
      final agent = entry.value as Map<String, dynamic>;
      if (agent['status'] != 'working') continue;

      // Check for stuck agents BEFORE updating heartbeat
      // (heartbeat is only refreshed by actual terminal output via onTerminalOutput,
      // NOT by polling — poll only checks, it doesn't renew)
      final heartbeat = DateTime.tryParse(agent['last_heartbeat'] as String? ?? '');
      if (heartbeat != null && DateTime.now().toUtc().difference(heartbeat).inSeconds > 120) {
        _emitDebounced(entry.key, 'stuck',
          AlfaChatEvent.alfa('⚠️ Agent ${entry.key} appears stuck — no output for 2+ minutes.'));
      }
    }

    // Cleanup stale claims
    await agentsState.cleanupStale();
  }

  void _updateHeartbeat(String terminalId) {
    agentsState.updateAgent(terminalId);
  }

  void _classify(String terminalId, String output) {
    final lower = output.toLowerCase();

    // Error detection
    if (lower.contains('error') || lower.contains('exception') ||
        lower.contains('fatal') || lower.contains('panic') ||
        lower.contains('stack trace')) {
      _emitDebounced(terminalId, 'error',
        AlfaChatEvent.alfa('💥 Error detected in $terminalId'));
    }
  }

  void _emitDebounced(String terminalId, String classification, AlfaChatEvent event) {
    final key = '$terminalId:$classification';
    final last = _lastAlerts[key];
    if (last != null && DateTime.now().difference(last).inSeconds < 60) return;

    _lastAlerts[key] = DateTime.now();
    onEvent(event);
  }
}
