# Alfa Orchestrator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an AI orchestrator agent (Alfa) to Dispatch that manages terminals running Claude Code via the Claude API, with project knowledge, decision memory, and a chat panel UI.

**Architecture:** Alfa is a Dart class with Ref injection (McpServer pattern) running an agentic tool-use loop against Claude's Messages API. It shares tool handler code with existing MCP tools and adds knowledge/decision tools backed by Drift DB and markdown files.

**Tech Stack:** Dart/Flutter, Riverpod, Drift (SQLite), Claude Messages API (HTTP), shelf (existing)

**Spec:** `docs/superpowers/specs/2026-03-22-alfa-orchestrator-design.md`

---

## File Structure

### New Files
```
packages/dispatch_app/lib/src/features/alfa/
  alfa_orchestrator.dart        — Main orchestrator class (Ref-injected, agentic loop)
  claude_client.dart            — HTTP client for Claude Messages API (streaming)
  tool_executor.dart            — Tool registry + execution engine
  tools/
    terminal_tools.dart         — spawn, write, run_command, read, kill, list (reuses MCP handlers)
    project_tools.dart          — create, close, list projects (reuses MCP handlers)
    knowledge_tools.dart        — read/update project knowledge, scan project
    filesystem_tools.dart       — read_file, list_directory, run_shell_command
    memory_tools.dart           — save_decision, search_decisions
  alfa_provider.dart            — Riverpod provider + state
  alfa_panel.dart               — Chat panel UI widget
  alfa_types.dart               — Message, ToolCall, ToolResult types
```

### Modified Files
```
packages/dispatch_app/lib/src/core/database/tables.dart         — Add AlfaDecisions, AlfaConversations tables
packages/dispatch_app/lib/src/core/database/database.dart       — Add tables + DAOs, bump schema to v2, migration
packages/dispatch_app/lib/src/core/database/daos.dart           — Add AlfaDecisionsDao, AlfaConversationsDao
packages/dispatch_app/lib/src/features/sidebar/right_panel.dart — Add ALFA tab
packages/dispatch_app/lib/src/features/sidebar/status_bar.dart  — Add Alfa status indicator
packages/dispatch_app/lib/src/app.dart                          — Initialize AlfaOrchestrator
```

---

## Task 1: Alfa Types

**Files:**
- Create: `packages/dispatch_app/lib/src/features/alfa/alfa_types.dart`

- [ ] **Step 1: Create the types file**

```dart
/// Types for Claude API messages and tool use.

enum MessageRole { user, assistant }

class AlfaMessage {
  final MessageRole role;
  final String? text;
  final List<AlfaToolUse>? toolUses;
  final List<AlfaToolResult>? toolResults;

  const AlfaMessage({
    required this.role,
    this.text,
    this.toolUses,
    this.toolResults,
  });

  Map<String, dynamic> toApi() {
    if (toolResults != null && toolResults!.isNotEmpty) {
      return {
        'role': 'user',
        'content': toolResults!.map((r) => r.toApi()).toList(),
      };
    }
    if (toolUses != null && toolUses!.isNotEmpty) {
      final content = <Map<String, dynamic>>[];
      if (text != null) {
        content.add({'type': 'text', 'text': text});
      }
      content.addAll(toolUses!.map((t) => t.toApi()));
      return {'role': 'assistant', 'content': content};
    }
    return {'role': role.name, 'content': text ?? ''};
  }
}

class AlfaToolUse {
  final String id;
  final String name;
  final Map<String, dynamic> input;

  const AlfaToolUse({
    required this.id,
    required this.name,
    required this.input,
  });

  Map<String, dynamic> toApi() => {
        'type': 'tool_use',
        'id': id,
        'name': name,
        'input': input,
      };

  factory AlfaToolUse.fromApi(Map<String, dynamic> json) => AlfaToolUse(
        id: json['id'] as String,
        name: json['name'] as String,
        input: (json['input'] as Map<String, dynamic>?) ?? {},
      );
}

class AlfaToolResult {
  final String toolUseId;
  final String content;
  final bool isError;

  const AlfaToolResult({
    required this.toolUseId,
    required this.content,
    this.isError = false,
  });

  Map<String, dynamic> toApi() => {
        'type': 'tool_result',
        'tool_use_id': toolUseId,
        'content': content,
        if (isError) 'is_error': true,
      };
}

class AlfaToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const AlfaToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  Map<String, dynamic> toApi() => {
        'name': name,
        'description': description,
        'input_schema': inputSchema,
      };
}

enum AlfaStatus { idle, thinking, executing, error }
```

- [ ] **Step 2: Commit**

```bash
git add packages/dispatch_app/lib/src/features/alfa/alfa_types.dart
git commit -m "feat(alfa): add core types for Claude API messages and tool use"
```

---

## Task 2: Claude API Client

**Files:**
- Create: `packages/dispatch_app/lib/src/features/alfa/claude_client.dart`

- [ ] **Step 1: Create the HTTP client**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'alfa_types.dart';

/// HTTP client for Claude Messages API with streaming support.
class ClaudeClient {
  final String apiKey;
  final String model;
  final HttpClient _http = HttpClient();

  static const _baseUrl = 'api.anthropic.com';
  static const _apiVersion = '2023-06-01';

  ClaudeClient({required this.apiKey, this.model = 'claude-sonnet-4-20250514'});

