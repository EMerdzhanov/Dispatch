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
