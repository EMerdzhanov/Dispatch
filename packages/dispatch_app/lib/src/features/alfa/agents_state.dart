import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'default_identity.dart';

/// Thread-safe read/write manager for agents.json.
/// Uses a chained-future lock to serialize all access.
class AgentsState {
  final String _path;
  Future<void> _chain = Future.value();

  AgentsState() : _path = '${alfaDir()}/agents.json';

  /// Acquire the lock via future chaining, run [fn] with current state, write back.
  Future<T> _withLock<T>(Future<T> Function(Map<String, dynamic> state) fn) {
    final prev = _chain;
    final completer = Completer<void>();
    _chain = completer.future;
    return prev.then((_) async {
      try {
        final state = await _read();
        final result = await fn(state);
        await _write(state);
        return result;
      } finally {
        completer.complete();
      }
    });
  }

  Future<Map<String, dynamic>> _read() async {
    final file = File(_path);
    if (!await file.exists()) {
      return {'agents': <String, dynamic>{}, 'active_plans': <dynamic>[], 'completed_plans': <dynamic>[]};
    }
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {'agents': <String, dynamic>{}, 'active_plans': <dynamic>[], 'completed_plans': <dynamic>[]};
    }
  }

  Future<void> _write(Map<String, dynamic> state) async {
    final file = File(_path);
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(state));
  }

  /// Read the full state (read-only snapshot).
  Future<Map<String, dynamic>> readState() async {
    return _withLock((state) async => Map<String, dynamic>.from(state));
  }

  /// Register a new agent.
  Future<void> registerAgent({
    required String terminalId,
    required String task,
    required String project,
    String? planStepId,
    String? successSignal,
    List<String> filesClaimed = const [],
  }) {
    return _withLock((state) async {
      final agents = (state['agents'] as Map<String, dynamic>?) ?? {};
      final now = DateTime.now().toUtc().toIso8601String();

      // Check file ownership before claiming
      for (final file in filesClaimed) {
        final owner = _findFileOwner(agents, file);
        if (owner != null && owner != terminalId) {
          throw StateError('File $file is already claimed by $owner');
        }
      }

      agents[terminalId] = {
        'task': task,
        'project': project,
        'status': 'working',
        'files_claimed': filesClaimed,
        'claimed_at': now,
        'last_heartbeat': now,
        'spawned_at': now,
        if (planStepId != null) 'plan_step_id': planStepId,
        if (successSignal != null) 'success_signal': successSignal,
      };
      state['agents'] = agents;
    });
  }

  /// Update agent status and heartbeat.
  Future<void> updateAgent(String terminalId, {String? status, List<String>? filesClaimed}) {
    return _withLock((state) async {
      final agents = (state['agents'] as Map<String, dynamic>?) ?? {};
      final agent = agents[terminalId] as Map<String, dynamic>?;
      if (agent == null) return;

      agent['last_heartbeat'] = DateTime.now().toUtc().toIso8601String();
      if (status != null) agent['status'] = status;
      if (filesClaimed != null) agent['files_claimed'] = filesClaimed;
      state['agents'] = agents;
    });
  }

  /// Remove a completed/killed agent.
  Future<void> removeAgent(String terminalId) {
    return _withLock((state) async {
      final agents = (state['agents'] as Map<String, dynamic>?) ?? {};
      agents.remove(terminalId);
      state['agents'] = agents;
    });
  }

  /// Cleanup stale agents (no heartbeat for >300s).
  Future<List<String>> cleanupStale() {
    return _withLock((state) async {
      final agents = (state['agents'] as Map<String, dynamic>?) ?? {};
      final now = DateTime.now().toUtc();
      final stale = <String>[];

      for (final entry in agents.entries.toList()) {
        final agent = entry.value as Map<String, dynamic>;
        final heartbeat = DateTime.tryParse(agent['last_heartbeat'] as String? ?? '');
        if (heartbeat != null && now.difference(heartbeat).inSeconds > 300) {
          stale.add(entry.key);
          agents.remove(entry.key);
        }
      }

      state['agents'] = agents;
      return stale;
    });
  }

  /// Check who owns a file. Returns terminal ID or null.
  String? _findFileOwner(Map<String, dynamic> agents, String filePath) {
    for (final entry in agents.entries) {
      final agent = entry.value as Map<String, dynamic>;
      final files = (agent['files_claimed'] as List<dynamic>?) ?? [];
      if (files.contains(filePath)) return entry.key;
    }
    return null;
  }

  /// Get a summary string for the system prompt.
  Future<String> getSummary() async {
    final state = await _read();
    final agents = (state['agents'] as Map<String, dynamic>?) ?? {};
    final plans = (state['active_plans'] as List<dynamic>?) ?? [];

    if (agents.isEmpty && plans.isEmpty) return 'No active agents or plans.';

    final lines = <String>[];
    for (final entry in agents.entries) {
      final a = entry.value as Map<String, dynamic>;
      lines.add('- ${entry.key}: ${a['status']} — ${a['task']}');
    }
    for (final plan in plans) {
      final p = plan as Map<String, dynamic>;
      final steps = (p['steps'] as List<dynamic>?) ?? [];
      final done = steps.where((s) => (s as Map)['status'] == 'done').length;
      lines.add('- Plan "${p['task']}": $done/${steps.length} steps done');
    }
    return lines.join('\n');
  }
}