  /// Send a messages request and stream the response.
  ///
  /// Yields text deltas as strings. When tool_use blocks are encountered,
  /// they are collected and returned via [onToolUse] after the stream ends.
  /// Returns the stop reason.
  Future<ClaudeResponse> sendMessage({
    required String systemPrompt,
    required List<AlfaMessage> messages,
    required List<AlfaToolDefinition> tools,
    int maxTokens = 8096,
    void Function(String delta)? onTextDelta,
  }) async {
    final body = jsonEncode({
      'model': model,
      'max_tokens': maxTokens,
      'system': systemPrompt,
      'messages': messages.map((m) => m.toApi()).toList(),
      if (tools.isNotEmpty)
        'tools': tools.map((t) => t.toApi()).toList(),
      'stream': true,
    });

    final request = await _http.postUrl(
      Uri.https(_baseUrl, '/v1/messages'),
    );
    request.headers.set('content-type', 'application/json');
    request.headers.set('x-api-key', apiKey);
    request.headers.set('anthropic-version', _apiVersion);
    request.write(body);

    final response = await request.close();

    if (response.statusCode != 200) {
      final errorBody = await response.transform(utf8.decoder).join();
      throw ClaudeApiError(response.statusCode, errorBody);
    }

    // Parse SSE stream
    final textBuffer = StringBuffer();
    final toolUses = <AlfaToolUse>[];
    String stopReason = 'end_turn';

    // Track tool_use blocks being built
    String? currentToolId;
    String? currentToolName;
    final currentToolInput = StringBuffer();

    await for (final chunk in response.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]' || data.isEmpty) continue;

        Map<String, dynamic> event;
        try {
          event = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        final type = event['type'] as String?;

        if (type == 'content_block_start') {
          final block = event['content_block'] as Map<String, dynamic>?;
          if (block != null && block['type'] == 'tool_use') {
            currentToolId = block['id'] as String;
            currentToolName = block['name'] as String;
            currentToolInput.clear();
          }
        } else if (type == 'content_block_delta') {
          final delta = event['delta'] as Map<String, dynamic>?;
          if (delta != null) {
            if (delta['type'] == 'text_delta') {
              final text = delta['text'] as String? ?? '';
              textBuffer.write(text);
              onTextDelta?.call(text);
            } else if (delta['type'] == 'input_json_delta') {
              currentToolInput.write(delta['partial_json'] ?? '');
            }
          }
        } else if (type == 'content_block_stop') {
          if (currentToolId != null && currentToolName != null) {
            Map<String, dynamic> input = {};
            final inputStr = currentToolInput.toString();
            if (inputStr.isNotEmpty) {
              try {
                input = jsonDecode(inputStr) as Map<String, dynamic>;
              } catch (_) {}
            }
            toolUses.add(AlfaToolUse(
              id: currentToolId!,
              name: currentToolName!,
              input: input,
            ));
            currentToolId = null;
            currentToolName = null;
            currentToolInput.clear();
          }
        } else if (type == 'message_delta') {
          final delta = event['delta'] as Map<String, dynamic>?;
          stopReason = delta?['stop_reason'] as String? ?? stopReason;
        }
      }
    }

    return ClaudeResponse(
      text: textBuffer.toString(),
      toolUses: toolUses,
      stopReason: stopReason,
    );
  }

  void close() => _http.close();
}

class ClaudeResponse {
  final String text;
  final List<AlfaToolUse> toolUses;
  final String stopReason;

  const ClaudeResponse({
    required this.text,
    required this.toolUses,
    required this.stopReason,
  });

  bool get hasToolUse => toolUses.isNotEmpty;
}

class ClaudeApiError implements Exception {
  final int statusCode;
  final String body;
  ClaudeApiError(this.statusCode, this.body);

  @override
  String toString() => 'ClaudeApiError($statusCode): $body';
}
```

- [ ] **Step 2: Commit**

```bash
git add packages/dispatch_app/lib/src/features/alfa/claude_client.dart
git commit -m "feat(alfa): add Claude Messages API HTTP client with streaming"
```

---

## Task 3: Database Schema — Drift Tables, DAOs, Migration

**Files:**
- Modify: `packages/dispatch_app/lib/src/core/database/tables.dart`
- Modify: `packages/dispatch_app/lib/src/core/database/daos.dart`
- Modify: `packages/dispatch_app/lib/src/core/database/database.dart`

- [ ] **Step 0: Add `package:crypto` dependency**

Run: `cd packages/dispatch_app && flutter pub add crypto`

- [ ] **Step 1: Add Alfa tables to tables.dart**

Append after the existing `ProjectGroups` table (after line 56):

```dart
class AlfaDecisions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get projectCwd => text()();
  TextColumn get summary => text()();
  TextColumn get outcome => text()(); // 'success', 'failure', 'partial'
  TextColumn get detail => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class AlfaConversations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get projectCwd => text().nullable()();
  TextColumn get role => text()(); // 'human', 'alfa'
  TextColumn get content => text()();
  TextColumn get toolCalls => text().nullable()(); // JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

- [ ] **Step 2: Add Alfa DAOs to daos.dart**

Append after the existing `TemplatesDao` (after line 157):

```dart
@DriftAccessor(tables: [AlfaDecisions])
class AlfaDecisionsDao extends DatabaseAccessor<AppDatabase>
    with _$AlfaDecisionsDaoMixin {
  AlfaDecisionsDao(super.db);

  Future<List<AlfaDecision>> getForProject(String cwd) {
    return (select(alfaDecisions)
          ..where((d) => d.projectCwd.equals(cwd))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)])
          ..limit(50))
        .get();
  }

  Future<List<AlfaDecision>> search(String query, {String? projectCwd}) {
    final q = select(alfaDecisions)
      ..where((d) =>
          d.summary.like('%$query%') | d.tags.like('%$query%'))
      ..orderBy([(d) => OrderingTerm.desc(d.createdAt)])
      ..limit(20);
    if (projectCwd != null) {
      q.where((d) => d.projectCwd.equals(projectCwd));
    }
    return q.get();
  }

  Future<List<AlfaDecision>> getRecent({int limit = 10}) {
    return (select(alfaDecisions)
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<int> insertDecision(AlfaDecisionsCompanion entry) {
    return into(alfaDecisions).insert(entry);
  }
}

@DriftAccessor(tables: [AlfaConversations])
class AlfaConversationsDao extends DatabaseAccessor<AppDatabase>
    with _$AlfaConversationsDaoMixin {
  AlfaConversationsDao(super.db);

  Future<List<AlfaConversation>> getForProject(String? cwd,
      {int limit = 100}) {
    final q = select(alfaConversations);
    if (cwd != null) {
      q.where((c) => c.projectCwd.equals(cwd));
    }
    q
      ..orderBy([(c) => OrderingTerm.desc(c.createdAt)])
      ..limit(limit);
    return q.get();
  }

  Future<int> insertMessage(AlfaConversationsCompanion entry) {
    return into(alfaConversations).insert(entry);
  }

  Future<void> clearForProject(String? cwd) {
    if (cwd == null) return Future.value();
    return (delete(alfaConversations)
          ..where((c) => c.projectCwd.equals(cwd)))
        .go();
  }
}
```

