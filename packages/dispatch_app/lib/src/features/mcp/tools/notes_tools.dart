import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp_tools.dart';
import '../../projects/projects_provider.dart';
import '../../../persistence/auto_save.dart';

List<McpToolDefinition> notesTools() => [
      McpToolDefinition(
        name: 'get_notes',
        description:
            'Returns all notes for the active project (or specified cwd). '
            'Each note has: id, title, body, updatedAt.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'projectCwd': {
              'type': 'string',
              'description':
                  'Working directory to scope notes to. Defaults to active project.',
            },
          },
        },
        handler: _getNotes,
      ),
      McpToolDefinition(
        name: 'update_notes',
        description:
            'Updates a project note. Can change title, body, or both. '
            'Use note_id to target a specific note, otherwise updates the first.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'note_id': {'type': 'integer', 'description': 'ID of the note to update. Defaults to first note.'},
            'title': {'type': 'string', 'description': 'New title for the note'},
            'content': {'type': 'string', 'description': 'New body content for the note'},
            'projectCwd': {
              'type': 'string',
              'description': 'Working directory. Defaults to active project.',
            },
          },
        },
        handler: _updateNotes,
      ),
      McpToolDefinition(
        name: 'append_notes',
        description:
            'Appends content to the first note for the active project '
            'without overwriting existing content. Creates a new note if none exists.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'content': {
              'type': 'string',
              'description': 'Content to append',
            },
            'projectCwd': {
              'type': 'string',
              'description': 'Working directory. Defaults to active project.',
            },
          },
          'required': ['content'],
        },
        handler: _appendNotes,
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

Future<Map<String, dynamic>> _getNotes(
    Ref ref, Map<String, dynamic> params) async {
  final cwd = _resolveCwd(ref, params);
  final db = ref.read(databaseProvider);
  final notes = await db.notesDao.getNotesForProject(cwd);
  return {
    'notes': notes
        .map((n) => {
              'id': n.id,
              'title': n.title,
              'body': n.body,
              'updatedAt': n.updatedAt.toIso8601String(),
            })
        .toList(),
  };
}

Future<Map<String, dynamic>> _updateNotes(
    Ref ref, Map<String, dynamic> params) async {
  final title = params['title'] as String?;
  final content = params['content'] as String?;
  final noteId = params['note_id'] as int?;
  if (title == null && content == null) {
    throw ArgumentError('At least one of title or content is required');
  }

  final cwd = _resolveCwd(ref, params);
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

Future<Map<String, dynamic>> _appendNotes(
    Ref ref, Map<String, dynamic> params) async {
  final content = params['content'] as String?;
  if (content == null) throw ArgumentError('content is required');

  final cwd = _resolveCwd(ref, params);
  final db = ref.read(databaseProvider);
  final notes = await db.notesDao.getNotesForProject(cwd);

  if (notes.isEmpty) {
    final id = await db.notesDao.insertNote(
      projectCwd: cwd,
      title: 'Notes',
      body: content,
    );
    return {'id': id, 'status': 'created'};
  }

  final existing = notes.first.body;
  final newBody = existing.isEmpty ? content : '$existing\n$content';
  await db.notesDao.updateNote(notes.first.id, body: newBody);
  return {'id': notes.first.id, 'status': 'appended'};
}
