import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alfa_types.dart';
import 'claude_client.dart';
import 'tool_executor.dart';
import 'agents_state.dart';
import 'playbook_loader.dart';
import 'monitor_skill.dart';
import 'background_loop.dart';
import 'default_identity.dart';
import 'migration.dart';
import 'tools/terminal_tools.dart';
import 'tools/project_tools.dart';
import 'tools/knowledge_tools.dart';
import 'tools/filesystem_tools.dart';
import 'tools/state_tools.dart';
import 'tools/project_tools_v2.dart';
import 'tools/playbook_tools.dart';
import 'tools/code_tools.dart';
import 'tools/test_tools.dart';
import 'tools/routing_tools.dart';
import 'tools/delegate_tools.dart';
import '../projects/projects_provider.dart';
import '../../persistence/auto_save.dart';
import '../../core/database/database.dart';
import '../terminal/session_registry.dart';

class AlfaOrchestrator {
  final Ref ref;
  late final ToolExecutor _tools;
  ClaudeClient? _client;

  late final AgentsState _agentsState;
  late final PlaybookLoader _playbookLoader;
  MonitorSkill? _monitorSkill;
  BackgroundLoop? _backgroundLoop;

  final Map<String, TestTracker> _testTrackers = {};

  AlfaStatus _status = AlfaStatus.idle;
  int _turnCount = 0;
  int _maxTurns = 50;

  final _statusController = StreamController<AlfaStatus>.broadcast();
  final _messageController = StreamController<AlfaChatEvent>.broadcast();

  Stream<AlfaStatus> get statusStream => _statusController.stream;
  Stream<AlfaChatEvent> get messageStream => _messageController.stream;
  AlfaStatus get status => _status;

  AlfaOrchestrator(this.ref) {
    _agentsState = AgentsState();
    _playbookLoader = PlaybookLoader();

    _tools = ToolExecutor(ref);
    _tools.registerAll(terminalTools());
    _tools.registerAll(projectTools());
    _tools.register(_scanProjectEntry());
    _tools.registerAll(filesystemTools());
    _tools.registerAll(stateTools(_agentsState));
    _tools.registerAll(projectToolsV2());
    _tools.registerAll(playbookTools(_playbookLoader));
    _tools.register(_loopStatusTool());

    _tools.registerAll(codeTools());
    _tools.registerAll(testTools(_testTrackers, _emit));
    _tools.registerAll(routingTools());
    _tools.registerAll(delegateTools(_agentsState, _emit));
  }

  Future<void> initialize() async {
    final db = ref.read(databaseProvider);
    final apiKey = await db.settingsDao.getValue('alfa.api_key');
    final model = await db.settingsDao.getValue('alfa.model') ?? 'claude-sonnet-4-6';
    final maxTurns = await db.settingsDao.getValue('alfa.max_turns');

    if (apiKey == null || apiKey.isEmpty) return;

    _client = ClaudeClient(apiKey: apiKey, model: model);
    if (maxTurns != null) _maxTurns = int.tryParse(maxTurns) ?? 50;

    await ensureAlfaDirs();
    await migrateFromV1(ref);

    final identityFile = File('${alfaDir()}/identity.md');
    if (!await identityFile.exists()) {
      await writeFile(identityFile.path, defaultIdentity);
    }

    final memoryFile = File('${alfaDir()}/memory.md');
    if (!await memoryFile.exists()) {
      await writeFile(memoryFile.path, defaultMemory);
    }

    final logFile = File('${alfaDir()}/log.md');
    if (!await logFile.exists()) {
      final timestamp = DateTime.now().toUtc().toIso8601String();
      await writeFile(logFile.path, '- [$timestamp] Alfa initialized.\n');
    }

    await _playbookLoader.ensureDefaults();
    await _agentsState.cleanupStale();

    _monitorSkill = MonitorSkill(
      ref: ref,
      agentsState: _agentsState,
      onEvent: _emit,
    );
    _monitorSkill!.start();

    ref.read(sessionRegistryProvider.notifier).onOutputCallback =
        (terminalId, output) {
      if (terminalId.endsWith('-alfa')) {
        _monitorSkill!.onTerminalOutput(terminalId, output);
      }
    };

    _backgroundLoop = BackgroundLoop(
      ref: ref,
      agentsState: _agentsState,
      onEvent: _emit,
    );
    _backgroundLoop!.start();
  }