- [ ] **Step 3: Update database.dart**

Update the `@DriftDatabase` annotation to include new tables and DAOs. Update schema version to 2 and add migration:

```dart
@DriftDatabase(
  tables: [
    Presets, Settings, Notes, Tasks, VaultEntries, Templates, ProjectGroups,
    AlfaDecisions, AlfaConversations,
  ],
  daos: [
    PresetsDao, SettingsDao, NotesDao, TasksDao, VaultDao, TemplatesDao,
    AlfaDecisionsDao, AlfaConversationsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(alfaDecisions);
            await m.createTable(alfaConversations);
          }
        },
      );
}
```

- [ ] **Step 4: Run Drift codegen**

Run: `cd packages/dispatch_app && dart run build_runner build --delete-conflicting-outputs`
Expected: Generates updated `database.g.dart` and `daos.g.dart`

- [ ] **Step 5: Verify build compiles**

Run: `cd packages/dispatch_app && flutter analyze`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add packages/dispatch_app/lib/src/core/database/
git commit -m "feat(alfa): add Drift tables and DAOs for decisions and conversations"
```

---

## Task 4: Tool Executor + Tool Definitions

**Files:**
- Create: `packages/dispatch_app/lib/src/features/alfa/tool_executor.dart`
- Create: `packages/dispatch_app/lib/src/features/alfa/tools/terminal_tools.dart`
- Create: `packages/dispatch_app/lib/src/features/alfa/tools/project_tools.dart`
- Create: `packages/dispatch_app/lib/src/features/alfa/tools/knowledge_tools.dart`
- Create: `packages/dispatch_app/lib/src/features/alfa/tools/filesystem_tools.dart`
- Create: `packages/dispatch_app/lib/src/features/alfa/tools/memory_tools.dart`

- [ ] **Step 1: Create tool executor**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alfa_types.dart';

/// Handler signature for Alfa tools.
typedef AlfaToolHandler = Future<Map<String, dynamic>> Function(
  Ref ref,
  Map<String, dynamic> params,
);

/// Registered tool with schema and handler.
class AlfaToolEntry {
  final AlfaToolDefinition definition;
  final AlfaToolHandler handler;
  final Duration timeout;

  const AlfaToolEntry({
    required this.definition,
    required this.handler,
    this.timeout = const Duration(seconds: 5),
  });
}

/// Registry and executor for all Alfa tools.
class ToolExecutor {
  final Ref ref;
  final Map<String, AlfaToolEntry> _tools = {};

  ToolExecutor(this.ref);

  void register(AlfaToolEntry entry) {
    _tools[entry.definition.name] = entry;
  }

  void registerAll(List<AlfaToolEntry> entries) {
    for (final entry in entries) {
      _tools[entry.definition.name] = entry;
    }
  }

  List<AlfaToolDefinition> get definitions =>
      _tools.values.map((e) => e.definition).toList();

  /// Execute a tool call with timeout. Returns a tool result.
  Future<AlfaToolResult> execute(AlfaToolUse toolUse) async {
    final entry = _tools[toolUse.name];
    if (entry == null) {
      return AlfaToolResult(
        toolUseId: toolUse.id,
        content: 'Unknown tool: ${toolUse.name}',
        isError: true,
      );
    }

    try {
      final result = await entry.handler(ref, toolUse.input)
          .timeout(entry.timeout);
      return AlfaToolResult(
        toolUseId: toolUse.id,
        content: _encodeResult(result),
      );
    } on TimeoutException {
      return AlfaToolResult(
        toolUseId: toolUse.id,
        content: 'Tool ${toolUse.name} timed out after ${entry.timeout.inSeconds}s',
        isError: true,
      );
    } catch (e) {
      return AlfaToolResult(
        toolUseId: toolUse.id,
        content: 'Error: $e',
        isError: true,
      );
    }
  }

  /// Execute multiple tool calls concurrently.
  Future<List<AlfaToolResult>> executeAll(List<AlfaToolUse> toolUses) {
    return Future.wait(toolUses.map(execute));
  }

  String _encodeResult(Map<String, dynamic> result) {
    try {
      return const JsonEncoder.withIndent(null).convert(result);
    } catch (_) {
      return result.toString();
    }
  }
}
```

- [ ] **Step 2: Create terminal tools**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alfa_types.dart';
import '../tool_executor.dart';
import '../../terminal/terminal_provider.dart';
import '../../terminal/session_registry.dart';
import '../../projects/projects_provider.dart';
import '../../../core/models/terminal_entry.dart';

