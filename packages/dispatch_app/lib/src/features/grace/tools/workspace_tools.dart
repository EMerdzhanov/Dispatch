import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grace_types.dart';
import '../tool_executor.dart';
import '../../projects/projects_provider.dart';
import '../../../persistence/auto_save.dart';

/// Tools for Grace to read/write Tasks, Notes, and Vault — the UI toolbox.
List<GraceToolEntry> workspaceTools() => [
      // ── Tasks ──
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'get_tasks',
          description:
              'Returns all tasks for the active project. '
              'Each task has: id, title, description, done.',
          inputSchema: {'type': 'object', 'properties': {}},
        ),
        handler: _getTasks,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'add_task',
          description:
              'Adds a task to the Tasks panel for the active project. '
              'Use this when the user mentions action items, bugs to fix, or work to do. '
              'Ask the user first: "Want me to add these as tasks?"',
          inputSchema: {
            'type': 'object',
            'properties': {
              'title': {'type': 'string', 'description': 'Task title'},
              'description': {
                'type': 'string',
                'description': 'Optional details',
              },
            },
            'required': ['title'],
          },
        ),
        handler: _addTask,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'complete_task',
          description: 'Marks a task as done by ID.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'id': {'type': 'integer', 'description': 'Task ID'},
            },
            'required': ['id'],
          },
        ),
        handler: _completeTask,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'update_task',
          description: 'Updates a task title and/or description by ID.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'id': {'type': 'integer', 'description': 'Task ID'},
              'title': {'type': 'string'},
              'description': {'type': 'string'},
            },
            'required': ['id'],
          },
        ),
        handler: _updateTask,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'delete_task',
          description: 'Deletes a task by ID.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'id': {'type': 'integer', 'description': 'Task ID'},
            },
            'required': ['id'],
          },
        ),
        handler: _deleteTask,
      ),

      // ── Notes ──
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'get_notes',
          description: 'Returns notes for the active project.',
          inputSchema: {'type': 'object', 'properties': {}},
        ),
        handler: _getNotes,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'update_notes',
          description:
              'Updates a project note. Can change title, body, or both. '
              'Use note_id to target a specific note (from get_notes), '
              'otherwise updates the first note. Read first with get_notes.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'note_id': {'type': 'integer', 'description': 'ID of the note to update (from get_notes). Defaults to first note.'},
              'title': {'type': 'string', 'description': 'New title for the note'},
              'content': {'type': 'string', 'description': 'New body content for the note'},
            },
          },
        ),
        handler: _updateNotes,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'append_notes',
          description:
              'Appends content to the project notes without overwriting.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'content': {'type': 'string', 'description': 'Content to append'},
            },
            'required': ['content'],
          },
        ),
        handler: _appendNotes,
      ),

      // ── Vault ──
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'get_vault_keys',
          description:
              'Returns vault key names for the active project. '
              'Does NOT return values — use get_vault_value for that. '
              'Only use when the task explicitly requires credentials.',
          inputSchema: {'type': 'object', 'properties': {}},
        ),
        handler: _getVaultKeys,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'get_vault_value',
          description:
              'Returns the value for a vault key. SENSITIVE — only use '
              'when explicitly asked for credentials or secrets.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'key': {'type': 'string', 'description': 'Vault key to retrieve'},
            },
            'required': ['key'],
          },
        ),
        handler: _getVaultValue,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'set_vault_value',
          description:
              'Stores or updates a key/value in the vault. SENSITIVE.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'key': {'type': 'string'},
              'value': {'type': 'string'},
            },
            'required': ['key', 'value'],
          },
        ),
        handler: _setVaultValue,
      ),
    ];

// ── Helpers ──

String _resolveCwd(Ref ref) {
  final state = ref.read(projectsProvider);
  final group = state.groups
      .where((g) => g.id == state.activeGroupId)
      .firstOrNull;
  final cwd = group?.cwd;
  if (cwd == null) throw StateError('No active project');
  return cwd;
}

// ── Task handlers ──

Future<Map<String, dynamic>> _getTasks(Ref ref, Map<String, dynamic> params) async {
  final cwd = _resolveCwd(ref);
  final db = ref.read(databaseProvider);
  final tasks = await db.tasksDao.getTasksForProject(cwd);
  return {
    'tasks': tasks.map((t) => {
      'id': t.id, 'title': t.title, 'description': t.description, 'done': t.done,
    }).toList(),
  };
}

Future<Map<String, dynamic>> _addTask(Ref ref, Map<String, dynamic> params) async {
  final title = params['title'] as String? ?? '';
  if (title.isEmpty) throw ArgumentError('title is required');
  final description = params['description'] as String? ?? '';
  final cwd = _resolveCwd(ref);
  final db = ref.read(databaseProvider);
  final id = await db.tasksDao.insertTask(projectCwd: cwd, title: title, description: description);
  return {'id': id, 'status': 'created'};
}

