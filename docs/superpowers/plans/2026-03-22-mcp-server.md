# MCP Server Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a built-in MCP server to Dispatch so AI coding agents can remotely observe, control, and orchestrate terminal sessions and projects.

**Architecture:** Dart-native MCP server using `shelf` for HTTP/SSE and `json_rpc_2` for JSON-RPC 2.0. The server lives inside `dispatch_app` as a feature module, accessing Riverpod state directly via `ref`. A `McpServerNotifier` manages lifecycle; an Integrations panel provides the UI.

**Tech Stack:** Dart, shelf, shelf_router, json_rpc_2, flutter_riverpod, drift

**Spec:** `docs/superpowers/specs/2026-03-22-mcp-server-design.md`

---

## File Map

### New Files
| File | Responsibility |
|---|---|
| `lib/src/features/mcp/mcp_provider.dart` | `McpServerNotifier extends Notifier<McpServerState>` — lifecycle, settings, state |
| `lib/src/features/mcp/mcp_server.dart` | shelf HTTP server, SSE stream management, JSON-RPC routing |
| `lib/src/features/mcp/mcp_protocol.dart` | JSON-RPC 2.0 message types, request parsing, response formatting |
| `lib/src/features/mcp/mcp_tools.dart` | Tool registry — maps tool names to handler functions |
| `lib/src/features/mcp/tools/observe_tools.dart` | list_projects, get_active_project, list_terminals, read_terminal, get_terminal_status |
| `lib/src/features/mcp/tools/act_tools.dart` | run_command, spawn_terminal, kill_terminal, write_to_terminal |
| `lib/src/features/mcp/tools/orchestrate_tools.dart` | create_project, close_project, set_active_project, set_active_terminal, split_terminal |
| `lib/src/features/mcp/mcp_notifications.dart` | Riverpod listeners → SSE notification push |
| `lib/src/features/mcp/mcp_panel.dart` | Integrations overlay panel UI |
| `bin/dispatch_mcp_stdio.dart` | stdio bridge process for Claude Code |

### Modified Files
| File | Changes |
|---|---|
| `pubspec.yaml` | Add shelf, shelf_router, json_rpc_2 dependencies |
| `session_registry.dart` | New state type with output accumulator + meta; new methods |
| `terminal_monitor.dart` | Add `onMetaUpdate` callback parameter |
| `terminal_pane.dart` | Feed output to SessionRegistry; wire meta callback |
| `tab_bar.dart` | Add `onOpenIntegrations` callback, status dot |
| `app.dart` | Add `_integrationsOpen` state, wire panel overlay |
| `main.dart` | Auto-start MCP server if enabled |

All paths below are relative to `packages/dispatch_app/`.

---

### Task 1: Add Dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add shelf, shelf_router, and json_rpc_2 to pubspec.yaml**

```yaml
# Add under dependencies: after webview_flutter_wkwebview
  shelf: ^1.4.0
  shelf_router: ^1.1.0
  json_rpc_2: ^3.0.0
```

- [ ] **Step 2: Run pub get**

Run: `cd packages/dispatch_app && flutter pub get`
Expected: "Got dependencies!" with no errors

- [ ] **Step 3: Commit**

```bash
git add packages/dispatch_app/pubspec.yaml packages/dispatch_app/pubspec.lock
git commit -m "deps: add shelf, shelf_router, json_rpc_2 for MCP server"
```

---

### Task 2: Extend SessionRegistry with Output Accumulator and Meta

**Files:**
- Modify: `lib/src/features/terminal/session_registry.dart`

The current `SessionRegistry` maps `String → PtySession`. We need to extend it with a per-terminal output accumulator (`Queue<String>`) and a `TerminalSessionMeta` record for idle/status tracking.

- [ ] **Step 1: Create the new state types and extend SessionRegistry**

Replace the entire file content with:

```dart
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:dispatch_terminal/dispatch_terminal.dart';

/// Metadata about a terminal session, updated by TerminalMonitor via callback.
class TerminalSessionMeta {
  final DateTime? lastActivityTime;
  final String? activityStatus; // 'idle', 'running', 'success', 'error'

  const TerminalSessionMeta({this.lastActivityTime, this.activityStatus});

  int? get idleDurationMs {
    if (lastActivityTime == null || activityStatus != 'idle') return null;
    return DateTime.now().difference(lastActivityTime!).inMilliseconds;
  }
}

/// All data associated with a terminal session.
class TerminalSessionRecord {
  final PtySession session;
  final Pty? pty;
  final Queue<String> outputBuffer;
  final TerminalSessionMeta meta;

  TerminalSessionRecord({
    required this.session,
    this.pty,
    Queue<String>? outputBuffer,
    this.meta = const TerminalSessionMeta(),
  }) : outputBuffer = outputBuffer ?? Queue<String>();
}

/// Global registry of active PTY sessions, keyed by terminal ID.
/// Holds PTY sessions, rolling output buffers, and activity metadata.
class SessionRegistry extends Notifier<Map<String, TerminalSessionRecord>> {
  static const int maxOutputLines = 10000;

  @override
  Map<String, TerminalSessionRecord> build() => {};

  void register(String terminalId, PtySession session, {Pty? pty}) {
    state = {
      ...state,
      terminalId: TerminalSessionRecord(session: session, pty: pty),
    };
  }

  /// Get the Pty handle for a terminal (for writing commands / killing).
  Pty? getPty(String terminalId) => state[terminalId]?.pty;

  void unregister(String terminalId) {
    state = Map.of(state)..remove(terminalId);
  }

  PtySession? getSession(String terminalId) => state[terminalId]?.session;

  /// Append output lines to the terminal's rolling buffer.
  void appendOutput(String terminalId, String data) {
    final record = state[terminalId];
    if (record == null) return;

    final lines = data.split('\n');
    for (final line in lines) {
      record.outputBuffer.addLast(line);
      while (record.outputBuffer.length > maxOutputLines) {
        record.outputBuffer.removeFirst();
      }
    }
    // Trigger state update for listeners
    state = Map.of(state);
  }

  /// Read the last N lines from a terminal's output buffer.
  String readOutput(String terminalId, {int lines = 100}) {
    final record = state[terminalId];
    if (record == null) return '';
    final asList = record.outputBuffer.toList();
    final start = asList.length > lines ? asList.length - lines : 0;
    return asList.sublist(start).join('\n');
  }

  /// Update activity metadata for a terminal.
  void updateMeta(String terminalId, {String? activityStatus}) {
    final record = state[terminalId];
    if (record == null) return;

    state = {
      ...state,
      terminalId: TerminalSessionRecord(
        session: record.session,
        pty: record.pty,
        outputBuffer: record.outputBuffer,
        meta: TerminalSessionMeta(
          lastActivityTime: DateTime.now(),
          activityStatus: activityStatus,
        ),
      ),
    };
  }

  /// Get metadata for a terminal.
  TerminalSessionMeta? getMeta(String terminalId) => state[terminalId]?.meta;
}

final sessionRegistryProvider =
    NotifierProvider<SessionRegistry, Map<String, TerminalSessionRecord>>(
        SessionRegistry.new);
```