List<AlfaToolEntry> terminalTools() => [
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'spawn_terminal',
          description:
              'Spawns a new terminal with a command in a project group. Returns the terminal ID.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'project_id': {'type': 'string', 'description': 'Project group ID'},
              'command': {'type': 'string', 'description': 'Command to run'},
              'cwd': {'type': 'string', 'description': 'Working directory'},
              'label': {'type': 'string', 'description': 'Optional label for the terminal'},
            },
            'required': ['project_id', 'command', 'cwd'],
          },
        ),
        handler: _spawnTerminal,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'write_to_terminal',
          description:
              'Sends raw bytes to a terminal PTY without appending a newline. Use for control sequences like Ctrl-C.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'terminal_id': {'type': 'string'},
              'data': {'type': 'string', 'description': 'Raw text to send'},
            },
            'required': ['terminal_id', 'data'],
          },
        ),
        handler: _writeToTerminal,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'run_command',
          description:
              'Sends a command to a terminal followed by Enter (carriage return). Use for typing prompts to AI coding agents.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'terminal_id': {'type': 'string'},
              'command': {'type': 'string', 'description': 'Command to type'},
            },
            'required': ['terminal_id', 'command'],
          },
        ),
        handler: _runCommand,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'read_terminal',
          description:
              'Returns the last N lines from a terminal output buffer. Includes ANSI codes.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'terminal_id': {'type': 'string'},
              'lines': {'type': 'integer', 'description': 'Number of lines (default 100)'},
            },
            'required': ['terminal_id'],
          },
        ),
        handler: _readTerminal,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'kill_terminal',
          description: 'Kills a terminal process.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'terminal_id': {'type': 'string'},
            },
            'required': ['terminal_id'],
          },
        ),
        handler: _killTerminal,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'list_terminals',
          description:
              'Lists all terminals with their ID, label, status, project, cwd, and last activity.',
          inputSchema: {
            'type': 'object',
            'properties': {},
          },
        ),
        handler: _listTerminals,
      ),
    ];

Future<Map<String, dynamic>> _spawnTerminal(
    Ref ref, Map<String, dynamic> params) async {
  final projectId = params['project_id'] as String;
  final command = params['command'] as String;
  final cwd = params['cwd'] as String;
  final label = params['label'] as String?;

  final id = 'term-${DateTime.now().millisecondsSinceEpoch}-alfa';

  await Future.delayed(Duration.zero);
  ref.read(terminalsProvider.notifier).addTerminal(
        projectId,
        TerminalEntry(
          id: id,
          command: command,
          cwd: cwd,
          status: TerminalStatus.running,
          label: label,
        ),
      );

  return {'terminal_id': id};
}

Future<Map<String, dynamic>> _writeToTerminal(
    Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminal_id'] as String;
  final data = params['data'] as String;

  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty == null) return {'error': 'Terminal not found or not running'};

  pty.write(const Utf8Encoder().convert(data));
  return {'success': true};
}

Future<Map<String, dynamic>> _runCommand(
    Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminal_id'] as String;
  final command = params['command'] as String;

  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty == null) return {'error': 'Terminal not found or not running'};

  pty.write(const Utf8Encoder().convert('$command\r'));
  return {'success': true};
}

Future<Map<String, dynamic>> _readTerminal(
    Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminal_id'] as String;
  final lines = (params['lines'] as int?) ?? 100;

  final output =
      ref.read(sessionRegistryProvider.notifier).readOutput(terminalId, lines: lines);

  return {'output': output};
}

Future<Map<String, dynamic>> _killTerminal(
    Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminal_id'] as String;

  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty == null) return {'error': 'Terminal not found'};

  pty.kill();
  return {'success': true};
}

Future<Map<String, dynamic>> _listTerminals(
    Ref ref, Map<String, dynamic> params) async {
  final terminals = ref.read(terminalsProvider).terminals;
  final registry = ref.read(sessionRegistryProvider.notifier);

  final list = terminals.values.map((t) {
    final meta = registry.getMeta(t.id);
    return {
      'id': t.id,
      'command': t.command,
      'cwd': t.cwd,
      'status': t.status.name,
      if (t.label != null) 'label': t.label,
      if (t.exitCode != null) 'exit_code': t.exitCode,
      if (meta != null) 'idle_ms': meta.idleDurationMs,
      if (meta != null) 'activity': meta.activityStatus,
      'is_alfa': t.id.endsWith('-alfa'),
    };
  }).toList();

  return {'terminals': list, 'count': list.length};
}
```

- [ ] **Step 3: Create project tools**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alfa_types.dart';
import '../tool_executor.dart';
import '../../projects/projects_provider.dart';
import '../../terminal/terminal_provider.dart';
import '../../terminal/session_registry.dart';

List<AlfaToolEntry> projectTools() => [
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'create_project',
          description:
              'Creates a new project group. Idempotent: returns existing group if one with the same cwd exists.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'label': {'type': 'string'},
              'cwd': {'type': 'string'},
            },
            'required': ['label', 'cwd'],
          },
        ),
        handler: _createProject,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'close_project',
          description: 'Closes a project group and kills all its terminals.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'project_id': {'type': 'string'},
            },
            'required': ['project_id'],
          },
        ),
        handler: _closeProject,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'list_projects',
          description: 'Lists all project groups with terminal counts and CWDs.',
          inputSchema: {
            'type': 'object',
            'properties': {},
          },
        ),
        handler: _listProjects,
      ),
    ];

Future<Map<String, dynamic>> _createProject(
    Ref ref, Map<String, dynamic> params) async {
  final label = params['label'] as String;
  final cwd = params['cwd'] as String;

  // Idempotent: check if a group with this cwd already exists
  final state = ref.read(projectsProvider);
  final existing = state.groups.where((g) => g.cwd == cwd).firstOrNull;
  if (existing != null) {
    return {'project_id': existing.id, 'existing': true};
  }

  await Future.delayed(Duration.zero);
  final before = ref.read(projectsProvider).groups.map((g) => g.id).toSet();
  ref.read(projectsProvider.notifier).addGroup(cwd, label);
  final after = ref.read(projectsProvider).groups;
  final newGroup = after.where((g) => !before.contains(g.id)).firstOrNull;

  return {'project_id': newGroup?.id ?? '', 'existing': false};
}

Future<Map<String, dynamic>> _closeProject(
    Ref ref, Map<String, dynamic> params) async {
  final projectId = params['project_id'] as String;

  final state = ref.read(projectsProvider);
  final group = state.groups.where((g) => g.id == projectId).firstOrNull;
  if (group == null) return {'error': 'Project not found'};

  for (final terminalId in [...group.terminalIds]) {
    final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
    pty?.kill();
  }

  await Future.delayed(Duration.zero);
  for (final terminalId in group.terminalIds) {
    ref.read(terminalsProvider.notifier).removeTerminal(terminalId);
  }
  ref.read(projectsProvider.notifier).removeGroup(projectId);

  return {'success': true};
}

Future<Map<String, dynamic>> _listProjects(
    Ref ref, Map<String, dynamic> params) async {
  final state = ref.read(projectsProvider);
  final list = state.groups.map((g) => {
        'id': g.id,
        'label': g.label,
        'cwd': g.cwd,
        'terminal_count': g.terminalIds.length,
        'is_active': g.id == state.activeGroupId,
      }).toList();

  return {'projects': list, 'count': list.length};
}
```