Future<Map<String, dynamic>> _completeTask(Ref ref, Map<String, dynamic> params) async {
  final id = params['id'] as int? ?? (params['id'] is String ? int.tryParse(params['id'] as String) : null);
  if (id == null) throw ArgumentError('id is required');
  final db = ref.read(databaseProvider);
  await db.tasksDao.markDone(id);
  return {'id': id, 'status': 'completed'};
}

Future<Map<String, dynamic>> _updateTask(Ref ref, Map<String, dynamic> params) async {
  final id = params['id'] as int? ?? (params['id'] is String ? int.tryParse(params['id'] as String) : null);
  if (id == null) throw ArgumentError('id is required');
  final title = params['title'] as String?;
  final description = params['description'] as String?;
  final db = ref.read(databaseProvider);
  await db.tasksDao.updateTask(id, title: title, description: description);
  return {'id': id, 'status': 'updated'};
}

Future<Map<String, dynamic>> _deleteTask(Ref ref, Map<String, dynamic> params) async {
  final id = params['id'] as int? ?? (params['id'] is String ? int.tryParse(params['id'] as String) : null);
  if (id == null) throw ArgumentError('id is required');
  final db = ref.read(databaseProvider);
  await db.tasksDao.deleteTask(id);
  return {'id': id, 'status': 'deleted'};
}

// ── Notes handlers ──

Future<Map<String, dynamic>> _getNotes(Ref ref, Map<String, dynamic> params) async {
  final cwd = _resolveCwd(ref);
  final db = ref.read(databaseProvider);
  final notes = await db.notesDao.getNotesForProject(cwd);
  return {
    'notes': notes.map((n) => {
      'id': n.id, 'title': n.title, 'body': n.body, 'updatedAt': n.updatedAt.toIso8601String(),
    }).toList(),
  };
}

Future<Map<String, dynamic>> _updateNotes(Ref ref, Map<String, dynamic> params) async {
  final title = params['title'] as String?;
  final content = params['content'] as String?;
  final noteId = params['note_id'] as int?;
  if (title == null && content == null) {
    throw ArgumentError('At least one of title or content is required');
  }
  final cwd = _resolveCwd(ref);
  final db = ref.read(databaseProvider);
  final notes = await db.notesDao.getNotesForProject(cwd);
  if (notes.isEmpty) {
    final id = await db.notesDao.insertNote(
      projectCwd: cwd,
      title: title ?? 'Notes',
      body: content ?? '',
    );
    return {'id': id, 'status': 'created'};
  }
  final target = noteId != null
      ? notes.firstWhere((n) => n.id == noteId, orElse: () => notes.first)
      : notes.first;
  await db.notesDao.updateNote(target.id, title: title, body: content);
  return {'id': target.id, 'status': 'updated', 'title': title ?? target.title};
}

Future<Map<String, dynamic>> _appendNotes(Ref ref, Map<String, dynamic> params) async {
  final content = params['content'] as String?;
  if (content == null) throw ArgumentError('content is required');
  final cwd = _resolveCwd(ref);
  final db = ref.read(databaseProvider);
  final notes = await db.notesDao.getNotesForProject(cwd);
  if (notes.isEmpty) {
    final id = await db.notesDao.insertNote(projectCwd: cwd, title: 'Notes', body: content);
    return {'id': id, 'status': 'created'};
  }
  final existing = notes.first.body;
  final newBody = existing.isEmpty ? content : '$existing\n$content';
  await db.notesDao.updateNote(notes.first.id, body: newBody);
  return {'id': notes.first.id, 'status': 'appended'};
}

// ── Vault handlers ──

Future<Map<String, dynamic>> _getVaultKeys(Ref ref, Map<String, dynamic> params) async {
  final cwd = _resolveCwd(ref);
  final db = ref.read(databaseProvider);
  final entries = await db.vaultDao.getEntriesForProject(cwd);
  return {'keys': entries.map((e) => e.label).toList()};
}

Future<Map<String, dynamic>> _getVaultValue(Ref ref, Map<String, dynamic> params) async {
  final key = params['key'] as String?;
  if (key == null || key.isEmpty) throw ArgumentError('key is required');
  final cwd = _resolveCwd(ref);
  final db = ref.read(databaseProvider);
  final entry = await db.vaultDao.getEntryByLabel(cwd, key);
  if (entry == null) throw StateError('Vault key not found: $key');
  return {'key': entry.label, 'value': entry.encryptedValue};
}

Future<Map<String, dynamic>> _setVaultValue(Ref ref, Map<String, dynamic> params) async {
  final key = params['key'] as String?;
  final value = params['value'] as String?;
  if (key == null || key.isEmpty) throw ArgumentError('key is required');
  if (value == null || value.isEmpty) throw ArgumentError('value is required');
  final cwd = _resolveCwd(ref);
  final db = ref.read(databaseProvider);
  final existing = await db.vaultDao.getEntryByLabel(cwd, key);
  if (existing != null) {
    await db.vaultDao.updateEntry(existing.id, encryptedValue: value);
    return {'key': key, 'status': 'updated'};
  }
  final id = await db.vaultDao.insertEntry(projectCwd: cwd, label: key, encryptedValue: value);
  return {'id': id, 'key': key, 'status': 'created'};
}