- [ ] **Step 2: Fix any existing references to the old API**

Search for `sessionRegistryProvider` usage across the codebase. The old API used `register(id, PtySession)`, `unregister(id)`, and `get(id)`. The new API keeps `register` and `unregister` with the same signatures (plus optional `pty` param). `get(id)` is now `getSession(id)` — update any callers.

Run: `grep -rn 'sessionRegistryProvider\|\.get(' lib/src/features/terminal/session_registry.dart lib/src/features/terminal/terminal_pane.dart`

Update any `ref.read(sessionRegistryProvider.notifier).get(id)` calls to `ref.read(sessionRegistryProvider.notifier).getSession(id)`.

Also update any existing `register(terminalId, session)` calls in `terminal_pane.dart` to pass the `Pty` handle: `register(terminalId, session, pty: _pty)`. This ensures MCP tool handlers can access the PTY via `SessionRegistry` rather than the static `TerminalPane.ptyRegistry` map (which is tied to widget lifecycle).

- [ ] **Step 3: Verify the app compiles**

Run: `cd packages/dispatch_app && flutter build macos --debug 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add lib/src/features/terminal/session_registry.dart
git commit -m "feat(mcp): extend SessionRegistry with output buffer and meta"
```

---

### Task 3: Wire TerminalMonitor Meta Callback

**Files:**
- Modify: `lib/src/features/terminal/terminal_monitor.dart`
- Modify: `lib/src/features/terminal/terminal_pane.dart`

- [ ] **Step 1: Add onMetaUpdate callback to TerminalMonitor**

In `terminal_monitor.dart`, add a third callback parameter:

```dart
// Add to the class fields (after onUrlDetected):
  final void Function(String terminalId, String activityStatus)? onMetaUpdate;

// Update constructor:
  TerminalMonitor({this.onStatusChange, this.onUrlDetected, this.onMetaUpdate});
```

Then in the `_updateStatus` method, after the existing `onStatusChange?.call(...)` line, add:

```dart
    onMetaUpdate?.call(terminalId, status.name);
```

- [ ] **Step 2: Wire output accumulator, TerminalMonitor, and meta callback in TerminalPane**

In `terminal_pane.dart`, in the `_TerminalPaneState` class:

Add imports at top of file:
```dart
import 'session_registry.dart';
import 'terminal_monitor.dart';
```

Add a `TerminalMonitor` field to `_TerminalPaneState`:
```dart
  late TerminalMonitor _monitor;
```

In `initState()`, construct the monitor (before `_startPty()`):
```dart
    _monitor = TerminalMonitor(
      onMetaUpdate: (terminalId, status) {
        ref.read(sessionRegistryProvider.notifier).updateMeta(
          terminalId,
          activityStatus: status,
        );
      },
    );
```

In `_startPty()`, inside the PTY output listener (the `.listen((data) {` block at line 78), add after `_terminal.write(data);`:

```dart
      // Feed output to SessionRegistry accumulator
      ref.read(sessionRegistryProvider.notifier).appendOutput(widget.terminalId, data);

      // Feed data to TerminalMonitor for idle/status detection
      _monitor.onData(widget.terminalId, data);
```

In `dispose()`, clean up the monitor:
```dart
    _monitor.cleanup(widget.terminalId);
```

- [ ] **Step 3: Verify the app compiles**

Run: `cd packages/dispatch_app && flutter build macos --debug 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add lib/src/features/terminal/terminal_monitor.dart lib/src/features/terminal/terminal_pane.dart
git commit -m "feat(mcp): wire terminal output accumulator and meta callbacks"
```

---

### Task 4: MCP Protocol Layer

**Files:**
- Create: `lib/src/features/mcp/mcp_protocol.dart`

- [ ] **Step 1: Create the MCP protocol message types**

```dart
import 'dart:convert';

/// JSON-RPC 2.0 protocol types for MCP.

class McpRequest {
  final String method;
  final Map<String, dynamic> params;
  final dynamic id;

  McpRequest({required this.method, this.params = const {}, this.id});

  factory McpRequest.fromJson(Map<String, dynamic> json) {
    return McpRequest(
      method: json['method'] as String,
      params: (json['params'] as Map<String, dynamic>?) ?? {},
      id: json['id'],
    );
  }
}

class McpResponse {
  final dynamic id;
  final Map<String, dynamic>? result;
  final McpError? error;

  McpResponse({this.id, this.result, this.error});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'jsonrpc': '2.0', 'id': id};
    if (error != null) {
      json['error'] = error!.toJson();
    } else {
      json['result'] = result ?? {};
    }
    return json;
  }

  String toJsonString() => jsonEncode(toJson());

  factory McpResponse.success(dynamic id, Map<String, dynamic> result) =>
      McpResponse(id: id, result: result);

  factory McpResponse.error(dynamic id, int code, String message) =>
      McpResponse(id: id, error: McpError(code: code, message: message));

  factory McpResponse.methodNotFound(dynamic id, String method) =>
      McpResponse.error(id, -32601, 'Method not found: $method');

  factory McpResponse.invalidParams(dynamic id, String message) =>
      McpResponse.error(id, -32602, message);

  factory McpResponse.internalError(dynamic id, String message) =>
      McpResponse.error(id, -32603, message);
}

class McpError {
  final int code;
  final String message;

  McpError({required this.code, required this.message});

  Map<String, dynamic> toJson() => {'code': code, 'message': message};
}

class McpNotification {
  final String method;
  final Map<String, dynamic> params;

  McpNotification({required this.method, required this.params});

  Map<String, dynamic> toJson() => {
        'jsonrpc': '2.0',
        'method': method,
        'params': params,
      };

  String toJsonString() => jsonEncode(toJson());

  String toSseEvent() => 'data: ${toJsonString()}\n\n';
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/features/mcp/mcp_protocol.dart
git commit -m "feat(mcp): add JSON-RPC 2.0 protocol types"
```

---

### Task 5: MCP Tool Registry

**Files:**
- Create: `lib/src/features/mcp/mcp_tools.dart`

- [ ] **Step 1: Create the tool registry**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mcp_protocol.dart';

/// Signature for an MCP tool handler function.
typedef McpToolHandler = Future<Map<String, dynamic>> Function(
  Ref ref,
  Map<String, dynamic> params,
);

/// Describes an MCP tool with its schema and handler.
class McpToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final McpToolHandler handler;

  const McpToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

/// Registry of all MCP tools. Populated at server startup.
class McpToolRegistry {
  final Map<String, McpToolDefinition> _tools = {};

  void register(McpToolDefinition tool) {
    _tools[tool.name] = tool;
  }

  void registerAll(List<McpToolDefinition> tools) {
    for (final tool in tools) {
      _tools[tool.name] = tool;
    }
  }

  McpToolDefinition? get(String name) => _tools[name];

  List<McpToolDefinition> get all => _tools.values.toList();

  List<Map<String, dynamic>> toJsonList() =>
      _tools.values.map((t) => t.toJson()).toList();