- [ ] **Step 4: Create knowledge tools**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alfa_types.dart';
import '../tool_executor.dart';

List<AlfaToolEntry> knowledgeTools() => [
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'read_project_knowledge',
          description:
              'Reads the project knowledge markdown file. Returns empty string if none exists yet.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'cwd': {'type': 'string'},
            },
            'required': ['cwd'],
          },
        ),
        handler: _readKnowledge,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'update_project_knowledge',
          description:
              'Overwrites the project knowledge file. You manage the full content — preserve what matters, add new learnings.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'cwd': {'type': 'string'},
              'content': {'type': 'string', 'description': 'Full markdown content'},
            },
            'required': ['cwd', 'content'],
          },
        ),
        handler: _updateKnowledge,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'scan_project',
          description:
              'Quick filesystem scan of a project directory. Detects language, framework, build files, entry points, test commands.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'cwd': {'type': 'string'},
            },
            'required': ['cwd'],
          },
        ),
        handler: _scanProject,
        timeout: const Duration(seconds: 10),
      ),
    ];

String _knowledgePath(String cwd) {
  final hash = sha256.convert(utf8.encode(cwd)).toString();
  final home = Platform.environment['HOME'] ?? '/tmp';
  return '$home/.config/dispatch/alfa/projects/$hash/knowledge.md';
}

Future<Map<String, dynamic>> _readKnowledge(
    Ref ref, Map<String, dynamic> params) async {
  final cwd = params['cwd'] as String;
  if (cwd.isEmpty) return {'error': 'cwd is required'};

  final file = File(_knowledgePath(cwd));
  if (!await file.exists()) return {'content': '', 'exists': false};

  final content = await file.readAsString();
  return {'content': content, 'exists': true};
}

Future<Map<String, dynamic>> _updateKnowledge(
    Ref ref, Map<String, dynamic> params) async {
  final cwd = params['cwd'] as String;
  final content = params['content'] as String;
  if (cwd.isEmpty) return {'error': 'cwd is required'};

  final file = File(_knowledgePath(cwd));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);

  return {'success': true, 'path': file.path};
}

Future<Map<String, dynamic>> _scanProject(
    Ref ref, Map<String, dynamic> params) async {
  final cwd = params['cwd'] as String;
  final dir = Directory(cwd);
  if (!await dir.exists()) return {'error': 'Directory does not exist'};

  final result = <String, dynamic>{
    'cwd': cwd,
    'name': cwd.split('/').last,
  };

  // Detect key files
  final markers = <String, String>{
    'pubspec.yaml': 'dart/flutter',
    'package.json': 'node',
    'Cargo.toml': 'rust',
    'go.mod': 'go',
    'pyproject.toml': 'python',
    'requirements.txt': 'python',
    'Gemfile': 'ruby',
    'pom.xml': 'java/maven',
    'build.gradle': 'java/gradle',
    'CMakeLists.txt': 'c/cpp',
    'Makefile': 'make',
    'melos.yaml': 'melos-monorepo',
  };

  final detected = <String>[];
  final buildFiles = <String>[];

  await for (final entity in dir.list()) {
    final name = entity.path.split('/').last;
    if (markers.containsKey(name)) {
      detected.add(markers[name]!);
      buildFiles.add(name);
    }
  }

  result['detected_stacks'] = detected;
  result['build_files'] = buildFiles;

  // Check for common directories
  final commonDirs = ['src', 'lib', 'test', 'tests', 'packages', 'apps'];
  final foundDirs = <String>[];
  for (final d in commonDirs) {
    if (await Directory('$cwd/$d').exists()) foundDirs.add(d);
  }
  result['directories'] = foundDirs;

  // Check for git
  result['has_git'] = await Directory('$cwd/.git').exists();

  return result;
}
```

- [ ] **Step 5: Create filesystem tools**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alfa_types.dart';
import '../tool_executor.dart';

List<AlfaToolEntry> filesystemTools() => [
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'read_file',
          description: 'Reads a file contents. Path must be within a known project CWD.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'path': {'type': 'string'},
            },
            'required': ['path'],
          },
        ),
        handler: _readFile,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'list_directory',
          description: 'Lists directory contents.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'path': {'type': 'string'},
              'recursive': {'type': 'boolean', 'description': 'List recursively (default false)'},
            },
            'required': ['path'],
          },
        ),
        handler: _listDirectory,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'run_shell_command',
          description:
              'Runs a shell command and returns stdout/stderr. 30-second default timeout. For quick operations only — use spawn_terminal for long-running processes.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'command': {'type': 'string'},
              'cwd': {'type': 'string'},
              'timeout_seconds': {'type': 'integer', 'description': 'Timeout in seconds (default 30)'},
            },
            'required': ['command', 'cwd'],
          },
        ),
        handler: _runShellCommand,
        timeout: const Duration(seconds: 35), // slightly above max to let Process.run handle it
      ),
    ];

Future<Map<String, dynamic>> _readFile(
    Ref ref, Map<String, dynamic> params) async {
  final path = params['path'] as String;
  final file = File(path);

  if (!await file.exists()) return {'error': 'File not found: $path'};

  final stat = await file.stat();
  if (stat.size > 1024 * 1024) {
    return {'error': 'File too large (${stat.size} bytes). Max 1MB.'};
  }

  final content = await file.readAsString();
  return {'content': content, 'size': stat.size};
}

Future<Map<String, dynamic>> _listDirectory(
    Ref ref, Map<String, dynamic> params) async {
  final path = params['path'] as String;
  final recursive = (params['recursive'] as bool?) ?? false;

  final dir = Directory(path);
  if (!await dir.exists()) return {'error': 'Directory not found: $path'};

  final entries = <Map<String, dynamic>>[];
  await for (final entity in dir.list(recursive: recursive)) {
    if (entries.length >= 500) break; // cap output
    final name = entity.path.substring(path.length).replaceFirst(RegExp(r'^/'), '');
    if (name.startsWith('.')) continue; // skip hidden
    entries.add({
      'name': name,
      'type': entity is Directory ? 'directory' : 'file',
    });
  }

  return {'entries': entries, 'count': entries.length, 'truncated': entries.length >= 500};
}

Future<Map<String, dynamic>> _runShellCommand(
    Ref ref, Map<String, dynamic> params) async {
  final command = params['command'] as String;
  final cwd = params['cwd'] as String;
  final timeoutSeconds = (params['timeout_seconds'] as int?) ?? 30;

  final result = await Process.run(
    '/bin/sh',
    ['-c', command],
    workingDirectory: cwd,
    environment: Platform.environment,
  ).timeout(Duration(seconds: timeoutSeconds));

  return {
    'stdout': (result.stdout as String).length > 10000
        ? (result.stdout as String).substring(0, 10000) + '\n[truncated]'
        : result.stdout,
    'stderr': (result.stderr as String).length > 5000
        ? (result.stderr as String).substring(0, 5000) + '\n[truncated]'
        : result.stderr,
    'exit_code': result.exitCode,
  };
}
```

