import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'grace_types.dart';
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

class GraceOrchestrator {
  final Ref ref;
  late final ToolExecutor _tools;
  ClaudeClient? _client;

  late final AgentsState _agentsState;
  late final PlaybookLoader _playbookLoader;
  MonitorSkill? _monitorSkill;
  BackgroundLoop? _backgroundLoop;

  final Map<String, TestTracker> _testTrackers = {};

  GraceStatus _status = GraceStatus.idle;
  int _turnCount = 0;
  int _maxTurns = 50;

  final _statusController = StreamController<GraceStatus>.broadcast();
  final _messageController = StreamController<GraceChatEvent>.broadcast();

  Stream<GraceStatus> get statusStream => _statusController.stream;
  Stream<GraceChatEvent> get messageStream => _messageController.stream;
  GraceStatus get status => _status;

  GraceOrchestrator(this.ref) {
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
    final apiKey = await db.settingsDao.getValue('grace.api_key')
        ?? await db.settingsDao.getValue('grace.api_key');
    final model = await db.settingsDao.getValue('grace.model')
        ?? await db.settingsDao.getValue('grace.model')
        ?? 'claude-sonnet-4-6';
    final maxTurns = await db.settingsDao.getValue('grace.max_turns')
        ?? await db.settingsDao.getValue('grace.max_turns');

    if (apiKey == null || apiKey.isEmpty) return;

    _client = ClaudeClient(apiKey: apiKey, model: model);
    if (maxTurns != null) _maxTurns = int.tryParse(maxTurns) ?? 50;

    await ensureGraceDirs();
    await migrateFromV1(ref);
    await _migrateOldAlfaToGrace();

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

    // Watch ALL terminals — Grace monitors everything, not just ones she spawned
    ref.read(sessionRegistryProvider.notifier).onOutputCallback =
        (terminalId, output) {
      _monitorSkill!.onTerminalOutput(terminalId, output);
    };

    _backgroundLoop = BackgroundLoop(
      ref: ref,
      agentsState: _agentsState,
      onEvent: _emit,
    );
    _backgroundLoop!.start();
  }

  static Future<void> _migrateOldAlfaToGrace() async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    final oldDir = Directory('$home/.config/dispatch/alfa');
    final newDir = Directory('$home/.config/dispatch/grace');

    if (!await oldDir.exists()) return;
    if (await File('${newDir.path}/memory.md').exists()) return;

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