  Future<McpResponse> handle(Ref ref, McpRequest request) async {
    final tool = _tools[request.method];
    if (tool == null) {
      return McpResponse.methodNotFound(request.id, request.method);
    }
    try {
      final result = await tool.handler(ref, request.params);
      return McpResponse.success(request.id, result);
    } catch (e) {
      return McpResponse.internalError(request.id, e.toString());
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/features/mcp/mcp_tools.dart
git commit -m "feat(mcp): add tool registry with handler routing"
```

---

### Task 6: Observe Tools

**Files:**
- Create: `lib/src/features/mcp/tools/observe_tools.dart`

- [ ] **Step 1: Implement observe tool handlers**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp_tools.dart';
import '../../projects/projects_provider.dart';
import '../../terminal/terminal_provider.dart';
import '../../terminal/session_registry.dart';

List<McpToolDefinition> observeTools() => [
      McpToolDefinition(
        name: 'list_projects',
        description: 'Returns all project groups with IDs, labels, cwds, and terminal IDs',
        inputSchema: {'type': 'object', 'properties': {}},
        handler: _listProjects,
      ),
      McpToolDefinition(
        name: 'get_active_project',
        description: 'Returns the currently active project group',
        inputSchema: {'type': 'object', 'properties': {}},
        handler: _getActiveProject,
      ),
      McpToolDefinition(
        name: 'list_terminals',
        description: 'Returns all terminals, optionally filtered by project',
        inputSchema: {
          'type': 'object',
          'properties': {
            'projectId': {'type': 'string', 'description': 'Filter by project group ID'},
          },
        },
        handler: _listTerminals,
      ),
      McpToolDefinition(
        name: 'read_terminal',
        description: 'Returns recent output from a terminal',
        inputSchema: {
          'type': 'object',
          'properties': {
            'terminalId': {'type': 'string'},
            'lines': {'type': 'integer', 'default': 100},
          },
          'required': ['terminalId'],
        },
        handler: _readTerminal,
      ),
      McpToolDefinition(
        name: 'get_terminal_status',
        description: 'Returns terminal status, exit code, and idle duration',
        inputSchema: {
          'type': 'object',
          'properties': {
            'terminalId': {'type': 'string'},
          },
          'required': ['terminalId'],
        },
        handler: _getTerminalStatus,
      ),
    ];

Future<Map<String, dynamic>> _listProjects(Ref ref, Map<String, dynamic> params) async {
  final state = ref.read(projectsProvider);
  return {
    'projects': state.groups.map((g) => {
          'id': g.id,
          'label': g.label,
          'cwd': g.cwd,
          'terminalIds': g.terminalIds,
        }).toList(),
  };
}

Future<Map<String, dynamic>> _getActiveProject(Ref ref, Map<String, dynamic> params) async {
  final state = ref.read(projectsProvider);
  final active = state.groups.where((g) => g.id == state.activeGroupId).firstOrNull;
  if (active == null) return {'project': null};
  return {
    'project': {
      'id': active.id,
      'label': active.label,
      'cwd': active.cwd,
      'terminalIds': active.terminalIds,
    },
  };
}

Future<Map<String, dynamic>> _listTerminals(Ref ref, Map<String, dynamic> params) async {
  final projectId = params['projectId'] as String?;
  final terminalsState = ref.read(terminalsProvider);
  final projectsState = ref.read(projectsProvider);

  var terminalIds = terminalsState.terminals.keys.toList();
  if (projectId != null) {
    final group = projectsState.groups.where((g) => g.id == projectId).firstOrNull;
    if (group != null) {
      terminalIds = group.terminalIds;
    }
  }

  return {
    'terminals': terminalIds
        .where((id) => terminalsState.terminals.containsKey(id))
        .map((id) {
      final t = terminalsState.terminals[id]!;
      return {
        'id': t.id,
        'command': t.command,
        'cwd': t.cwd,
        'status': t.status.name,
        'label': t.label,
        'exitCode': t.exitCode,
      };
    }).toList(),
  };
}

Future<Map<String, dynamic>> _readTerminal(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminalId'] as String?;
  if (terminalId == null) throw ArgumentError('terminalId is required');

  final lines = (params['lines'] as int?) ?? 100;
  final registry = ref.read(sessionRegistryProvider.notifier);
  final content = registry.readOutput(terminalId, lines: lines);
  final lineCount = content.isEmpty ? 0 : content.split('\n').length;

  return {
    'terminalId': terminalId,
    'content': content,
    'lineCount': lineCount,
  };
}

Future<Map<String, dynamic>> _getTerminalStatus(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminalId'] as String?;
  if (terminalId == null) throw ArgumentError('terminalId is required');

  final terminal = ref.read(terminalsProvider).terminals[terminalId];
  if (terminal == null) throw StateError('Terminal not found: $terminalId');

  final meta = ref.read(sessionRegistryProvider.notifier).getMeta(terminalId);

  return {
    'status': terminal.status.name,
    'exitCode': terminal.exitCode,
    'idleDurationMs': meta?.idleDurationMs,
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/features/mcp/tools/observe_tools.dart
git commit -m "feat(mcp): implement observe tools (list/read terminals & projects)"
```

---

### Task 7: Act Tools

**Files:**
- Create: `lib/src/features/mcp/tools/act_tools.dart`

- [ ] **Step 1: Implement act tool handlers**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp_tools.dart';
import '../../terminal/terminal_provider.dart';
import '../../terminal/session_registry.dart';
import '../../projects/projects_provider.dart';
import '../../../core/models/terminal_entry.dart';

List<McpToolDefinition> actTools() => [
      McpToolDefinition(
        name: 'run_command',
        description: 'Sends a command to an existing terminal (writes command + newline)',
        inputSchema: {
          'type': 'object',
          'properties': {
            'terminalId': {'type': 'string'},
            'command': {'type': 'string'},
          },
          'required': ['terminalId', 'command'],
        },
        handler: _runCommand,
      ),
      McpToolDefinition(
        name: 'spawn_terminal',
        description: 'Creates a new terminal with a command and working directory',
        inputSchema: {
          'type': 'object',
          'properties': {
            'command': {'type': 'string'},
            'cwd': {'type': 'string'},
            'projectId': {'type': 'string'},
            'label': {'type': 'string'},
          },
          'required': ['command', 'cwd'],
        },
        handler: _spawnTerminal,
      ),
      McpToolDefinition(
        name: 'kill_terminal',
        description: 'Kills a terminal PTY process',
        inputSchema: {
          'type': 'object',
          'properties': {
            'terminalId': {'type': 'string'},
          },
          'required': ['terminalId'],
        },
        handler: _killTerminal,
      ),
      McpToolDefinition(
        name: 'write_to_terminal',
        description: 'Writes raw text to a terminal PTY (no newline appended)',
        inputSchema: {
          'type': 'object',
          'properties': {
            'terminalId': {'type': 'string'},
            'input': {'type': 'string'},
          },
          'required': ['terminalId', 'input'],
        },
        handler: _writeToTerminal,
      ),
    ];

Future<Map<String, dynamic>> _runCommand(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminalId'] as String?;
  final command = params['command'] as String?;
  if (terminalId == null || command == null) {
    throw ArgumentError('terminalId and command are required');
  }

  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty == null) return {'success': false, 'error': 'Terminal PTY not found'};

  pty.write(const Utf8Encoder().convert('$command\n'));
  return {'success': true};
}

Future<Map<String, dynamic>> _spawnTerminal(Ref ref, Map<String, dynamic> params) async {
  final command = params['command'] as String?;
  final cwd = params['cwd'] as String?;
  if (command == null || cwd == null) {
    throw ArgumentError('command and cwd are required');
  }

  final projectId = params['projectId'] as String?;
  final label = params['label'] as String?;

  // Find or create group
  final groupId = projectId ??
      ref.read(projectsProvider).activeGroupId ??
      ref.read(projectsProvider.notifier).findOrCreateGroup(cwd);

  final terminalId = 'term-${DateTime.now().millisecondsSinceEpoch}-mcp';

  ref.read(terminalsProvider.notifier).addTerminal(
        groupId,
        TerminalEntry(
          id: terminalId,
          command: command,
          cwd: cwd,
          status: TerminalStatus.running,
          label: label,
        ),
      );

  return {'terminalId': terminalId, 'projectId': groupId};
}

Future<Map<String, dynamic>> _killTerminal(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminalId'] as String?;
  if (terminalId == null) throw ArgumentError('terminalId is required');

  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty == null) return {'success': false, 'error': 'Terminal PTY not found'};

  pty.kill();
  return {'success': true};
}

Future<Map<String, dynamic>> _writeToTerminal(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminalId'] as String?;
  final input = params['input'] as String?;
  if (terminalId == null || input == null) {
    throw ArgumentError('terminalId and input are required');
  }

  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty == null) return {'success': false, 'error': 'Terminal PTY not found'};