- [ ] **Step 6: Create memory tools**

```dart
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alfa_types.dart';
import '../tool_executor.dart';
import '../../../persistence/auto_save.dart';
import '../../../core/database/tables.dart';

List<AlfaToolEntry> memoryTools() => [
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'save_decision',
          description:
              'Logs a decision to the database for future reference. Record what you did, whether it worked, and relevant tags.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'project_cwd': {'type': 'string'},
              'summary': {'type': 'string', 'description': 'What was decided/done'},
              'outcome': {
                'type': 'string',
                'enum': ['success', 'failure', 'partial'],
              },
              'detail': {'type': 'string', 'description': 'Optional longer explanation'},
              'tags': {
                'type': 'array',
                'items': {'type': 'string'},
                'description': 'Categorization tags',
              },
            },
            'required': ['project_cwd', 'summary', 'outcome'],
          },
        ),
        handler: _saveDecision,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'search_decisions',
          description: 'Searches past decisions by text or tags.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'query': {'type': 'string'},
              'project_cwd': {'type': 'string', 'description': 'Optional: filter to specific project'},
            },
            'required': ['query'],
          },
        ),
        handler: _searchDecisions,
      ),
    ];

Future<Map<String, dynamic>> _saveDecision(
    Ref ref, Map<String, dynamic> params) async {
  final db = ref.read(databaseProvider);
  final tags = (params['tags'] as List<dynamic>?)?.cast<String>() ?? [];

  final id = await db.alfaDecisionsDao.insertDecision(
    AlfaDecisionsCompanion.insert(
      projectCwd: params['project_cwd'] as String,
      summary: params['summary'] as String,
      outcome: params['outcome'] as String,
      detail: Value(params['detail'] as String?),
      tags: Value(tags.join(',')),
    ),
  );

  return {'id': id};
}

Future<Map<String, dynamic>> _searchDecisions(
    Ref ref, Map<String, dynamic> params) async {
  final db = ref.read(databaseProvider);
  final query = params['query'] as String;
  final projectCwd = params['project_cwd'] as String?;

  final results = await db.alfaDecisionsDao.search(query, projectCwd: projectCwd);

  return {
    'decisions': results
        .map((d) => {
              'id': d.id,
              'summary': d.summary,
              'outcome': d.outcome,
              'detail': d.detail,
              'tags': d.tags,
              'project_cwd': d.projectCwd,
              'created_at': d.createdAt.toIso8601String(),
            })
        .toList(),
    'count': results.length,
  };
}
```

- [ ] **Step 7: Commit**

```bash
git add packages/dispatch_app/lib/src/features/alfa/tool_executor.dart
git add packages/dispatch_app/lib/src/features/alfa/tools/
git commit -m "feat(alfa): add tool executor and 17 tool definitions"
```

---

## Task 5: Alfa Orchestrator — Core Agentic Loop

**Files:**
- Create: `packages/dispatch_app/lib/src/features/alfa/alfa_orchestrator.dart`

- [ ] **Step 1: Create the orchestrator**

```dart
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
import '../../core/database/tables.dart';

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
    final model = await db.settingsDao.getValue('alfa.model') ?? 'claude-sonnet-4-20250514';
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
        // Warn about approaching limit
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
        // Add assistant message with text + tool_use
        messages.add(AlfaMessage(
          role: MessageRole.assistant,
          text: response.text.isNotEmpty ? response.text : null,
          toolUses: response.toolUses,
        ));

        // Execute tools concurrently
        _setStatus(AlfaStatus.executing);
        final results = await _tools.executeAll(response.toolUses);

        // Emit tool execution events
        for (var i = 0; i < response.toolUses.length; i++) {
          _emit(AlfaChatEvent.toolCall(
            response.toolUses[i].name,
            response.toolUses[i].input,
            results[i].content,
            results[i].isError,
          ));
        }

        // Add tool results as user message
        messages.add(AlfaMessage(
          role: MessageRole.user,
          toolResults: results,
        ));

        continue; // Loop: send results back to Claude
      }

      // No tool use — final text response
      if (response.text.isNotEmpty) {
        // Save to DB
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

      break; // End of conversation
    }

    if (_turnCount >= _maxTurns) {
      _emit(AlfaChatEvent.alfa('[Reached $_maxTurns turn limit. Stopping.]'));
    }
  }

  Future<String> _buildSystemPrompt(String? activeCwd) async {
    final parts = <String>[
      _identityPrompt,
    ];

    // Project knowledge
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

    // Recent decisions
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
You are Alfa, the orchestrator agent for Dispatch. You manage coding projects by controlling terminals that run AI coding tools (Claude Code, Codex, Gemini CLI).

You have full autonomy to spawn terminals, delegate tasks, monitor progress, and make decisions. No confirmation needed.

You think strategically: break work into parallel tasks when possible, choose the right approach for each sub-task, and monitor outcomes. When something fails, you diagnose and retry with a different approach.

You communicate concisely with the human. Lead with actions and results, not plans and reasoning — unless asked.

You maintain project knowledge files that grow smarter over time. Update them when you learn something non-obvious about a project.

When working with a new project, use scan_project first, then update_project_knowledge with your findings.

Terminal IDs ending in "-alfa" were spawned by you. Use read_terminal to check their output and run_command to send them instructions.
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
```

