import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp_tools.dart';
import '../../projects/projects_provider.dart';
import '../../grace/grace_provider.dart';
import '../../../persistence/auto_save.dart';

List<McpToolDefinition> tasksTools() => [
      McpToolDefinition(
        name: 'get_tasks',
        description:
            'Returns all tasks for the active project (or specified cwd). '
            'Each task has: id, title, description, done, createdAt.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'projectCwd': {
              'type': 'string',
              'description':
                  'Working directory to scope tasks to. Defaults to active project.',
            },
          },
        },
        handler: _getTasks,
      ),
      McpToolDefinition(
        name: 'add_task',
        description: 'Adds a task to the active project.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Task title'},
            'description': {
              'type': 'string',
              'description': 'Optional task description',
            },
          },
          'required': ['title'],
        },
        handler: _addTask,
      ),
      McpToolDefinition(
        name: 'complete_task',
        description: 'Marks a task as done.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'id': {'type': 'integer', 'description': 'Task ID'},
          },
          'required': ['id'],
        },
        handler: _completeTask,
      ),
      McpToolDefinition(
        name: 'delete_task',
        description: 'Deletes a task.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'id': {'type': 'integer', 'description': 'Task ID'},
          },
          'required': ['id'],
        },
        handler: _deleteTask,
      ),
      McpToolDefinition(
        name: 'update_task',
        description: 'Updates title and/or description of a task.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'id': {'type': 'integer', 'description': 'Task ID'},
            'title': {'type': 'string', 'description': 'New title'},
            'description': {
              'type': 'string',
              'description': 'New description',
            },
          },
          'required': ['id'],
        },
        handler: _updateTask,
      ),
    ];

String _resolveCwd(Ref ref, Map<String, dynamic> params) {
  final explicit = params['projectCwd'] as String?;
  if (explicit != null && explicit.isNotEmpty) return explicit;

  final state = ref.read(projectsProvider);
  final group = state.groups
      .where((g) => g.id == state.activeGroupId)
      .firstOrNull;
  final cwd = group?.cwd;
  if (cwd == null) throw StateError('No active project');
  return cwd;
}

Future<Map<String, dynamic>> _getTasks(
    Ref ref, Map<String, dynamic> params) async {
  final cwd = _resolveCwd(ref, params);
  final db = ref.read(databaseProvider);
  final tasks = await db.tasksDao.getTasksForProject(cwd);
  return {
    'tasks': tasks
        .map((t) => {
              'id': t.id,
              'title': t.title,
              'description': t.description,
              'done': t.done,
            })
        .toList(),
  };
}

Future<Map<String, dynamic>> _addTask(
    Ref ref, Map<String, dynamic> params) async {
  final title = params['title'] as String?;
  if (title == null || title.isEmpty) throw ArgumentError('title is required');

  final description = params['description'] as String? ?? '';
  final cwd = _resolveCwd(ref, params);
  final db = ref.read(databaseProvider);

  final id = await db.tasksDao.insertTask(
    projectCwd: cwd,
    title: title,
    description: description,
  );

  // [GRACE] prefix detection — notify Grace orchestrator
  if (title.toLowerCase().startsWith('[grace]')) {
    ref.read(graceProvider.notifier).injectTask(title, description);
  }

  return {'id': id, 'status': 'created'};
}

Future<Map<String, dynamic>> _completeTask(
    Ref ref, Map<String, dynamic> params) async {
  final id = params['id'] as int?;
  if (id == null) throw ArgumentError('id is required');

  final db = ref.read(databaseProvider);
  await db.tasksDao.markDone(id);
  return {'id': id, 'status': 'completed'};
}

Future<Map<String, dynamic>> _deleteTask(
    Ref ref, Map<String, dynamic> params) async {
  final id = params['id'] as int?;
  if (id == null) throw ArgumentError('id is required');

  final db = ref.read(databaseProvider);
  await db.tasksDao.deleteTask(id);
  return {'id': id, 'status': 'deleted'};
}

Future<Map<String, dynamic>> _updateTask(
    Ref ref, Map<String, dynamic> params) async {
  final id = params['id'] as int?;
  if (id == null) throw ArgumentError('id is required');

  final title = params['title'] as String?;
  final description = params['description'] as String?;
  if (title == null && description == null) {
    throw ArgumentError('At least one of title or description is required');
  }

  final db = ref.read(databaseProvider);
  await db.tasksDao.updateTask(id, title: title, description: description);
  return {'id': id, 'status': 'updated'};
}