  Future<void> sendMessage(String userMessage) async {
    if (_client == null) {
      _emit(AlfaChatEvent.alfa(
          'Alfa is not configured. Set your API key in settings (alfa.api_key).'));
      return;
    }

    _backgroundLoop?.pause();
    _setStatus(AlfaStatus.thinking);
    _turnCount = 0;

    final db = ref.read(databaseProvider);
    final activeCwd = _getActiveCwd();
    await db.alfaConversationsDao.insertMessage(
      AlfaConversationsCompanion.insert(
        projectCwd: Value(activeCwd),
        role: 'human',
        content: userMessage,
      ),
    );
    _emit(AlfaChatEvent.human(userMessage));

    final systemPrompt = await _buildSystemPrompt(activeCwd);
    final messages = <AlfaMessage>[
      AlfaMessage(role: MessageRole.user, text: userMessage),
    ];

    try {
      await _runLoop(systemPrompt, messages, activeCwd);
    } catch (e) {
      _setStatus(AlfaStatus.error);
      _emit(AlfaChatEvent.alfa('Error: $e'));
    } finally {
      _setStatus(AlfaStatus.idle);
      _backgroundLoop?.resume();
    }
  }

  Future<void> _runLoop(
    String systemPrompt,
    List<AlfaMessage> messages,
    String? activeCwd,
  ) async {
    while (_turnCount < _maxTurns) {
      _turnCount++;

      if (_turnCount == _maxTurns - 5) {
        messages.add(AlfaMessage(
          role: MessageRole.user,
          text:
              '[System: You have ${_maxTurns - _turnCount} tool turns remaining. Wrap up and summarize progress.]',
        ));
      }

      _setStatus(AlfaStatus.thinking);

      final response = await _client!.sendMessage(
        systemPrompt: systemPrompt,
        messages: messages,
        tools: _tools.definitions,
        onTextDelta: (delta) => _emit(AlfaChatEvent.delta(delta)),
      );

      if (response.hasToolUse) {
        if (response.text.isNotEmpty) _emit(AlfaChatEvent.alfa(response.text));

        messages.add(AlfaMessage(
          role: MessageRole.assistant,
          text: response.text.isNotEmpty ? response.text : null,
          toolUses: response.toolUses,
        ));

        _setStatus(AlfaStatus.executing);
        final results = await _tools.executeAll(response.toolUses);

        for (var i = 0; i < response.toolUses.length; i++) {
          _emit(AlfaChatEvent.toolCall(
            response.toolUses[i].name,
            response.toolUses[i].input,
            results[i].content,
            results[i].isError,
          ));
        }

        messages.add(AlfaMessage(role: MessageRole.user, toolResults: results));
        continue;
      }

      if (response.text.isNotEmpty) {
        final db = ref.read(databaseProvider);
        await db.alfaConversationsDao.insertMessage(
          AlfaConversationsCompanion.insert(
            projectCwd: Value(activeCwd),
            role: 'alfa',
            content: response.text,
          ),
        );
        _emit(AlfaChatEvent.alfaDone(response.text));
      }

      break;
    }

    if (_turnCount >= _maxTurns) {
      _emit(AlfaChatEvent.alfa('[Reached $_maxTurns turn limit. Stopping.]'));
    }
  }