    final oldProjects = Directory('${oldDir.path}/projects');
    if (await oldProjects.exists()) {
      await for (final entity in oldProjects.list()) {
        if (entity is File) {
          final newFile = File(
              '${newDir.path}/projects/${entity.uri.pathSegments.last}');
          if (!await newFile.exists()) {
            await newFile.parent.create(recursive: true);
            await entity.copy(newFile.path);
          }
        }
      }
    }
  }

  Future<void> sendMessage(String userMessage, {List<GraceAttachment>? attachments}) async {
    if (_client == null) {
      _emit(GraceChatEvent.grace(
          'Grace is not configured. Set your API key in settings (grace.api_key).'));
      return;
    }

    _backgroundLoop?.pause();
    _setStatus(GraceStatus.thinking);
    _turnCount = 0;

    final db = ref.read(databaseProvider);
    final activeCwd = _getActiveCwd();
    final fileNames = attachments?.map((a) => a.fileName).toList() ?? [];
    final displayText = fileNames.isEmpty
        ? userMessage
        : '$userMessage\n[Attached: ${fileNames.join(', ')}]';
    await db.graceConversationsDao.insertMessage(
      GraceConversationsCompanion.insert(
        projectCwd: Value(activeCwd),
        role: 'human',
        content: displayText,
      ),
    );
    _emit(GraceChatEvent.human(displayText));

    final systemPrompt = await _buildSystemPrompt(activeCwd);
    final messages = <GraceMessage>[
      GraceMessage(
        role: MessageRole.user,
        text: userMessage,
        attachments: attachments,
      ),
    ];

    try {
      await _runLoop(systemPrompt, messages, activeCwd);
    } catch (e) {
      _setStatus(GraceStatus.error);
      _emit(GraceChatEvent.grace('Error: $e'));
    } finally {
      _setStatus(GraceStatus.idle);
      _backgroundLoop?.resume();
    }
  }

  Future<void> _runLoop(
    String systemPrompt,
    List<GraceMessage> messages,
    String? activeCwd,
  ) async {
    while (_turnCount < _maxTurns) {
      _turnCount++;

      if (_turnCount == _maxTurns - 5) {
        messages.add(GraceMessage(
          role: MessageRole.user,
          text:
              '[System: You have ${_maxTurns - _turnCount} tool turns remaining. Wrap up and summarize progress.]',
        ));
      }

      _setStatus(GraceStatus.thinking);

      final response = await _client!.sendMessage(
        systemPrompt: systemPrompt,
        messages: messages,
        tools: _tools.definitions,
        onTextDelta: (delta) => _emit(GraceChatEvent.delta(delta)),
      );

      if (response.hasToolUse) {
        if (response.text.isNotEmpty) _emit(GraceChatEvent.grace(response.text));

        messages.add(GraceMessage(
          role: MessageRole.assistant,
          text: response.text.isNotEmpty ? response.text : null,
          toolUses: response.toolUses,
        ));

        _setStatus(GraceStatus.executing);
        final results = await _tools.executeAll(response.toolUses);

        for (var i = 0; i < response.toolUses.length; i++) {
          _emit(GraceChatEvent.toolCall(
            response.toolUses[i].name,
            response.toolUses[i].input,
            results[i].content,
            results[i].isError,
          ));
        }

        messages.add(GraceMessage(role: MessageRole.user, toolResults: results));
        continue;
      }

      if (response.text.isNotEmpty) {
        final db = ref.read(databaseProvider);
        await db.graceConversationsDao.insertMessage(
          GraceConversationsCompanion.insert(
            projectCwd: Value(activeCwd),
            role: 'grace',
            content: response.text,
          ),
        );
        _emit(GraceChatEvent.graceDone(response.text));
      }

      break;
    }

    if (_turnCount >= _maxTurns) {
      _emit(GraceChatEvent.grace('[Reached $_maxTurns turn limit. Stopping.]'));
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
        await db.graceConversationsDao.getForProject(activeCwd, limit: 20);
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

  void _setStatus(GraceStatus s) {
    _status = s;
    _statusController.add(s);
  }

  void _emit(GraceChatEvent event) => _messageController.add(event);

  GraceToolEntry _loopStatusTool() => GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'get_loop_status',
          description:
              'Returns background loop status: running/paused, last tick, active alerts.',
          inputSchema: {'type': 'object', 'properties': {}},
        ),
        handler: (ref, params) async =>
            _backgroundLoop?.getStatus() ?? {'status': 'not_started'},
      );

  // ---------------------------------------------------------------------------
  // generate_grace_md — smart GRACE.md that adapts to CLAUDE.md presence
  // ---------------------------------------------------------------------------

  GraceToolEntry _generateGraceMdTool() => GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'generate_grace_md',
          description:
              'Generate or update GRACE.md in the project root. '
              'Grace reads CLAUDE.md first — if it is detailed (has tech stack, '
              'architecture, or commands), GRACE.md writes session state only '
              '(last worked on, open tasks, recent decisions). '
              'If CLAUDE.md is sparse or missing, GRACE.md writes the full brief. '
              'Never duplicates what CLAUDE.md already covers. '
              'Never writes to CLAUDE.md except to add a one-line reference. '
              'Call after any session where meaningful work was done.',
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

    final label = cwd.split('/').last;
    final timestamp =
        DateTime.now().toUtc().toIso8601String().split('T').first;
    final graceMdPath = '$cwd/GRACE.md';
    final claudeMdPath = '$cwd/CLAUDE.md';

    // Read CLAUDE.md to decide what Grace needs to cover
    final claudeMdFile = File(claudeMdPath);
    final claudeExists = await claudeMdFile.exists();
    final claudeContent = claudeExists ? await claudeMdFile.readAsString() : '';

    // "detailed" = CLAUDE.md already covers tech stack / architecture / commands
    final claudeIsDetailed = claudeExists &&
        (claudeContent.toLowerCase().contains('## tech stack') ||
            claudeContent.toLowerCase().contains('## architecture') ||
            claudeContent.toLowerCase().contains('## commands') ||
            claudeContent.length > 500);

    // Load Grace's own data
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
        : incomplete.map((t) {
            final desc =
                t.description.isNotEmpty ? ' — ${t.description}' : '';
            return '- ${t.title}$desc';
          }).join('\n');

    final buf = StringBuffer();

    // Header
    buf.writeln('# GRACE.md — $label');
    buf.writeln('Generated by Grace · $timestamp');
    buf.writeln(
        '> Maintained by Grace (Dispatch). Do not edit manually — will be regenerated.');
    if (claudeIsDetailed) {
      buf.writeln(
          '> Tech stack, commands, and conventions are in CLAUDE.md — not duplicated here.');
    }
    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    // Full project brief — only when CLAUDE.md is sparse or missing
    if (!claudeIsDetailed && projectContent.isNotEmpty) {
      buf.writeln('## Project Brief');
      buf.writeln();
      buf.writeln(projectContent.trim());
      buf.writeln();
      buf.writeln('---');
      buf.writeln();
    }

    // Session state — always written
    buf.writeln('## Last Worked On');
    buf.writeln();
    buf.writeln(logLines.isNotEmpty ? logLines : 'No recent session log.');
    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    buf.writeln('## Open Tasks');
    buf.writeln();
    buf.writeln(taskLines);
    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    // Instructions
    buf.writeln('## For Claude Code');
    buf.writeln();
    if (claudeIsDetailed) {
      buf.writeln('- Read **CLAUDE.md** for tech stack, commands, conventions');
      buf.writeln(
          '- This file has session context only — what changed, what is next');
    } else {
      buf.writeln('- No detailed CLAUDE.md found — all project context is above');
    }
    buf.writeln('- Grace maintains this file. Do not edit manually.');

    await writeFile(graceMdPath, buf.toString());

    // Add one-line reference in CLAUDE.md if missing
    if (claudeExists && !claudeContent.contains('GRACE.md')) {
      await claudeMdFile.writeAsString(
        '$claudeContent\n\n---\n\nSee GRACE.md for session context (last worked on, open tasks).\n',
      );
    }

    final mode = claudeIsDetailed ? 'session-state-only' : 'full-brief';
    return {
      'success': true,
      'path': graceMdPath,
      'mode': mode,
      'claude_md_found': claudeExists,
      'claude_md_detailed': claudeIsDetailed,
      'message': claudeIsDetailed
          ? 'GRACE.md written (session state only — CLAUDE.md covers the rest)'
          : 'GRACE.md written (full brief — CLAUDE.md is sparse or missing)',
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

GraceToolEntry _scanProjectEntry() =>
    knowledgeTools().firstWhere((t) => t.definition.name == 'scan_project');
