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
