import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alfa_types.dart';
import 'agents_state.dart';
import 'default_identity.dart';
import '../../persistence/auto_save.dart';
import '../projects/projects_provider.dart';
import '../terminal/session_registry.dart';

/// Persistent loop state written to loop_state.json.
class LoopState {
  final Set<int> handledAlfaTasks;
  final Set<String> flaggedTerminals;
  final DateTime? lastGitCheck;
  final DateTime? lastTick;
  final List<String> activeAlerts;

  LoopState({
    Set<int>? handledAlfaTasks,
    Set<String>? flaggedTerminals,
    this.lastGitCheck,
    this.lastTick,
    List<String>? activeAlerts,
  })  : handledAlfaTasks = handledAlfaTasks ?? {},
        flaggedTerminals = flaggedTerminals ?? {},
        activeAlerts = activeAlerts ?? [];

  Map<String, dynamic> toJson() => {
        'handled_alfa_tasks': handledAlfaTasks.toList(),
        'flagged_terminals': flaggedTerminals.toList(),
        'last_git_check': lastGitCheck?.toIso8601String(),
        'last_tick': lastTick?.toIso8601String(),
        'active_alerts': activeAlerts,
      };

  factory LoopState.fromJson(Map<String, dynamic> json) => LoopState(
        handledAlfaTasks:
            (json['handled_alfa_tasks'] as List<dynamic>?)?.map((e) => e as int).toSet(),
        flaggedTerminals:
            (json['flagged_terminals'] as List<dynamic>?)?.map((e) => e as String).toSet(),
        lastGitCheck: json['last_git_check'] != null
            ? DateTime.tryParse(json['last_git_check'] as String)
            : null,
        lastTick: json['last_tick'] != null
            ? DateTime.tryParse(json['last_tick'] as String)
            : null,
        activeAlerts:
            (json['active_alerts'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}

/// Always-on background loop that watches for things needing attention.
/// Runs every 30 seconds, checking tasks, servers, errors, and git status.
class BackgroundLoop {
  final Ref ref;
  final AgentsState agentsState;
  final void Function(AlfaChatEvent event) onEvent;
  final Duration interval;

  Timer? _timer;
  int _tickCount = 0;
  bool _paused = false;
  bool _running = false;

  LoopState _state = LoopState();

  static final _ansiPattern =
      RegExp(r'\x1B\[[0-9;]*[A-Za-z]|\x1B\][^\x07]*\x07|\x1B[()][A-B012]');

  static final _errorPatterns = [
    RegExp(r'\bError:', caseSensitive: false),
    RegExp(r'\bFAILED\b', caseSensitive: false),
    RegExp(r'\bexception\b', caseSensitive: false),
    RegExp(r'\bcrash\b', caseSensitive: false),
    RegExp(r'\bpanic\b', caseSensitive: false),
  ];

  static final _serverPatterns = [
    RegExp(r'localhost', caseSensitive: false),
    RegExp(r'\bport\b', caseSensitive: false),
    RegExp(r'\blistening\b', caseSensitive: false),
    RegExp(r'\bstarted\b', caseSensitive: false),
  ];

  BackgroundLoop({
    required this.ref,
    required this.agentsState,
    required this.onEvent,
    this.interval = const Duration(seconds: 30),
  });

  bool get isRunning => _running;
  bool get isPaused => _paused;
  LoopState get loopState => _state;

  void start() {
    if (_running) return;
    _running = true;
    _loadState();
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  void pause() => _paused = true;
  void resume() => _paused = false;

  Future<void> _tick() async {
    if (_paused) return;

    _tickCount++;
    _state = LoopState(
      handledAlfaTasks: _state.handledAlfaTasks,
      flaggedTerminals: _state.flaggedTerminals,
      lastGitCheck: _state.lastGitCheck,
      lastTick: DateTime.now().toUtc(),
      activeAlerts: _state.activeAlerts,
    );

    try {
      await _checkAlfaTasks();
      await _checkServerHealth();
      await _checkBuildErrors();
      if (_tickCount % 5 == 0) await _checkGitStatus();
      await _checkAlfaTaskCompletion();
    } catch (_) {}

    await _saveState();
  }

  Future<void> _checkAlfaTasks() async {
    final cwd = _getActiveCwd();
    if (cwd == null) return;

    final db = ref.read(databaseProvider);
    final tasks = await db.tasksDao.getTasksForProject(cwd);

    for (final task in tasks) {
      if (task.done) continue;
      if (!task.title.toLowerCase().startsWith('[alfa]')) continue;
      if (_state.handledAlfaTasks.contains(task.id)) continue;

      final agentState = await agentsState.readState();
      final agents = (agentState['agents'] as Map<String, dynamic>?) ?? {};
      final alreadyHandled = agents.values.any((a) {
        final agent = a as Map<String, dynamic>;
        return agent['task']?.toString().contains(task.title) == true &&
            agent['status'] == 'working';
      });

      if (!alreadyHandled) {
        _state.handledAlfaTasks.add(task.id);
        onEvent(AlfaChatEvent.alfa(
          '[Background] New [ALFA] task: "${task.title}". Injecting.',
        ));
        final message = 'New task assigned: ${task.title}'
            '${task.description.isNotEmpty ? '. Details: ${task.description}' : ''}. '
            'Handle this now.';
        onEvent(AlfaChatEvent.human(message));
      }
    }
  }

  Future<void> _checkServerHealth() async {
    final registry = ref.read(sessionRegistryProvider);

    for (final entry in registry.entries) {
      final id = entry.key;
      final record = entry.value;

      final output = record.outputBuffer.toList();
      if (output.length < 2) continue;

      final sample = output
          .skip(output.length > 20 ? output.length - 20 : 0)
          .join('\n')
          .replaceAll(_ansiPattern, '');

      final isServer = _serverPatterns.any((p) => p.hasMatch(sample));
      if (!isServer) continue;

      final meta = record.meta;
      if (meta.lastActivityTime == null) continue;

      final idleSeconds =
          DateTime.now().difference(meta.lastActivityTime!).inSeconds;
      if (idleSeconds > 300) {
        final key = '$id:server_idle';
        if (!_state.flaggedTerminals.contains(key)) {
          _state.flaggedTerminals.add(key);
          _state.activeAlerts
              .add('Server in $id may have crashed — no output for 5+ minutes');
          onEvent(AlfaChatEvent.alfa(
            '[Background] Dev server in $id may have crashed — '
            'no output for ${idleSeconds ~/ 60} minutes.',
          ));
        }
      }
    }
  }

  Future<void> _checkBuildErrors() async {
    final registry = ref.read(sessionRegistryProvider);

    for (final entry in registry.entries) {
      final id = entry.key;
      final record = entry.value;

      if (id.endsWith('-alfa') || id.endsWith('-mcp')) continue;

      final output = record.outputBuffer.toList();
      if (output.isEmpty) continue;

      final tail = output
          .skip(output.length > 20 ? output.length - 20 : 0)
          .join('\n')
          .replaceAll(_ansiPattern, '');

      final hasError = _errorPatterns.any((p) => p.hasMatch(tail));
      final flagKey = '$id:build_error';

      if (hasError && !_state.flaggedTerminals.contains(flagKey)) {
        _state.flaggedTerminals.add(flagKey);
        _state.activeAlerts.add('Build/test error detected in $id');
        onEvent(AlfaChatEvent.alfa(
          '[Background] Build/test error detected in terminal $id.',
        ));
      } else if (!hasError && _state.flaggedTerminals.contains(flagKey)) {
        _state.flaggedTerminals.remove(flagKey);
        _state.activeAlerts.removeWhere((a) => a.contains(id));
      }
    }
  }

  Future<void> _checkGitStatus() async {
    final cwd = _getActiveCwd();
    if (cwd == null) return;

    final gitDir = Directory('$cwd/.git');
    if (!await gitDir.exists()) return;

    try {
      final result = await Process.run(
        'git', ['status', '--short'],
        workingDirectory: cwd,
      ).timeout(const Duration(seconds: 5));

      final output = (result.stdout as String).trim();
      _state = LoopState(
        handledAlfaTasks: _state.handledAlfaTasks,
        flaggedTerminals: _state.flaggedTerminals,
        lastGitCheck: DateTime.now().toUtc(),
        lastTick: _state.lastTick,
        activeAlerts: _state.activeAlerts,
      );

      if (output.isEmpty) return;

      final files = output
          .split('\n')
          .map((l) => l.trim().split(RegExp(r'\s+')).last)
          .where((f) => f.isNotEmpty)
          .toList();

      DateTime? oldest;
      for (final filePath in files) {
        final file = File('$cwd/$filePath');
        if (await file.exists()) {
          final modified = await file.lastModified();
          if (oldest == null || modified.isBefore(oldest)) oldest = modified;
        }
      }

      if (oldest != null) {
        final age = DateTime.now().difference(oldest);
        if (age.inHours >= 2) {
          const flagKey = 'git:uncommitted';
          if (!_state.flaggedTerminals.contains(flagKey)) {
            _state.flaggedTerminals.add(flagKey);
            _state.activeAlerts
                .add('Uncommitted changes older than ${age.inHours} hours');
            onEvent(AlfaChatEvent.alfa(
              '[Background] Uncommitted changes older than ${age.inHours} hours. '
              '${files.length} file(s) modified.',
            ));
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _checkAlfaTaskCompletion() async {
    final cwd = _getActiveCwd();
    if (cwd == null) return;

    final agentState = await agentsState.readState();
    final agents = (agentState['agents'] as Map<String, dynamic>?) ?? {};

    final db = ref.read(databaseProvider);
    final tasks = await db.tasksDao.getTasksForProject(cwd);

    for (final task in tasks) {
      if (task.done) continue;
      if (!task.title.toLowerCase().startsWith('[alfa]')) continue;
      if (!_state.handledAlfaTasks.contains(task.id)) continue;

      final handlingAgent = agents.entries.where((e) {
        final agent = e.value as Map<String, dynamic>;
        return agent['task']?.toString().contains(task.title) == true;
      }).firstOrNull;

      if (handlingAgent == null) continue;

      final agent = handlingAgent.value as Map<String, dynamic>;
      final status = agent['status'] as String?;

      if (status == 'done' || status == 'completed') {
        await db.tasksDao.markDone(task.id);
        _state.handledAlfaTasks.remove(task.id);
        onEvent(AlfaChatEvent.alfa(
          '[Background] [ALFA] task "${task.title}" completed by ${handlingAgent.key}.',
        ));
      }
    }
  }

  String? _getActiveCwd() {
    final state = ref.read(projectsProvider);
    return state.groups
        .where((g) => g.id == state.activeGroupId)
        .firstOrNull
        ?.cwd;
  }

  Future<void> _saveState() async {
    try {
      final path = '${alfaDir()}/loop_state.json';
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(_state.toJson()));
    } catch (_) {}
  }

  Future<void> _loadState() async {
    try {
      final path = '${alfaDir()}/loop_state.json';
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        _state = LoopState.fromJson(jsonDecode(content) as Map<String, dynamic>);
      }
    } catch (_) {
      _state = LoopState();
    }
  }

  Map<String, dynamic> getStatus() => {
        'running': _running,
        'paused': _paused,
        'tick_count': _tickCount,
        'last_tick': _state.lastTick?.toIso8601String(),
        'last_git_check': _state.lastGitCheck?.toIso8601String(),
        'handled_alfa_tasks': _state.handledAlfaTasks.toList(),
        'flagged_terminals': _state.flaggedTerminals.toList(),
        'active_alerts': _state.activeAlerts,
      };
}