- [ ] **Step 2: Commit**

```bash
git add packages/dispatch_app/lib/src/features/alfa/alfa_orchestrator.dart
git commit -m "feat(alfa): add core orchestrator with agentic tool-use loop"
```

---

## Task 6: Alfa Provider (Riverpod)

**Files:**
- Create: `packages/dispatch_app/lib/src/features/alfa/alfa_provider.dart`

- [ ] **Step 1: Create the provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alfa_orchestrator.dart';
import 'alfa_types.dart';

class AlfaState {
  final AlfaStatus status;
  final List<AlfaChatEvent> messages;
  final bool configured;

  const AlfaState({
    this.status = AlfaStatus.idle,
    this.messages = const [],
    this.configured = false,
  });

  AlfaState copyWith({
    AlfaStatus? status,
    List<AlfaChatEvent>? messages,
    bool? configured,
  }) {
    return AlfaState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      configured: configured ?? this.configured,
    );
  }
}

class AlfaNotifier extends Notifier<AlfaState> {
  AlfaOrchestrator? _orchestrator;

  @override
  AlfaState build() {
    ref.onDispose(() => _orchestrator?.dispose());
    return const AlfaState();
  }

  Future<void> initialize() async {
    _orchestrator = AlfaOrchestrator(ref);
    await _orchestrator!.initialize();

    final configured = _orchestrator!.status != AlfaStatus.error;

    _orchestrator!.statusStream.listen((s) {
      state = state.copyWith(status: s);
    });

    _orchestrator!.messageStream.listen((event) {
      state = state.copyWith(
        messages: [...state.messages, event],
      );
    });

    state = state.copyWith(configured: configured);
  }

  Future<void> sendMessage(String text) async {
    if (_orchestrator == null) return;
    await _orchestrator!.sendMessage(text);
  }

  void clearMessages() {
    state = state.copyWith(messages: []);
  }
}

final alfaProvider =
    NotifierProvider<AlfaNotifier, AlfaState>(AlfaNotifier.new);
```

- [ ] **Step 2: Commit**

```bash
git add packages/dispatch_app/lib/src/features/alfa/alfa_provider.dart
git commit -m "feat(alfa): add Riverpod provider and state management"
```

---

## Task 7: Alfa Chat Panel (UI)

**Files:**
- Create: `packages/dispatch_app/lib/src/features/alfa/alfa_panel.dart`

- [ ] **Step 1: Create the chat panel widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alfa_orchestrator.dart';
import 'alfa_provider.dart';
import 'alfa_types.dart';
import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';

class AlfaPanel extends ConsumerStatefulWidget {
  const AlfaPanel({super.key});

  @override
  ConsumerState<AlfaPanel> createState() => _AlfaPanelState();
}

class _AlfaPanelState extends ConsumerState<AlfaPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  String _streamingText = '';

  @override
  void initState() {
    super.initState();
    ref.listenManual(alfaProvider, (prev, next) {
      // Auto-scroll on new messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });

      // Track streaming text
      if (next.messages.isNotEmpty) {
        final last = next.messages.last;
        if (last is AlfaDeltaEvent) {
          setState(() => _streamingText += last.text);
        } else if (last is AlfaDoneEvent || last is AlfaMessageEvent) {
          setState(() => _streamingText = '');
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    _streamingText = '';
    ref.read(alfaProvider.notifier).sendMessage(text);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alfaProvider);
    final theme = ref.watch(appThemeProvider);

    return Column(
      children: [
        // Header
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(bottom: BorderSide(color: theme.border)),
          ),
          child: Row(
            children: [
              _StatusDot(status: state.status, theme: theme),
              const SizedBox(width: 8),
              Text('ALFA', style: TextStyle(
                color: theme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              )),
              const Spacer(),
              if (state.status != AlfaStatus.idle)
                SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: theme.accentBlue,
                  ),
                ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: _buildDisplayItems(state.messages).length +
                (_streamingText.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              final items = _buildDisplayItems(state.messages);
              if (index == items.length && _streamingText.isNotEmpty) {
                return _MessageBubble(
                  role: 'alfa',
                  text: _streamingText,
                  theme: theme,
                );
              }
              if (index >= items.length) return const SizedBox.shrink();
              return items[index];
            },
          ),
        ),

        // Input
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(top: BorderSide(color: theme.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: TextStyle(color: theme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: state.configured
                        ? 'Talk to Alfa...'
                        : 'Set alfa.api_key in settings first',
                    hintStyle: TextStyle(color: theme.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: theme.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  enabled: state.configured,
                  onSubmitted: (_) => _send(),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send, size: 18, color: theme.accentBlue),
                onPressed: state.status == AlfaStatus.idle && state.configured
                    ? _send
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDisplayItems(List<AlfaChatEvent> events) {
    final widgets = <Widget>[];
    final theme = ref.read(appThemeProvider);

    for (final event in events) {
      switch (event) {
        case HumanMessageEvent(:final text):
          widgets.add(_MessageBubble(role: 'human', text: text, theme: theme));
        case AlfaMessageEvent(:final text):
          widgets.add(_MessageBubble(role: 'alfa', text: text, theme: theme));
        case AlfaDoneEvent(:final text):
          widgets.add(_MessageBubble(role: 'alfa', text: text, theme: theme));
        case ToolCallEvent(:final name, :final isError):
          widgets.add(_ToolCallCard(name: name, isError: isError, theme: theme));
        case AlfaDeltaEvent():
          break; // Handled by streaming buffer
      }
    }
    return widgets;
  }
}

class _StatusDot extends StatelessWidget {
  final AlfaStatus status;
  final AppTheme theme;

  const _StatusDot({required this.status, required this.theme});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AlfaStatus.idle => Colors.grey,
      AlfaStatus.thinking => Colors.blue,
      AlfaStatus.executing => Colors.orange,
      AlfaStatus.error => Colors.red,
    };
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String role;
  final String text;
  final AppTheme theme;

  const _MessageBubble({required this.role, required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isHuman = role == 'human';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isHuman ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isHuman ? theme.accentBlue.withValues(alpha: 0.15) : theme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.border),
          ),
          child: SelectableText(
            text,
            style: TextStyle(color: theme.textPrimary, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _ToolCallCard extends StatelessWidget {
  final String name;
  final bool isError;
  final AppTheme theme;

  const _ToolCallCard({required this.name, required this.isError, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 14,
            color: isError ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 11,
              fontFamily: 'JetBrains Mono',
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add packages/dispatch_app/lib/src/features/alfa/alfa_panel.dart
git commit -m "feat(alfa): add chat panel UI with message display and streaming"
```

