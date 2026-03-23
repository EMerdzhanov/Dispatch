import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp_tools.dart';
import '../../projects/projects_provider.dart';
import '../../terminal/terminal_provider.dart';
import '../../terminal/session_registry.dart';
import '../../../core/models/terminal_entry.dart';
import '../../../core/models/split_node.dart';

/// Schedule a state modification outside Flutter's build phase.
Future<void> _deferStateChange(void Function() fn) async {
  await Future.delayed(Duration.zero);
  fn();
}

List<McpToolDefinition> orchestrateTools() => [
      McpToolDefinition(
        name: 'set_project_config',
        description:
            'Sets project-level configuration. '
            'auto_approve: when true, spawned AI agent terminals (claude, codex, gemini) '
            'will use permission-skipping flags. '
            'allowlist: glob patterns for allowed commands (e.g. "npm:*", "git:*").',
        inputSchema: {
          'type': 'object',
          'properties': {
            'projectId': {'type': 'string'},
            'auto_approve': {'type': 'boolean'},
            'allowlist': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Command patterns to auto-approve (e.g. ["npm:*", "git:*"])',
            },
          },
          'required': ['projectId'],
        },
        handler: _setProjectConfig,
      ),
      McpToolDefinition(
        name: 'get_project_config',
        description: 'Gets the current project-level configuration.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'projectId': {'type': 'string'},
          },
          'required': ['projectId'],
        },
        handler: _getProjectConfig,
      ),
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

  String? newId;
  await _deferStateChange(() {
    final before = ref.read(projectsProvider).groups.map((g) => g.id).toSet();
    ref.read(projectsProvider.notifier).addGroup(cwd, label);
    final after = ref.read(projectsProvider).groups;
    final newGroup = after.where((g) => !before.contains(g.id)).firstOrNull;
    newId = newGroup?.id;
  });
  return {'projectId': newId ?? ''};
}

Future<Map<String, dynamic>> _closeProject(Ref ref, Map<String, dynamic> params) async {
  final projectId = params['projectId'] as String?;
  if (projectId == null) throw ArgumentError('projectId is required');

  final state = ref.read(projectsProvider);
  final group = state.groups.where((g) => g.id == projectId).firstOrNull;
  if (group == null) return {'success': false, 'error': 'Project not found'};

  // Kill all terminals in the group
  final terminalIds = [...group.terminalIds];
  for (final terminalId in terminalIds) {
    final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
    pty?.kill();
  }
  await _deferStateChange(() {
    for (final terminalId in terminalIds) {
      ref.read(terminalsProvider.notifier).removeTerminal(terminalId);
    }
    ref.read(projectsProvider.notifier).removeGroup(projectId);
  });
  return {'success': true};
}

Future<Map<String, dynamic>> _setActiveProject(Ref ref, Map<String, dynamic> params) async {
  final projectId = params['projectId'] as String?;
  if (projectId == null) throw ArgumentError('projectId is required');

  await _deferStateChange(() {
    ref.read(projectsProvider.notifier).setActiveGroup(projectId);
  });
  return {'success': true};
}

Future<Map<String, dynamic>> _setActiveTerminal(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminalId'] as String?;
  if (terminalId == null) throw ArgumentError('terminalId is required');

  await _deferStateChange(() {
    ref.read(terminalsProvider.notifier).setActiveTerminal(terminalId);
  });
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

    await _deferStateChange(() {
      ref.read(terminalsProvider.notifier).addTerminal(
            groupId,
            TerminalEntry(
              id: targetTerminalId,
              command: command,
              cwd: cwd,
              status: TerminalStatus.running,
            ),
          );
      ref.read(terminalsProvider.notifier).setActiveTerminal(targetTerminalId);
    });
  }

  // Build split layout
  await _deferStateChange(() {
    final projectsState = ref.read(projectsProvider);
    final group = projectsState.groups
        .where((g) => g.id == projectsState.activeGroupId)
        .firstOrNull;
    if (group == null) return;

    final layout = SplitNode.buildEqualSplit(group.terminalIds, direction);
    ref.read(projectsProvider.notifier).setGroupSplitLayout(group.id, layout);
  });

  return {'terminalId': targetTerminalId};
}

// ── Project config persistence ──────────────────────────────────────────

String _configDir() {
  final home = Platform.environment['HOME'] ?? '/tmp';
  return '$home/.config/dispatch';
}

Future<Map<String, dynamic>> _readProjectConfig(String projectId) async {
  final file = File('${_configDir()}/project_configs/$projectId.json');
  if (!await file.exists()) return {};
  try {
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

Future<void> _writeProjectConfig(String projectId, Map<String, dynamic> config) async {
  final file = File('${_configDir()}/project_configs/$projectId.json');
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(config));
}

Future<Map<String, dynamic>> _setProjectConfig(Ref ref, Map<String, dynamic> params) async {
  final projectId = params['projectId'] as String?;
  if (projectId == null) throw ArgumentError('projectId is required');

  final config = await _readProjectConfig(projectId);
  if (params.containsKey('auto_approve')) {
    config['auto_approve'] = params['auto_approve'] as bool;
  }
  if (params.containsKey('allowlist')) {
    config['allowlist'] = params['allowlist'];
  }
  await _writeProjectConfig(projectId, config);
  return {'success': true, 'config': config};
}

Future<Map<String, dynamic>> _getProjectConfig(Ref ref, Map<String, dynamic> params) async {
  final projectId = params['projectId'] as String?;
  if (projectId == null) throw ArgumentError('projectId is required');
  return await _readProjectConfig(projectId);
}
