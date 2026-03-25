import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grace_types.dart';
import '../tool_executor.dart';
import '../memory_retrieval.dart';
import '../claude_client.dart';
import '../../projects/projects_provider.dart';
import '../../../persistence/auto_save.dart';
import '../../../core/database/database.dart';

List<GraceToolEntry> graceMemoryTools(ClaudeClient? client) => [
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'save_memory',
          description:
              'Save a memory to the persistent memory system. '
              'Call after the user confirms they want something remembered. '
              'Categories: preference, decision, correction, context, workflow.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'content': {'type': 'string', 'description': 'The memory to save'},
              'category': {
                'type': 'string',
                'enum': ['preference', 'decision', 'correction', 'context', 'workflow'],
              },
              'tags': {'type': 'string', 'description': 'Comma-separated lowercase tags'},
              'projectCwd': {'type': 'string', 'description': 'Project scope (null = global)'},
              'pinned': {'type': 'boolean', 'description': 'Pin to always load (default false)'},
            },
            'required': ['content', 'category'],
          },
        ),
        handler: _saveMemory,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'recall_memories',
          description: 'Retrieve memories relevant to a given context.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'context': {'type': 'string', 'description': 'Context to match memories against'},
            },
            'required': ['context'],
          },
        ),
        handler: (ref, params) => _recallMemories(ref, params, client),
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'list_memories',
          description: 'List all memories, optionally filtered by category or project.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'category': {'type': 'string', 'description': 'Filter by category'},
              'projectCwd': {'type': 'string', 'description': 'Filter by project'},
            },
          },
        ),
        handler: _listMemories,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'delete_memory',
          description: 'Delete a memory by ID.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'id': {'type': 'integer', 'description': 'Memory ID'},
            },
            'required': ['id'],
          },
        ),
        handler: _deleteMemory,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'pin_memory',
          description: 'Pin a memory so it always loads in the system prompt.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'id': {'type': 'integer', 'description': 'Memory ID'},
            },
            'required': ['id'],
          },
        ),
        handler: _pinMemory,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'unpin_memory',
          description: 'Unpin a memory.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'id': {'type': 'integer', 'description': 'Memory ID'},
            },
            'required': ['id'],
          },
        ),
        handler: _unpinMemory,
      ),
    ];

String? _resolveCwd(Ref ref, Map<String, dynamic> params) {
  final explicit = params['projectCwd'] as String?;
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final state = ref.read(projectsProvider);
  final group = state.groups
      .where((g) => g.id == state.activeGroupId)
      .firstOrNull;
  return group?.cwd;
}

Future<Map<String, dynamic>> _saveMemory(Ref ref, Map<String, dynamic> params) async {
  final content = params['content'] as String? ?? '';
  final category = params['category'] as String? ?? 'preference';
  final tags = params['tags'] as String? ?? '';
  final pinned = params['pinned'] as bool? ?? false;
  final projectCwd = _resolveCwd(ref, params);

  if (content.isEmpty) throw ArgumentError('content is required');

  final db = ref.read(databaseProvider);

  // Duplicate check
  final existing = await db.graceMemoriesDao.findDuplicate(content, projectCwd);
  if (existing != null) {
    return {'id': existing.id, 'status': 'already_exists'};
  }

  final id = await db.graceMemoriesDao.insertMemory(
    GraceMemoriesCompanion.insert(
      category: category,
      content: content,
      source: 'grace_suggested',
      tags: Value(tags),
      pinned: Value(pinned),
      projectCwd: Value(projectCwd),
    ),
  );
  return {'id': id, 'status': 'saved'};
}

Future<Map<String, dynamic>> _recallMemories(
    Ref ref, Map<String, dynamic> params, ClaudeClient? client) async {
  final context = params['context'] as String? ?? '';
  final projectCwd = _resolveCwd(ref, params);
  final db = ref.read(databaseProvider);

  final candidates = await db.graceMemoriesDao.getCandidates(projectCwd);
  if (candidates.isEmpty) return {'memories': [], 'count': 0};

  if (client == null) {
    // No client — return all
    return {
      'memories': candidates.map((m) => _memoryToMap(m)).toList(),
      'count': candidates.length,
    };
  }

  final relevantIds = await scoreMemoryRelevance(client, context, candidates);
  final relevant = candidates.where((m) => relevantIds.contains(m.id)).toList();

  await db.graceMemoriesDao.touchRetrieved(relevantIds);

  return {
    'memories': relevant.map((m) => _memoryToMap(m)).toList(),
    'count': relevant.length,
  };
}

Future<Map<String, dynamic>> _listMemories(Ref ref, Map<String, dynamic> params) async {
  final category = params['category'] as String?;
  final projectCwd = _resolveCwd(ref, params);
  final db = ref.read(databaseProvider);

  var memories = await db.graceMemoriesDao.getForProject(projectCwd);
  if (category != null) {
    memories = memories.where((m) => m.category == category).toList();
  }

  return {
    'memories': memories.map((m) => _memoryToMap(m)).toList(),
    'count': memories.length,
  };
}

Future<Map<String, dynamic>> _deleteMemory(Ref ref, Map<String, dynamic> params) async {
  final id = params['id'] as int?;
  if (id == null) throw ArgumentError('id is required');
  final db = ref.read(databaseProvider);
  await db.graceMemoriesDao.deleteMemory(id);
  return {'id': id, 'status': 'deleted'};
}

Future<Map<String, dynamic>> _pinMemory(Ref ref, Map<String, dynamic> params) async {
  final id = params['id'] as int?;
  if (id == null) throw ArgumentError('id is required');
  final db = ref.read(databaseProvider);
  await db.graceMemoriesDao.setPinned(id, true);
  return {'id': id, 'status': 'pinned'};
}

Future<Map<String, dynamic>> _unpinMemory(Ref ref, Map<String, dynamic> params) async {
  final id = params['id'] as int?;
  if (id == null) throw ArgumentError('id is required');
  final db = ref.read(databaseProvider);
  await db.graceMemoriesDao.setPinned(id, false);
  return {'id': id, 'status': 'unpinned'};
}

Map<String, dynamic> _memoryToMap(GraceMemory m) => {
  'id': m.id,
  'content': m.content,
  'category': m.category,
  'tags': m.tags,
  'pinned': m.pinned,
  'projectCwd': m.projectCwd,
  'createdAt': m.createdAt.toIso8601String(),
};