---

## Task 8: Integrate Alfa into Dispatch App

**Files:**
- Modify: `packages/dispatch_app/lib/src/features/sidebar/right_panel.dart`
- Modify: `packages/dispatch_app/lib/src/features/sidebar/status_bar.dart`
- Modify: `packages/dispatch_app/lib/src/app.dart`

- [ ] **Step 1: Add ALFA tab to right_panel.dart**

Add import at the top of `right_panel.dart`:

```dart
import '../alfa/alfa_panel.dart';
```

In `_RightPanelState`, change `_tab` initial value and add 'alfa' option. Replace the `_tab` field (line ~22):

```dart
String _tab = 'alfa';
```

Add the ALFA tab header alongside the existing FILES and PROJECT tabs in the tab row. In the expanded panel body, add a case for 'alfa' that renders `const AlfaPanel()`.

The exact edits depend on the widget structure — add a third `_PanelTab` for 'ALFA' and a conditional body:

```dart
// In the tab row, add:
_PanelTab(
  label: 'ALFA',
  active: _tab == 'alfa',
  onTap: () => setState(() => _tab = 'alfa'),
  theme: theme,
),

// In the body switch, add:
if (_tab == 'alfa') const AlfaPanel(),
```

- [ ] **Step 2: Add Alfa status dot to status_bar.dart**

Add import at the top:

```dart
import '../alfa/alfa_provider.dart';
import '../alfa/alfa_types.dart';
```

In the `build` method, watch `alfaProvider` and add a small status indicator next to the terminal count:

```dart
final alfaState = ref.watch(alfaProvider);

// Add after the terminal count text:
const SizedBox(width: 8),
Container(
  width: 6, height: 6,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: switch (alfaState.status) {
      AlfaStatus.idle => Colors.grey,
      AlfaStatus.thinking => Colors.blue,
      AlfaStatus.executing => Colors.orange,
      AlfaStatus.error => Colors.red,
    },
  ),
),
const SizedBox(width: 4),
Text('A', style: TextStyle(color: Color(0xFF6B6B8D), fontSize: 10)),
```

- [ ] **Step 3: Initialize Alfa in app.dart**

Add import at the top of `app.dart`:

```dart
import 'features/alfa/alfa_provider.dart';
```

In `_DispatchAppState.initState()`, after the existing provider reads (around line 55), add:

```dart
ref.read(alfaProvider.notifier).initialize();
```

- [ ] **Step 4: Add terminal badge for Alfa-spawned terminals**

In `packages/dispatch_app/lib/src/features/sidebar/terminal_list.dart`, find where terminal labels are rendered and add a small "A" badge when the terminal ID ends with `-alfa`:

```dart
if (terminal.id.endsWith('-alfa'))
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
    decoration: BoxDecoration(
      color: Colors.blue.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(3),
    ),
    child: const Text('A', style: TextStyle(fontSize: 9, color: Colors.blue)),
  ),
```

- [ ] **Step 5: Verify build**

Run: `cd packages/dispatch_app && flutter analyze`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add packages/dispatch_app/lib/src/features/sidebar/right_panel.dart
git add packages/dispatch_app/lib/src/features/sidebar/status_bar.dart
git add packages/dispatch_app/lib/src/features/sidebar/terminal_list.dart
git add packages/dispatch_app/lib/src/app.dart
git commit -m "feat(alfa): integrate orchestrator into Dispatch UI"
```

---

## Task 9: End-to-End Verification

- [ ] **Step 1: Set API key in database**

Use the app's settings or manually insert:

Run: `cd packages/dispatch_app && flutter run -d macos`

In the app, verify:
1. Right panel shows ALFA tab
2. Status bar shows Alfa status dot
3. Chat panel displays "Set alfa.api_key in settings first" when no key is set

- [ ] **Step 2: Test with API key**

Set `alfa.api_key` in settings, restart app. Send a message like "scan this project and tell me what you see". Verify:
1. Alfa streams a response
2. Tool calls show as cards in the chat
3. Terminal can be spawned by Alfa
4. Status dot changes during execution

**Known omission:** Knowledge file size management (~4000 token cap with archiving) is deferred to a follow-up task. Alfa's system prompt instruction to keep files lean provides soft enforcement for now.

- [ ] **Step 3: Commit any fixes**

```bash
git add -u
git commit -m "fix(alfa): end-to-end verification fixes"
```
