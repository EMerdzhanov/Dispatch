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
import 'default_identity.dart';
import 'migration.dart';
import 'tools/terminal_tools.dart';
import 'tools/project_tools.dart';
import 'tools/knowledge_tools.dart';
import 'tools/filesystem_tools.dart';
import 'tools/state_tools.dart';
import 'tools/project_tools_v2.dart';
import 'tools/playbook_tools.dart';
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
    // Keep scan_project from knowledge_tools (read_project_knowledge and
    // update_project_knowledge are superseded by project_tools_v2 but
    // scan_project is still needed and lives here for now)
    _tools.register(_scanProjectEntry());
    _tools.registerAll(filesystemTools());
    _tools.registerAll(stateTools(_agentsState));
    _tools.registerAll(projectToolsV2());
    _tools.registerAll(playbookTools(_playbookLoader));
  }

  Future<void> initialize() async {
    final db = ref.read(databaseProvider);
    final apiKey = await db.settingsDao.getValue('alfa.api_key');
    final model = await db.settingsDao.getValue('alfa.model') ?? 'claude-sonnet-4-6';
    final maxTurns = await db.settingsDao.getValue('alfa.max_turns');

    if (apiKey == null || apiKey.isEmpty) return;

    _client = ClaudeClient(apiKey: apiKey, model: model);
    if (maxTurns != null) _maxTurns = int.tryParse(maxTurns) ?? 50;

    // Startup sequence
    await ensureAlfaDirs();
    await migrateFromV1(ref);

    // Create default identity.md if missing
    final identityFile = File('${alfaDir()}/identity.md');
    if (!await identityFile.exists()) {
      await writeFile(identityFile.path, defaultIdentity);
    }

    await _playbookLoader.ensureDefaults();
    await _agentsState.cleanupStale();

    // Start MonitorSkill
    _monitorSkill = MonitorSkill(
      ref: ref,
      agentsState: _agentsState,
      onEvent: _emit,
    );
    _monitorSkill!.start();

    // Hook MonitorSkill into SessionRegistry for event-driven monitoring
    ref.read(sessionRegistryProvider.notifier).onOutputCallback = (terminalId, output) {
      if (terminalId.endsWith('-alfa')) {
        _monitorSkill!.onTerminalOutput(terminalId, output);
      }
    };
  }

  Future<void> sendMessage(String userMessage) async {
    if (_client == null) {
      _emit(AlfaChatEvent.alfa('Alfa is not configured. Set your API key in settings (alfa.api_key).'));
      return;
    }

    _setStatus(AlfaStatus.thinking);
    _turnCount = 0;

    // Save human message to DB
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

    // Build system prompt
    final systemPrompt = await _buildSystemPrompt(activeCwd);

    // Build conversation (single turn — ephemeral)
    final messages = <AlfaMessage>[
      AlfaMessage(role: MessageRole.user, text: userMessage),
    ];

    // Agentic loop
    try {
      await _runLoop(systemPrompt, messages, activeCwd);
    } catch (e) {
      _setStatus(AlfaStatus.error);
      _emit(AlfaChatEvent.alfa('Error: $e'));
    } finally {
      _setStatus(AlfaStatus.idle);
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
          text: '[System: You have ${_maxTurns - _turnCount} tool turns remaining. Wrap up and summarize progress.]',
        ));
      }

      _setStatus(AlfaStatus.thinking);

      final textBuffer = StringBuffer();
      final response = await _client!.sendMessage(
        systemPrompt: systemPrompt,
        messages: messages,
        tools: _tools.definitions,
        onTextDelta: (delta) {
          textBuffer.write(delta);
          _emit(AlfaChatEvent.delta(delta));
        },
      );

      if (response.hasToolUse) {
        // Emit any text that came before the tool calls so the UI
        // clears the streaming buffer and shows it as a message
        if (response.text.isNotEmpty) {
          _emit(AlfaChatEvent.alfa(response.text));
        }

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

        messages.add(AlfaMessage(
          role: MessageRole.user,
          toolResults: results,
        ));

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

    // 1. Identity — read identity.md
    final identity = await loadFile('${alfaDir()}/identity.md');
    parts.add(identity.isNotEmpty ? identity : defaultIdentity);

    // 2. Memory — read memory.md, truncate to ~8000 chars
    final memory = await loadFile('${alfaDir()}/memory.md');
    if (memory.isNotEmpty) {
      parts.add('## Memory\n\n${_truncate(memory, 8000)}');
    }

    // 3. Project context — read projects/{slugified-cwd}.md, truncate to ~8000 chars
    if (activeCwd != null && activeCwd.isNotEmpty) {
      final projectContent = await loadFile(
        '${alfaDir()}/projects/${slugifyPath(activeCwd)}.md',
      );
      if (projectContent.isNotEmpty) {
        parts.add('## Current Project Context\n\n${_truncate(projectContent, 8000)}');
      } else {
        parts.add(
          '## Current Project Context\n\n'
          'No project context yet for: $activeCwd\n'
          'Use scan_project to learn about this codebase, then update_project to save findings.',
        );
      }
    }

    // 4. Available playbooks — summary from PlaybookLoader
    final playbookSummary = await _playbookLoader.getPromptSummary();
    parts.add('## Available Playbooks\n\n$playbookSummary');

    // 5. Agent state — summary from AgentsState
    final agentSummary = await _agentsState.getSummary();
    parts.add('## Agent State\n\n$agentSummary');

    // 6. Recent log — last 10 lines from log.md
    final logContent = await loadFile('${alfaDir()}/log.md');
    if (logContent.isNotEmpty) {
      final logLines = logContent
          .split('\n')
          .where((l) => l.startsWith('- ['))
          .take(10)
          .join('\n');
      if (logLines.isNotEmpty) {
        parts.add('## Recent Log\n\n$logLines');
      }
    }

    // 7. Recent conversation — from DB
    final db = ref.read(databaseProvider);
    final recentMessages = await db.alfaConversationsDao.getForProject(
      activeCwd,
      limit: 20,
    );
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
        'You said these things recently. You remember this context. Don\'t repeat yourself.\n\n'
        '${lines.join('\n\n')}',
      );
    }

    return parts.join('\n\n');
  }

  String _truncate(String s, int maxChars) =>
      s.length > maxChars ? '${s.substring(0, maxChars)}\n[truncated]' : s;

  String? _getActiveCwd() {
    final state = ref.read(projectsProvider);
    final group = state.groups
        .where((g) => g.id == state.activeGroupId)
        .firstOrNull;
    return group?.cwd;
  }

  void _setStatus(AlfaStatus s) {
    _status = s;
    _statusController.add(s);
  }

  void _emit(AlfaChatEvent event) {
    _messageController.add(event);
  }

  void dispose() {
    _monitorSkill?.stop();

    // Best-effort shutdown: append summary to log.md
    _appendShutdownLog();

    _client?.close();
    _statusController.close();
    _messageController.close();
  }

  /// Fire-and-forget log append on shutdown. Errors are silently ignored.
  void _appendShutdownLog() {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final logPath = '${alfaDir()}/log.md';
    final entry = '- [$timestamp] Session ended.\n';

    File(logPath).readAsString().then((existing) {
      File(logPath).writeAsString(entry + existing);
    }).catchError((_) {
      // If file doesn't exist yet, create it
      writeFile(logPath, entry);
    });
  }
}