  Future<String> _buildSystemPrompt(String? activeCwd) async {
    final parts = <String>[];

    final identity = await loadFile('${alfaDir()}/identity.md');
    parts.add(identity.isNotEmpty ? identity : defaultIdentity);

    final memory = await loadFile('${alfaDir()}/memory.md');
    if (memory.isNotEmpty) {
      parts.add('## Alfa Memory\n\n${_truncate(memory, 8000)}');
    }

    if (activeCwd != null && activeCwd.isNotEmpty) {
      final projectPath = '${alfaDir()}/projects/${slugifyPath(activeCwd)}.md';
      var projectContent = await loadFile(projectPath);
      if (projectContent.isEmpty) {
        final label = activeCwd.split('/').last;
        projectContent = defaultProjectTemplate(label, activeCwd);
        await writeFile(projectPath, projectContent);
        parts.add(
          '## Project Knowledge\n\n$projectContent\n\n'
          'This is a new project. Use scan_project to learn about it.',
        );
      } else {
        parts.add('## Project Knowledge\n\n${_truncate(projectContent, 8000)}');
      }
    }

    final playbookSummary = await _playbookLoader.getPromptSummary();
    parts.add('## Available Playbooks\n\n$playbookSummary');

    final agentSummary = await _agentsState.getSummary();
    parts.add('## Agent State\n\n$agentSummary');

    final logContent = await loadFile('${alfaDir()}/log.md');
    if (logContent.isNotEmpty) {
      final logLines = logContent
          .split('\n')
          .where((l) => l.startsWith('- ['))
          .take(10)
          .join('\n');
      if (logLines.isNotEmpty) parts.add('## Recent Log\n\n$logLines');
    }

    final db = ref.read(databaseProvider);
    if (activeCwd != null && activeCwd.isNotEmpty) {
      final tasks = await db.tasksDao.getTasksForProject(activeCwd);
      final incomplete = tasks.where((t) => !t.done).toList();
      if (incomplete.isNotEmpty) {
        final taskLines = incomplete.map((t) {
          final desc = t.description.isNotEmpty ? ' — ${t.description}' : '';
          return '- [${t.id}] ${t.title}$desc';
        }).join('\n');
        parts.add('## Current Tasks\n\n$taskLines');
      } else {
        parts.add('## Current Tasks\n\nNo incomplete tasks.');
      }

      final notes = await db.notesDao.getNotesForProject(activeCwd);
      if (notes.isNotEmpty) {
        final preview = notes.first.body.length > 500
            ? '${notes.first.body.substring(0, 500)}...'
            : notes.first.body;
        if (preview.isNotEmpty) parts.add('## Notes\n\n$preview');
      }

      final tracker = _testTrackers[activeCwd];
      if (tracker != null && tracker.latest != null) {
        final s = tracker.getSummary();
        final trend = s['trend'] as String? ?? 'stable';
        final latest = s['latest_run'] as Map<String, dynamic>?;
        if (latest != null) {
          parts.add(
              '## Test Status\n\n${latest['passed']} passed, ${latest['failed']} failed — trend: $trend');
        }
      }
    }

    final recentMessages =
        await db.alfaConversationsDao.getForProject(activeCwd, limit: 20);
    if (recentMessages.isNotEmpty) {
      final lines = recentMessages.reversed.map((m) {
        final prefix = m.role == 'human' ? 'Human' : 'Alfa';
        final text = m.content.length > 200
            ? '${m.content.substring(0, 200)}...'
            : m.content;
        return '[$prefix] $text';
      });
      parts.add(
        '## Recent Conversation History\n\n'
        "Don't repeat yourself.\n\n${lines.join('\n\n')}",
      );
    }

    return parts.join('\n\n');
  }

  String _truncate(String s, int maxChars) =>
      s.length > maxChars ? '${s.substring(0, maxChars)}\n[truncated]' : s;

  String? _getActiveCwd() {
    final state = ref.read(projectsProvider);
    return state.groups
        .where((g) => g.id == state.activeGroupId)
        .firstOrNull
        ?.cwd;
  }

  void _setStatus(AlfaStatus s) {
    _status = s;
    _statusController.add(s);
  }

  void _emit(AlfaChatEvent event) => _messageController.add(event);

  AlfaToolEntry _loopStatusTool() => AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'get_loop_status',
          description:
              'Returns background loop status: running/paused, last tick, active alerts.',
          inputSchema: {'type': 'object', 'properties': {}},
        ),
        handler: (ref, params) async =>
            _backgroundLoop?.getStatus() ?? {'status': 'not_started'},
      );

  void dispose() {
    _backgroundLoop?.stop();
    _monitorSkill?.stop();
    _appendShutdownLog();
    _client?.close();
    _statusController.close();
    _messageController.close();
  }

  /// Fire-and-forget log append on shutdown. Runs in background, never throws.
  void _appendShutdownLog() {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final logPath = '${alfaDir()}/log.md';
    final entry = '- [$timestamp] Session ended.\n';
    _doShutdownLog(logPath, entry);
  }

  static Future<void> _doShutdownLog(String logPath, String entry) async {
    try {
      final existing = await File(logPath).readAsString();
      await File(logPath).writeAsString(entry + existing);
    } catch (_) {
      try { await writeFile(logPath, entry); } catch (_) {}
    }
  }
}

AlfaToolEntry _scanProjectEntry() =>
    knowledgeTools().firstWhere((t) => t.definition.name == 'scan_project');
