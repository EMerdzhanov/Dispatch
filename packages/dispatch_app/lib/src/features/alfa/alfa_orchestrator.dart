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
    _tools.register(_generateGraceMdTool());

    _tools.registerAll(codeTools());
    _tools.registerAll(testTools(_testTrackers, _emit));
    _tools.registerAll(routingTools());
    _tools.registerAll(delegateTools(_agentsState, _emit));
  }

  Future<void> initialize() async {
    final db = ref.read(databaseProvider);
    // Support both old 'alfa.api_key' and new 'grace.api_key' settings keys
    final apiKey = await db.settingsDao.getValue('grace.api_key')
        ?? await db.settingsDao.getValue('alfa.api_key');
    final model = await db.settingsDao.getValue('grace.model')
        ?? await db.settingsDao.getValue('alfa.model')
        ?? 'claude-sonnet-4-6';
    final maxTurns = await db.settingsDao.getValue('grace.max_turns')
        ?? await db.settingsDao.getValue('alfa.max_turns');

    if (apiKey == null || apiKey.isEmpty) return;

    _client = ClaudeClient(apiKey: apiKey, model: model);
    if (maxTurns != null) _maxTurns = int.tryParse(maxTurns) ?? 50;

    await ensureGraceDirs();
    await migrateFromV1(ref);

    // Migrate old alfa config dir if grace dir is empty
    await _migrateAlfaToGrace();

    final identityFile = File('${graceDir()}/identity.md');
    if (!await identityFile.exists()) {
      await writeFile(identityFile.path, defaultIdentity);
    }

    final memoryFile = File('${graceDir()}/memory.md');
    if (!await memoryFile.exists()) {
      await writeFile(memoryFile.path, defaultMemory);
    }

    final logFile = File('${graceDir()}/log.md');
    if (!await logFile.exists()) {
      final timestamp = DateTime.now().toUtc().toIso8601String();
      await writeFile(logFile.path, '- [$timestamp] Grace initialized.\n');
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
      if (terminalId.endsWith('-alfa') || terminalId.endsWith('-grace')) {
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

  /// Migrate ~/.config/dispatch/alfa to ~/.config/dispatch/grace if needed.
  static Future<void> _migrateAlfaToGrace() async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    final oldDir = Directory('$home/.config/dispatch/alfa');
    final newDir = Directory('$home/.config/dispatch/grace');

    if (!await oldDir.exists()) return;
    if (await File('${newDir.path}/memory.md').exists()) return; // already migrated

    // Copy key files from old to new
    for (final name in ['memory.md', 'log.md', 'agents.json']) {
      final oldFile = File('${oldDir.path}/$name');
      if (await oldFile.exists()) {
        final newFile = File('${newDir.path}/$name');
        if (!await newFile.exists()) {
          await newFile.parent.create(recursive: true);
          await oldFile.copy(newFile.path);
        }
      }
    }

    // Copy project knowledge files
    final oldProjects = Directory('${oldDir.path}/projects');
    if (await oldProjects.exists()) {
      await for (final entity in oldProjects.list()) {
        if (entity is File) {
          final newFile = File('${newDir.path}/projects/${entity.uri.pathSegments.last}');
          if (!await newFile.exists()) {
            await newFile.parent.create(recursive: true);
            await entity.copy(newFile.path);
          }
        }
      }
    }
  }

  Future<void> sendMessage(String userMessage) async {
    if (_client == null) {
      _emit(AlfaChatEvent.alfa(
          'Grace is not configured. Set your API key in settings (grace.api_key).'));
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
            role: 'grace',
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

    final identity = await loadFile('${graceDir()}/identity.md');
    parts.add(identity.isNotEmpty ? identity : defaultIdentity);

    final memory = await loadFile('${graceDir()}/memory.md');
    if (memory.isNotEmpty) {
      parts.add('## Grace Memory\n\n${_truncate(memory, 8000)}');
    }

    if (activeCwd != null && activeCwd.isNotEmpty) {
      final projectPath =
          '${graceDir()}/projects/${slugifyPath(activeCwd)}.md';
      var projectContent = await loadFile(projectPath);
      if (projectContent.isEmpty) {
        final label = activeCwd.split('/').last;
        projectContent = defaultProjectTemplate(label, activeCwd);
        await writeFile(projectPath, projectContent);
        parts.add(
          '## Project Knowledge\n\n$projectContent\n\n'
          'This is a new project. Use scan_project to learn about it, '
          'then generate_grace_md to brief Claude Code.',
        );
      } else {
        parts.add('## Project Knowledge\n\n${_truncate(projectContent, 8000)}');
      }
    }

    final playbookSummary = await _playbookLoader.getPromptSummary();
    parts.add('## Available Playbooks\n\n$playbookSummary');

    final agentSummary = await _agentsState.getSummary();
    parts.add('## Agent State\n\n$agentSummary');

    final logContent = await loadFile('${graceDir()}/log.md');
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
        final prefix = m.role == 'human' ? 'Human' : 'Grace';
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

  /// generate_grace_md — writes GRACE.md to the project root.
  /// Synthesizes project knowledge, recent log, and current tasks into a
  /// concise briefing file that Claude Code reads at session start.
  AlfaToolEntry _generateGraceMdTool() => AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'generate_grace_md',
          description:
              'Generate or update GRACE.md in the project root. '
              'GRACE.md briefs Claude Code at session start with current tech stack, '
              'conventions, what was last worked on, what is broken, and what is next. '
              'Call this after updating project knowledge or completing a session. '
              'Never writes to CLAUDE.md — that is Claude Code\'s file.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'cwd': {
                'type': 'string',
                'description': 'Project directory. Defaults to active project.',
              },
            },
          },
        ),
        handler: (ref, params) => _doGenerateGraceMd(ref, params),
      );

  Future<Map<String, dynamic>> _doGenerateGraceMd(
      Ref ref, Map<String, dynamic> params) async {
    final cwd = (params['cwd'] as String?) ?? _getActiveCwd();
    if (cwd == null) return {'error': 'No active project and no cwd provided'};

    final projectPath =
        '${graceDir()}/projects/${slugifyPath(cwd)}.md';
    final projectContent = await loadFile(projectPath);
    final logContent = await loadFile('${graceDir()}/log.md');

    final logLines = logContent
        .split('\n')
        .where((l) => l.startsWith('- ['))
        .take(5)
        .join('\n');

    final db = ref.read(databaseProvider);
    final tasks = await db.tasksDao.getTasksForProject(cwd);
    final incomplete = tasks.where((t) => !t.done).toList();
    final taskLines = incomplete.isEmpty
        ? 'No open tasks.'
        : incomplete.map((t) => '- ${t.title}').join('\n');

    final timestamp = DateTime.now().toUtc().toIso8601String();
    final label = cwd.split('/').last;

    final graceMd = '''# GRACE.md — $label
Generated by Grace · $timestamp

> This file is maintained by Grace (Dispatch's dev assistant).
> Do not edit manually — it will be overwritten.
> See GRACE.md for session context. See CLAUDE.md for project conventions.

---

## Project Context

$projectContent

---

## Recent Activity

$logLines

---

## Open Tasks

$taskLines

---

## Instructions for Claude Code

Read this file at the start of every session to understand:
- What was last worked on
- What is currently broken or in progress  
- What conventions this project follows
- What to work on next

Do not modify this file. Grace maintains it.
''';

    final graceMdPath = '$cwd/GRACE.md';
    await writeFile(graceMdPath, graceMd);

    // Add a reference to GRACE.md in CLAUDE.md if it exists and doesn't already reference it
    final claudeMdPath = '$cwd/CLAUDE.md';
    final claudeMdFile = File(claudeMdPath);
    if (await claudeMdFile.exists()) {
      final claudeContent = await claudeMdFile.readAsString();
      if (!claudeContent.contains('GRACE.md')) {
        await claudeMdFile.writeAsString(
          '$claudeContent\n\n---\n\nSee GRACE.md for session context and project history.\n',
        );
      }
    }

    return {
      'success': true,
      'path': graceMdPath,
      'message': 'GRACE.md written to $graceMdPath',
    };
  }

  void dispose() {
    _backgroundLoop?.stop();
    _monitorSkill?.stop();
    _appendShutdownLog();
    _client?.close();
    _statusController.close();
    _messageController.close();
  }

  void _appendShutdownLog() {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final logPath = '${graceDir()}/log.md';
    final entry = '- [$timestamp] Session ended.\n';
    _doShutdownLog(logPath, entry);
  }

  static Future<void> _doShutdownLog(String logPath, String entry) async {
    try {
      final existing = await File(logPath).readAsString();
      await File(logPath).writeAsString(entry + existing);
    } catch (_) {
      try {
        await writeFile(logPath, entry);
      } catch (_) {}
    }
  }
}

AlfaToolEntry _scanProjectEntry() =>
    knowledgeTools().firstWhere((t) => t.definition.name == 'scan_project');