/// Extract only the scan_project tool entry from knowledge_tools.
/// The old read_project_knowledge / update_project_knowledge tools are
/// superseded by project_tools_v2 (read_project / update_project).
AlfaToolEntry _scanProjectEntry() {
  return knowledgeTools().firstWhere((t) => t.definition.name == 'scan_project');
}

/// Events emitted by the orchestrator to the UI.
sealed class AlfaChatEvent {
  const AlfaChatEvent();

  factory AlfaChatEvent.human(String text) = HumanMessageEvent;
  factory AlfaChatEvent.alfa(String text) = AlfaMessageEvent;
  factory AlfaChatEvent.alfaDone(String text) = AlfaDoneEvent;
  factory AlfaChatEvent.delta(String text) = AlfaDeltaEvent;
  factory AlfaChatEvent.toolCall(
    String name,
    Map<String, dynamic> input,
    String result,
    bool isError,
  ) = ToolCallEvent;
}

class HumanMessageEvent extends AlfaChatEvent {
  final String text;
  const HumanMessageEvent(this.text);
}

class AlfaMessageEvent extends AlfaChatEvent {
  final String text;
  const AlfaMessageEvent(this.text);
}

class AlfaDoneEvent extends AlfaChatEvent {
  final String text;
  const AlfaDoneEvent(this.text);
}

class AlfaDeltaEvent extends AlfaChatEvent {
  final String text;
  const AlfaDeltaEvent(this.text);
}

class ToolCallEvent extends AlfaChatEvent {
  final String name;
  final Map<String, dynamic> input;
  final String result;
  final bool isError;
  const ToolCallEvent(this.name, this.input, this.result, this.isError);
}