  pty.write(const Utf8Encoder().convert(input));
  return {'success': true};
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/features/mcp/tools/act_tools.dart
git commit -m "feat(mcp): implement act tools (run/spawn/kill/write terminal)"
```

---

### Task 8: Orchestrate Tools

**Files:**
- Create: `lib/src/features/mcp/tools/orchestrate_tools.dart`

- [ ] **Step 1: Implement orchestrate tool handlers**

```dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp_tools.dart';
import '../../projects/projects_provider.dart';
import '../../terminal/terminal_provider.dart';
import '../../terminal/session_registry.dart';
import '../../../core/models/terminal_entry.dart';
import '../../../core/models/split_node.dart';

List<McpToolDefinition> orchestrateTools() => [
      McpToolDefinition(
        name: 'create_project',
        description: 'Creates a new project group',
        inputSchema: {
          'type': 'object',
          'properties': {
            'label': {'type': 'string'},
            'cwd': {'type': 'string'},
          },
          'required': ['label', 'cwd'],
        },
        handler: _createProject,
      ),
      McpToolDefinition(
        name: 'close_project',
        description: 'Closes a project group and all its terminals',
        inputSchema: {
          'type': 'object',
          'properties': {
            'projectId': {'type': 'string'},
          },
          'required': ['projectId'],
        },
        handler: _closeProject,
      ),
      McpToolDefinition(
        name: 'set_active_project',
        description: 'Switches the active project tab',
        inputSchema: {
          'type': 'object',
          'properties': {
            'projectId': {'type': 'string'},
          },
          'required': ['projectId'],
        },
        handler: _setActiveProject,
      ),
      McpToolDefinition(
        name: 'set_active_terminal',
        description: 'Switches the active terminal',
        inputSchema: {
          'type': 'object',
          'properties': {
            'terminalId': {'type': 'string'},
          },
          'required': ['terminalId'],
        },
        handler: _setActiveTerminal,
      ),
      McpToolDefinition(
        name: 'split_terminal',
        description: 'Splits the view and places a terminal in the new pane',
        inputSchema: {
          'type': 'object',
          'properties': {
            'terminalId': {'type': 'string', 'description': 'Source pane terminal ID'},
            'direction': {'type': 'string', 'enum': ['horizontal', 'vertical']},
            'newTerminalId': {'type': 'string', 'description': 'Existing terminal to place in new pane'},
            'command': {'type': 'string', 'description': 'Command for new terminal (if not using newTerminalId)'},
            'cwd': {'type': 'string', 'description': 'Working directory for new terminal'},
          },
          'required': ['terminalId', 'direction'],
        },
        handler: _splitTerminal,
      ),
    ];

Future<Map<String, dynamic>> _createProject(Ref ref, Map<String, dynamic> params) async {
  final label = params['label'] as String?;
  final cwd = params['cwd'] as String?;
  if (label == null || cwd == null) {
    throw ArgumentError('label and cwd are required');
  }

  // Use addGroup which accepts a custom label (unlike findOrCreateGroup which
  // auto-generates from path). Read the groups before/after to find the new ID.
  final before = ref.read(projectsProvider).groups.map((g) => g.id).toSet();
  ref.read(projectsProvider.notifier).addGroup(cwd, label);
  final after = ref.read(projectsProvider).groups;
  final newGroup = after.where((g) => !before.contains(g.id)).firstOrNull;
  return {'projectId': newGroup?.id ?? ''};
}

Future<Map<String, dynamic>> _closeProject(Ref ref, Map<String, dynamic> params) async {
  final projectId = params['projectId'] as String?;
  if (projectId == null) throw ArgumentError('projectId is required');

  final state = ref.read(projectsProvider);
  final group = state.groups.where((g) => g.id == projectId).firstOrNull;
  if (group == null) return {'success': false, 'error': 'Project not found'};

  // Kill all terminals in the group
  for (final terminalId in [...group.terminalIds]) {
    final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
    pty?.kill();
    ref.read(terminalsProvider.notifier).removeTerminal(terminalId);
  }
  ref.read(projectsProvider.notifier).removeGroup(projectId);
  return {'success': true};
}

Future<Map<String, dynamic>> _setActiveProject(Ref ref, Map<String, dynamic> params) async {
  final projectId = params['projectId'] as String?;
  if (projectId == null) throw ArgumentError('projectId is required');

  ref.read(projectsProvider.notifier).setActiveGroup(projectId);
  return {'success': true};
}

Future<Map<String, dynamic>> _setActiveTerminal(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminalId'] as String?;
  if (terminalId == null) throw ArgumentError('terminalId is required');

  ref.read(terminalsProvider.notifier).setActiveTerminal(terminalId);
  return {'success': true};
}

Future<Map<String, dynamic>> _splitTerminal(Ref ref, Map<String, dynamic> params) async {
  final sourceTerminalId = params['terminalId'] as String?;
  final directionStr = params['direction'] as String?;
  if (sourceTerminalId == null || directionStr == null) {
    throw ArgumentError('terminalId and direction are required');
  }

  final direction = directionStr == 'horizontal'
      ? SplitDirection.horizontal
      : SplitDirection.vertical;

  // Determine target terminal
  String targetTerminalId;
  final newTerminalId = params['newTerminalId'] as String?;

  if (newTerminalId != null) {
    targetTerminalId = newTerminalId;
  } else {
    // Spawn a new terminal
    final command = (params['command'] as String?) ?? '\$SHELL';
    final cwd = (params['cwd'] as String?) ??
        ref.read(terminalsProvider).terminals[sourceTerminalId]?.cwd ??
        Platform.environment['HOME'] ??
        '/';

    targetTerminalId = 'term-${DateTime.now().millisecondsSinceEpoch}-split';
    final groupId = ref.read(projectsProvider).activeGroupId;
    if (groupId == null) throw StateError('No active project group');

    ref.read(terminalsProvider.notifier).addTerminal(
          groupId,
          TerminalEntry(
            id: targetTerminalId,
            command: command,
            cwd: cwd,
            status: TerminalStatus.running,
          ),
        );
  }

  // Build split layout
  final projectsState = ref.read(projectsProvider);
  final group = projectsState.groups
      .where((g) => g.id == projectsState.activeGroupId)
      .firstOrNull;
  if (group == null) throw StateError('No active project group');

  // Create a simple equal split with all terminals in the group
  final layout = SplitNode.buildEqualSplit(group.terminalIds, direction);
  ref.read(projectsProvider.notifier).setGroupSplitLayout(group.id, layout);

  return {'terminalId': targetTerminalId};
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/features/mcp/tools/orchestrate_tools.dart
git commit -m "feat(mcp): implement orchestrate tools (project/split management)"
```

---

### Task 9: MCP HTTP Server

**Files:**
- Create: `lib/src/features/mcp/mcp_server.dart`

- [ ] **Step 1: Implement the shelf-based MCP server**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'mcp_protocol.dart';
import 'mcp_tools.dart';
import 'tools/observe_tools.dart';
import 'tools/act_tools.dart';
import 'tools/orchestrate_tools.dart';

class McpServer {
  final Ref ref;
  final McpToolRegistry _registry = McpToolRegistry();
  final List<StreamController<String>> _sseClients = [];

  HttpServer? _server;
  int _port = 3900;
  String? _authToken;
  bool _bindAll = false;
  int _requestCount = 0;
  final List<McpActivityEntry> activityLog = [];

  int get port => _port;
  int get connectionCount => _sseClients.length;
  bool get isRunning => _server != null;

  McpServer(this.ref) {
    _registry.registerAll(observeTools());
    _registry.registerAll(actTools());
    _registry.registerAll(orchestrateTools());
  }

  Future<int> start({
    int port = 3900,
    String? authToken,
    bool bindAll = false,
  }) async {
    _authToken = authToken;
    _bindAll = bindAll;

    final router = Router()
      ..post('/mcp', _handleRpc)
      ..get('/mcp/sse', _handleSse)
      ..get('/mcp/health', _handleHealth);

    final handler = const shelf.Pipeline()
        .addMiddleware(_authMiddleware())
        .addHandler(router.call);

    // Try the requested port, fall back to random
    final address = bindAll ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4;
    try {
      _server = await shelf_io.serve(handler, address, port);
      _port = port;
    } catch (_) {
      // Port in use — try a random port
      _server = await shelf_io.serve(handler, address, 0);
      _port = _server!.port;
    }

    return _port;
  }

  Future<void> stop() async {
    for (final client in _sseClients) {
      await client.close();
    }
    _sseClients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  /// Push a notification to all connected SSE clients.
  void notify(McpNotification notification) {
    final event = notification.toSseEvent();
    for (final client in _sseClients) {
      client.add(event);
    }
  }

  shelf.Middleware _authMiddleware() {
    return (shelf.Handler handler) {
      return (shelf.Request request) {
        if (_authToken == null || _authToken!.isEmpty) {
          return handler(request);
        }
        final auth = request.headers['authorization'];
        if (auth != 'Bearer $_authToken') {
          return shelf.Response.forbidden(
            jsonEncode({'error': 'Invalid or missing authorization token'}),
            headers: {'content-type': 'application/json'},
          );
        }
        return handler(request);
      };
    };
  }

  Future<shelf.Response> _handleRpc(shelf.Request request) async {
    final body = await request.readAsString();
    Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return shelf.Response(400,
          body: jsonEncode({'error': 'Invalid JSON'}),
          headers: {'content-type': 'application/json'});
    }

    final mcpRequest = McpRequest.fromJson(json);

    // Handle JSON-RPC notifications (no id) — return 204 No Content
    if (mcpRequest.id == null) {
      return shelf.Response(204);
    }

    // Handle MCP protocol methods
    if (mcpRequest.method == 'initialize') {
      final response = McpResponse.success(mcpRequest.id, {
        'protocolVersion': '2024-11-05',
        'capabilities': {
          'tools': {'listChanged': false},
        },
        'serverInfo': {
          'name': 'dispatch',
          'version': '0.1.0',
        },
      });
      return shelf.Response.ok(response.toJsonString(),
          headers: {'content-type': 'application/json'});
    }

    if (mcpRequest.method == 'tools/list') {
      final response = McpResponse.success(mcpRequest.id, {
        'tools': _registry.toJsonList(),
      });
      return shelf.Response.ok(response.toJsonString(),
          headers: {'content-type': 'application/json'});
    }

    if (mcpRequest.method == 'tools/call') {
      final toolName = mcpRequest.params['name'] as String?;
      final toolParams =
          (mcpRequest.params['arguments'] as Map<String, dynamic>?) ?? {};
      if (toolName == null) {
        return shelf.Response.ok(
          McpResponse.invalidParams(mcpRequest.id, 'Missing tool name')
              .toJsonString(),
          headers: {'content-type': 'application/json'},
        );
      }

      final toolRequest =
          McpRequest(method: toolName, params: toolParams, id: mcpRequest.id);
      final response = await _registry.handle(ref, toolRequest);

      // Log activity
      _requestCount++;
      activityLog.insert(0, McpActivityEntry(
        timestamp: DateTime.now(),
        toolName: toolName,
        agentId: request.headers['x-agent-id'] ?? 'unknown',
      ));
      if (activityLog.length > 100) activityLog.removeLast();

      return shelf.Response.ok(response.toJsonString(),
          headers: {'content-type': 'application/json'});
    }

    // Unknown method
    return shelf.Response.ok(
      McpResponse.methodNotFound(mcpRequest.id, mcpRequest.method)
          .toJsonString(),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<shelf.Response> _handleSse(shelf.Request request) async {
    final controller = StreamController<String>();
    _sseClients.add(controller);

    // Remove client on disconnect
    controller.onCancel = () {
      _sseClients.remove(controller);
    };

    return shelf.Response.ok(
      controller.stream,
      headers: {
        'content-type': 'text/event-stream',
        'cache-control': 'no-cache',
        'connection': 'keep-alive',
      },
    );
  }

  Future<shelf.Response> _handleHealth(shelf.Request request) async {
    return shelf.Response.ok(
      jsonEncode({
        'status': 'ok',
        'version': '0.1.0',
        'connections': _sseClients.length,
        'requestsServed': _requestCount,
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  static String generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

class McpActivityEntry {
  final DateTime timestamp;
  final String toolName;
  final String agentId;

  McpActivityEntry({
    required this.timestamp,
    required this.toolName,
    required this.agentId,
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/features/mcp/mcp_server.dart
git commit -m "feat(mcp): implement shelf HTTP server with RPC routing and SSE"
```

---

### Task 10: MCP Notifications

**Files:**
- Create: `lib/src/features/mcp/mcp_notifications.dart`

- [ ] **Step 1: Implement notification listeners**

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mcp_protocol.dart';
import 'mcp_server.dart';
import '../terminal/terminal_provider.dart';
import '../terminal/session_registry.dart';
import '../projects/projects_provider.dart';

/// Sets up Riverpod listeners that push SSE notifications when state changes.
class McpNotificationManager {
  final Ref ref;
  final McpServer server;
  Timer? _outputDebounce;
  Map<String, int> _lastOutputLengths = {};

  McpNotificationManager(this.ref, this.server);

  void startListening() {
    // Watch terminal state changes
    ref.listen(terminalsProvider, (prev, next) {
      if (prev == null) return;

      // Detect status changes
      for (final entry in next.terminals.entries) {
        final prevTerminal = prev.terminals[entry.key];
        if (prevTerminal != null && prevTerminal.status != entry.value.status) {
          server.notify(McpNotification(
            method: 'terminal_status_changed',
            params: {
              'terminalId': entry.key,
              'status': entry.value.status.name,
              'exitCode': entry.value.exitCode,
            },
          ));
        }
      }
    });

    // Watch project changes
    ref.listen(projectsProvider, (prev, next) {
      if (prev == null) return;
      if (prev.groups.length != next.groups.length ||
          prev.activeGroupId != next.activeGroupId) {
        server.notify(McpNotification(
          method: 'project_changed',
          params: {
            'activeProjectId': next.activeGroupId,
            'projectCount': next.groups.length,
          },
        ));
      }
    });

    // Debounced terminal output notifications
    ref.listen(sessionRegistryProvider, (prev, next) {
      _outputDebounce?.cancel();
      _outputDebounce = Timer(const Duration(milliseconds: 200), () {
        for (final entry in next.entries) {
          final currentLength = entry.value.outputBuffer.length;
          final prevLength = _lastOutputLengths[entry.key] ?? 0;
          if (currentLength > prevLength) {
            server.notify(McpNotification(
              method: 'terminal_output',
              params: {
                'terminalId': entry.key,
                'newLines': currentLength - prevLength,
              },
            ));
          }
          _lastOutputLengths[entry.key] = currentLength;
        }
      });
    });
  }

  void stopListening() {
    _outputDebounce?.cancel();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/features/mcp/mcp_notifications.dart
git commit -m "feat(mcp): add notification manager for SSE event push"
```

---

### Task 11: MCP Provider (State Management)

**Files:**
- Create: `lib/src/features/mcp/mcp_provider.dart`

- [ ] **Step 1: Implement McpServerNotifier**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mcp_server.dart';
import 'mcp_notifications.dart';
import '../../persistence/auto_save.dart';

class McpServerState {
  final bool enabled;
  final bool running;
  final int port;
  final bool authEnabled;
  final String? authToken;
  final bool bindAll;
  final int connectionCount;
  final List<McpActivityEntry> activityLog;

  const McpServerState({
    this.enabled = false,
    this.running = false,
    this.port = 3900,
    this.authEnabled = false,
    this.authToken,
    this.bindAll = false,
    this.connectionCount = 0,
    this.activityLog = const [],
  });

  McpServerState copyWith({
    bool? enabled,
    bool? running,
    int? port,
    bool? authEnabled,
    String? Function()? authToken,
    bool? bindAll,
    int? connectionCount,
    List<McpActivityEntry>? activityLog,
  }) {
    return McpServerState(
      enabled: enabled ?? this.enabled,
      running: running ?? this.running,
      port: port ?? this.port,
      authEnabled: authEnabled ?? this.authEnabled,
      authToken: authToken != null ? authToken() : this.authToken,
      bindAll: bindAll ?? this.bindAll,
      connectionCount: connectionCount ?? this.connectionCount,
      activityLog: activityLog ?? this.activityLog,
    );
  }

  String get httpUrl => 'http://localhost:$port/mcp';

  String claudeCodeConfig() {
    final config = <String, dynamic>{
      'type': 'url',
      'url': httpUrl,
    };
    if (authEnabled && authToken != null) {
      config['headers'] = {'Authorization': 'Bearer $authToken'};
    }
    return '{\n  "dispatch": ${_prettyJson(config)}\n}';
  }

  static String _prettyJson(Map<String, dynamic> json) {
    final buffer = StringBuffer('{');
    final entries = json.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final value = entry.value is String
          ? '"${entry.value}"'
          : entry.value is Map
              ? _prettyJson(entry.value as Map<String, dynamic>)
              : entry.value.toString();
      buffer.write('\n    "${entry.key}": $value');
      if (i < entries.length - 1) buffer.write(',');
    }
    buffer.write('\n  }');
    return buffer.toString();
  }
}

class McpServerNotifier extends Notifier<McpServerState> {
  McpServer? _server;
  McpNotificationManager? _notificationManager;
  bool _disposed = false;

  @override
  McpServerState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      stopServer();
    });
    // Load settings from database at startup
    _loadSettings();
    return const McpServerState();
  }

  Future<void> _loadSettings() async {
    final db = ref.read(databaseProvider);
    final enabled = await db.settingsDao.getValue('mcp_enabled');
    final port = await db.settingsDao.getValue('mcp_port');
    final authEnabled = await db.settingsDao.getValue('mcp_auth_enabled');
    final authToken = await db.settingsDao.getValue('mcp_auth_token');
    final bindAll = await db.settingsDao.getValue('mcp_bind_all');

    // Guard against disposal during async gap
    if (_disposed) return;

    state = state.copyWith(
      enabled: enabled == 'true',
      port: port != null ? (int.tryParse(port) ?? 3900) : 3900,
      authEnabled: authEnabled == 'true',
      authToken: () => authToken,
      bindAll: bindAll == 'true',
    );

    // Auto-start if enabled
    if (state.enabled) {
      await startServer();
    }
  }

  Future<void> _saveSettings() async {
    final db = ref.read(databaseProvider);
    await db.settingsDao.setValue('mcp_enabled', state.enabled.toString());
    await db.settingsDao.setValue('mcp_port', state.port.toString());
    await db.settingsDao.setValue('mcp_auth_enabled', state.authEnabled.toString());
    if (state.authToken != null) {
      await db.settingsDao.setValue('mcp_auth_token', state.authToken!);
    }
    await db.settingsDao.setValue('mcp_bind_all', state.bindAll.toString());
  }

  Future<void> startServer() async {
    if (_server != null) return;

    _server = McpServer(ref);
    final actualPort = await _server!.start(
      port: state.port,
      authToken: state.authEnabled ? state.authToken : null,
      bindAll: state.bindAll,
    );

    _notificationManager = McpNotificationManager(ref, _server!);
    _notificationManager!.startListening();

    state = state.copyWith(
      running: true,
      port: actualPort,
    );
  }

  Future<void> stopServer() async {
    _notificationManager?.stopListening();
    _notificationManager = null;
    await _server?.stop();
    _server = null;
    state = state.copyWith(running: false, connectionCount: 0);
  }

  Future<void> toggle() async {
    if (state.running) {
      await stopServer();
      state = state.copyWith(enabled: false);
    } else {
      state = state.copyWith(enabled: true);
      await startServer();
    }
    await _saveSettings();
  }

  Future<void> setPort(int port) async {
    state = state.copyWith(port: port);
    if (state.running) {
      await stopServer();
      await startServer();
    }
    await _saveSettings();
  }

  Future<void> setAuthEnabled(bool enabled) async {
    if (enabled && state.authToken == null) {
      state = state.copyWith(
        authEnabled: true,
        authToken: () => McpServer.generateToken(),
      );
    } else {
      state = state.copyWith(authEnabled: enabled);
    }
    if (state.running) {
      await stopServer();
      await startServer();
    }
    await _saveSettings();
  }

  Future<void> regenerateToken() async {
    state = state.copyWith(authToken: () => McpServer.generateToken());
    if (state.running) {
      await stopServer();
      await startServer();
    }
    await _saveSettings();
  }

  Future<void> setBindAll(bool bindAll) async {
    state = state.copyWith(bindAll: bindAll);
    if (state.running) {
      await stopServer();
      await startServer();
    }
    await _saveSettings();
  }

  /// Refresh connection count and activity log from the server.
  void refreshStatus() {
    if (_server == null) return;
    state = state.copyWith(
      connectionCount: _server!.connectionCount,
      activityLog: List.of(_server!.activityLog),
    );
  }
}

final mcpServerProvider =
    NotifierProvider<McpServerNotifier, McpServerState>(McpServerNotifier.new);
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/features/mcp/mcp_provider.dart
git commit -m "feat(mcp): add McpServerNotifier with lifecycle and settings persistence"
```

---

### Task 12: Integrations Panel UI

**Files:**
- Create: `lib/src/features/mcp/mcp_panel.dart`

- [ ] **Step 1: Implement the Integrations panel**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
import 'mcp_provider.dart';
import 'mcp_server.dart';

class McpPanel extends ConsumerStatefulWidget {
  final bool open;
  final VoidCallback onClose;

  const McpPanel({super.key, required this.open, required this.onClose});

  @override
  ConsumerState<McpPanel> createState() => _McpPanelState();
}

class _McpPanelState extends ConsumerState<McpPanel> {
  late TextEditingController _portCtrl;
  bool _tokenVisible = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _portCtrl = TextEditingController();
    // Refresh connection count periodically
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      ref.read(mcpServerProvider.notifier).refreshStatus();
    });
  }

  @override
  void dispose() {
    _portCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    final mcpState = ref.watch(mcpServerProvider);
    final colorTheme = ref.watch(activeThemeProvider);
    final theme = AppTheme(colorTheme);
    // Only update controller if value actually changed (avoids overwriting mid-edit)
    final portStr = mcpState.port.toString();
    if (_portCtrl.text != portStr) _portCtrl.text = portStr;

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // prevent close on panel tap
            child: Container(
              width: 480,
              constraints: const BoxConstraints(maxHeight: 600),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border, width: 1),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.extension_outlined, color: theme.textPrimary, size: 18),
                        const SizedBox(width: 8),
                        Text('Integrations', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: widget.onClose,
                          child: Icon(Icons.close, color: theme.textSecondary, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Server Status
                    _sectionLabel('MCP SERVER', theme),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Server', style: TextStyle(color: theme.textPrimary, fontSize: 13)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => ref.read(mcpServerProvider.notifier).toggle(),
                          child: Container(
                            width: 40,
                            height: 22,
                            decoration: BoxDecoration(
                              color: mcpState.running ? theme.accentGreen : theme.border,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 150),
                              alignment: mcpState.running ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                width: 18,
                                height: 18,
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: theme.textPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (mcpState.running) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Running on port ${mcpState.port} \u2022 ${mcpState.connectionCount} connected',
                        style: TextStyle(color: theme.textSecondary, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Connection Info
                    if (mcpState.running) ...[
                      _sectionLabel('CONNECTION', theme),
                      const SizedBox(height: 8),
                      _copyRow('URL', mcpState.httpUrl, theme),
                      if (mcpState.authEnabled && mcpState.authToken != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text('Token', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setState(() => _tokenVisible = !_tokenVisible),
                              child: Text(
                                _tokenVisible ? mcpState.authToken! : '\u2022' * 16,
                                style: TextStyle(color: theme.textPrimary, fontSize: 11, fontFamily: 'Menlo'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _copyButton(mcpState.authToken!, theme),
                          ],
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => ref.read(mcpServerProvider.notifier).regenerateToken(),
                          child: Text('Regenerate token', style: TextStyle(color: theme.accentBlue, fontSize: 11)),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _sectionLabel('CLAUDE CODE CONFIG', theme),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                mcpState.claudeCodeConfig(),
                                style: TextStyle(color: theme.textSecondary, fontSize: 11, fontFamily: 'Menlo'),
                              ),
                            ),
                            _copyButton(mcpState.claudeCodeConfig(), theme),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Settings
                    _sectionLabel('SETTINGS', theme),
                    const SizedBox(height: 8),
                    _settingRow('Port', theme, child: SizedBox(
                      width: 80,
                      height: 28,
                      child: TextField(
                        controller: _portCtrl,
                        style: TextStyle(color: theme.textPrimary, fontSize: 12),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: theme.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: theme.border)),
                        ),
                        onSubmitted: (value) {
                          final port = int.tryParse(value);
                          if (port != null && port > 0 && port < 65536) {
                            ref.read(mcpServerProvider.notifier).setPort(port);
                          }
                        },
                      ),
                    )),
                    const SizedBox(height: 6),
                    _toggleRow('Token auth', mcpState.authEnabled, theme,
                        onChanged: (v) => ref.read(mcpServerProvider.notifier).setAuthEnabled(v)),
                    const SizedBox(height: 6),
                    _toggleRow('Network access', mcpState.bindAll, theme,
                        onChanged: (v) => ref.read(mcpServerProvider.notifier).setBindAll(v),
                        warning: 'Exposes server to local network'),

                    // Activity Log
                    if (mcpState.running && mcpState.activityLog.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionLabel('RECENT ACTIVITY', theme),
                      const SizedBox(height: 8),
                      ...mcpState.activityLog.take(10).map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                Text(
                                  '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}',
                                  style: TextStyle(color: theme.textSecondary, fontSize: 10, fontFamily: 'Menlo'),
                                ),
                                const SizedBox(width: 8),
                                Text(entry.toolName, style: TextStyle(color: theme.textPrimary, fontSize: 11)),
                                const Spacer(),
                                Text(entry.agentId, style: TextStyle(color: theme.textSecondary, fontSize: 10)),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, AppTheme theme) {
    return Text(text, style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1));
  }

  Widget _copyRow(String label, String value, AppTheme theme) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
        const Spacer(),
        Text(value, style: TextStyle(color: theme.textPrimary, fontSize: 11, fontFamily: 'Menlo')),
        const SizedBox(width: 6),
        _copyButton(value, theme),
      ],
    );
  }

