import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grace_types.dart';
import '../tool_executor.dart';
import '../../projects/projects_provider.dart';
import '../../terminal/terminal_provider.dart';
import '../../terminal/session_registry.dart';

List<GraceToolEntry> projectTools() => [
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'create_project',
          description: 'Creates a new project group. Idempotent: returns existing group if one with the same cwd exists.',
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
      GraceToolEntry(
        definition: const GraceToolDefinition(
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
      GraceToolEntry(
        definition: const GraceToolDefinition(
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

Future<Map<String, dynamic>> _createProject(Ref ref, Map<String, dynamic> params) async {
  final label = params['label'] as String;
  final cwd = params['cwd'] as String;
  final state = ref.read(projectsProvider);
  final existing = state.groups.where((g) => g.cwd == cwd).firstOrNull;
  if (existing != null) return {'project_id': existing.id, 'existing': true};
  await Future.delayed(Duration.zero);
  final before = ref.read(projectsProvider).groups.map((g) => g.id).toSet();
  ref.read(projectsProvider.notifier).addGroup(cwd, label);
  final after = ref.read(projectsProvider).groups;
  final newGroup = after.where((g) => !before.contains(g.id)).firstOrNull;
  return {'project_id': newGroup?.id ?? '', 'existing': false};
}

Future<Map<String, dynamic>> _closeProject(Ref ref, Map<String, dynamic> params) async {
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

Future<Map<String, dynamic>> _listProjects(Ref ref, Map<String, dynamic> params) async {
  final state = ref.read(projectsProvider);
  final list = state.groups.map((g) => {
        'id': g.id, 'label': g.label, 'cwd': g.cwd,
        'terminal_count': g.terminalIds.length,
        'is_active': g.id == state.activeGroupId,
      }).toList();
  return {'projects': list, 'count': list.length};
}
