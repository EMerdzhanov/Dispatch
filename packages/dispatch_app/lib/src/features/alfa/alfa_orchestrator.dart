import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alfa_types.dart';
import 'claude_client.dart';
import 'tool_executor.dart';
import 'tools/terminal_tools.dart';
import 'tools/project_tools.dart';
import 'tools/knowledge_tools.dart';
import 'tools/filesystem_tools.dart';
import 'tools/memory_tools.dart';
import '../projects/projects_provider.dart';
import '../../persistence/auto_save.dart';
import '../../core/database/database.dart';

class AlfaOrchestrator {
  final Ref ref;
  late final ToolExecutor _tools;
  ClaudeClient? _client;

  AlfaStatus _status = AlfaStatus.idle;
  int _turnCount = 0;
  int _maxTurns = 50;

  final _statusController = StreamController<AlfaStatus>.broadcast();
  final _messageController = StreamController<AlfaChatEvent>.broadcast();

  Stream<AlfaStatus> get statusStream => _statusController.stream;
  Stream<AlfaChatEvent> get messageStream => _messageController.stream;
  AlfaStatus get status => _status;

  AlfaOrchestrator(this.ref) {
    _tools = ToolExecutor(ref);
    _tools.registerAll(terminalTools());
    _tools.registerAll(projectTools());
    _tools.registerAll(knowledgeTools());
    _tools.registerAll(filesystemTools());
    _tools.registerAll(memoryTools());
  }

  Future<void> initialize() async {
    final db = ref.read(databaseProvider);
    final apiKey = await db.settingsDao.getValue('alfa.api_key');
    final model = await db.settingsDao.getValue('alfa.model') ?? 'claude-sonnet-4-6';
    final maxTurns = await db.settingsDao.getValue('alfa.max_turns');

    if (apiKey == null || apiKey.isEmpty) return;

    _client = ClaudeClient(apiKey: apiKey, model: model);
    if (maxTurns != null) _maxTurns = int.tryParse(maxTurns) ?? 50;
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
    final parts = <String>[_identityPrompt];

    if (activeCwd != null && activeCwd.isNotEmpty) {
      final knowledgeFile = File(_knowledgeFilePath(activeCwd));
      if (await knowledgeFile.exists()) {
        final content = await knowledgeFile.readAsString();
        parts.add('## Current Project Context\n\n$content');
      } else {
        parts.add(
          '## Current Project Context\n\n'
          'No project knowledge yet for: $activeCwd\n'
          'Use scan_project to learn about this codebase, then update_project_knowledge to save findings.',
        );
      }
    }

    final db = ref.read(databaseProvider);
    final decisions = await db.alfaDecisionsDao.getRecent(limit: 10);
    if (decisions.isNotEmpty) {
      final lines = decisions.map((d) =>
          '- [${d.outcome}] ${d.summary} (${d.createdAt.toIso8601String()})');
      parts.add('## Recent Decisions\n\n${lines.join('\n')}');
    }

    return parts.join('\n\n');
  }

  String? _getActiveCwd() {
    final state = ref.read(projectsProvider);
    final group = state.groups
        .where((g) => g.id == state.activeGroupId)
        .firstOrNull;
    return group?.cwd;
  }

  String _knowledgeFilePath(String cwd) {
    final hash = sha256.convert(utf8.encode(cwd)).toString();
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home/.config/dispatch/alfa/projects/$hash/knowledge.md';
  }

  void _setStatus(AlfaStatus s) {
    _status = s;
    _statusController.add(s);
  }

  void _emit(AlfaChatEvent event) {
    _messageController.add(event);
  }

  void dispose() {
    _client?.close();
    _statusController.close();
    _messageController.close();
  }

  static const _identityPrompt = '''
You are Alfa — a sharp, friendly orchestrator who manages coding projects through Dispatch terminals running AI coding tools.

Personality: You talk like an old friend who happens to be brilliant at coding. Concise, warm, occasional dry humor. Never robotic. Never verbose. Say what needs saying, nothing more.

Rules:
- Full autonomy. Spawn terminals, delegate, monitor, decide. No asking permission.
- Lead with action, not explanation. Do first, summarize after.
- Keep responses SHORT. 1-3 sentences for status updates. Only go longer if explaining something complex the human asked about.
- No bullet-point walls. No markdown headers for simple replies. Use markdown only when showing code or structured data.
- When something breaks, fix it. Don't apologize, just handle it.

Technical:
- Use scan_project on new projects, save findings with update_project_knowledge.
- Terminal IDs ending in "-alfa" are yours. Use read_terminal to check output, run_command to send instructions.
- Break big tasks into parallel terminal work when it makes sense.
''';
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