  Widget _copyButton(String text, AppTheme theme) {
    return GestureDetector(
      onTap: () => Clipboard.setData(ClipboardData(text: text)),
      child: Icon(Icons.copy, size: 12, color: theme.textSecondary),
    );
  }

  Widget _settingRow(String label, AppTheme theme, {required Widget child}) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: theme.textPrimary, fontSize: 13)),
        const Spacer(),
        child,
      ],
    );
  }

  Widget _toggleRow(String label, bool value, AppTheme theme,
      {required ValueChanged<bool> onChanged, String? warning}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(color: theme.textPrimary, fontSize: 13)),
            const Spacer(),
            GestureDetector(
              onTap: () => onChanged(!value),
              child: Container(
                width: 36,
                height: 20,
                decoration: BoxDecoration(
                  color: value ? theme.accentGreen : theme.border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 150),
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.textPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (warning != null && value)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(warning, style: TextStyle(color: theme.accentYellow, fontSize: 10)),
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/features/mcp/mcp_panel.dart
git commit -m "feat(mcp): add Integrations panel UI"
```

---

### Task 13: Wire UI — Tab Bar and App Shell

**Files:**
- Modify: `lib/src/features/projects/tab_bar.dart`
- Modify: `lib/src/app.dart`

- [ ] **Step 1: Add onOpenIntegrations callback to ProjectTabBar**

In `tab_bar.dart`, add the new parameter:

```dart
// Add to class fields (after onOpenShortcuts):
  final VoidCallback onOpenIntegrations;

// Add to constructor required params:
  required this.onOpenIntegrations,
```

Wire the Integrations icon button (around line 155-159), change `onTap: () {}` to `onTap: onOpenIntegrations`.

Add an import for the MCP provider to show a status dot:
```dart
import '../mcp/mcp_provider.dart';
```

Replace the Integrations `_IconButton` block with a `Stack` that shows a green dot when the server is running:

```dart
          // Integrations icon with status dot
          Stack(
            children: [
              _IconButton(
                icon: Icons.extension_outlined,
                tooltip: 'Integrations',
                onTap: onOpenIntegrations,
                theme: theme,
              ),
              if (ref.watch(mcpServerProvider.select((s) => s.running)))
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.accentGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
```

- [ ] **Step 2: Wire the panel overlay in app.dart**

In `app.dart`, add the import:
```dart
import 'features/mcp/mcp_panel.dart';
```

Add the state variable (after `_shortcutsOpen`):
```dart
  bool _integrationsOpen = false;
```

In the `ProjectTabBar` constructor call, add:
```dart
                    onOpenIntegrations: () =>
                        setState(() => _integrationsOpen = true),
```

In the `builder:` `Stack.children`, add after the `_shortcutsOpen` block:
```dart
            if (_integrationsOpen)
              McpPanel(
                open: true,
                onClose: () => setState(() => _integrationsOpen = false),
              ),
```

- [ ] **Step 3: Verify the app compiles**

Run: `cd packages/dispatch_app && flutter build macos --debug 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add lib/src/features/projects/tab_bar.dart lib/src/app.dart
git commit -m "feat(mcp): wire Integrations button and panel overlay"
```

---

### Task 14: Auto-Start and Final Wiring

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Initialize MCP provider on startup**

In `main.dart`, add imports are not needed — the provider self-initializes via `build()`. However, we need to ensure the provider is read early so `_loadSettings()` fires.

In `app.dart`, in `_DispatchAppState.initState()`, after `ref.read(autoSaveProvider);` add:

```dart
      ref.read(mcpServerProvider);
```

Also add the import at the top of `app.dart`:
```dart
import 'features/mcp/mcp_provider.dart';
```

(This import may already exist from Task 13.)

- [ ] **Step 2: Verify the app compiles and starts**

Run: `cd packages/dispatch_app && flutter build macos --debug 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add lib/src/app.dart
git commit -m "feat(mcp): auto-initialize MCP provider on startup"
```

---

### Task 15: stdio Bridge Entry Point

**Files:**
- Create: `bin/dispatch_mcp_stdio.dart`

- [ ] **Step 1: Create the stdio bridge**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Standalone stdio-to-HTTP bridge for MCP.
///
/// This process reads JSON-RPC 2.0 messages from stdin, forwards them to
/// the running Dispatch app's HTTP server via loopback, and writes responses
/// to stdout.
///
/// Usage: dart run bin/dispatch_mcp_stdio.dart [--port PORT] [--token TOKEN]
void main(List<String> args) async {
  var port = 3900;
  String? token;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--port' && i + 1 < args.length) {
      port = int.parse(args[++i]);
    } else if (args[i] == '--token' && i + 1 < args.length) {
      token = args[++i];
    }
  }

  final baseUrl = 'http://localhost:$port/mcp';
  final client = HttpClient();

  // Read lines from stdin and forward to HTTP
  final lines = stdin
      .transform(const Utf8Decoder())
      .transform(const LineSplitter());

  await for (final line in lines) {
    if (line.trim().isEmpty) continue;

    try {
      final request = client.postUrl(Uri.parse(baseUrl));
      final httpRequest = await request;
      httpRequest.headers.set('content-type', 'application/json');
      if (token != null) {
        httpRequest.headers.set('authorization', 'Bearer $token');
      }
      httpRequest.write(line);
      final response = await httpRequest.close();
      final responseBody = await response.transform(const Utf8Decoder()).join();
      stdout.writeln(responseBody);
    } catch (e) {
      final errorResponse = jsonEncode({
        'jsonrpc': '2.0',
        'error': {'code': -32000, 'message': 'Bridge error: $e'},
        'id': null,
      });
      stdout.writeln(errorResponse);
    }
  }

  client.close();
}
```

- [ ] **Step 2: Commit**

```bash
git add bin/dispatch_mcp_stdio.dart
git commit -m "feat(mcp): add stdio bridge entry point for Claude Code"
```

---

### Task 16: Manual Integration Test

- [ ] **Step 1: Build and run the app**

Run: `cd packages/dispatch_app && flutter run -d macos`

- [ ] **Step 2: Test MCP server toggle**

1. Click the Integrations icon in the tab bar
2. Toggle the MCP server on
3. Verify the green status dot appears on the Integrations icon
4. Verify the connection URL is shown

- [ ] **Step 3: Test HTTP endpoint**

Run from another terminal:
```bash
curl -X POST http://localhost:3900/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"initialize","id":1}'
```
Expected: JSON response with protocolVersion and serverInfo

- [ ] **Step 4: Test tools/list**

```bash
curl -X POST http://localhost:3900/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":2}'
```
Expected: JSON response with all 14 tools listed

- [ ] **Step 5: Test list_projects**

```bash
curl -X POST http://localhost:3900/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list_projects","arguments":{}},"id":3}'
```
Expected: JSON response with project groups

- [ ] **Step 6: Test health endpoint**

```bash
curl http://localhost:3900/mcp/health
```
Expected: JSON with status "ok"

- [ ] **Step 7: Commit final state if all tests pass**

```bash
git add -A
git commit -m "feat(mcp): complete MCP server integration"
```
