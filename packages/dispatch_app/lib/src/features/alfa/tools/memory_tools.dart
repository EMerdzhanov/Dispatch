import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alfa_types.dart';
import '../tool_executor.dart';
import '../../../persistence/auto_save.dart';
import '../../../core/database/database.dart';

List<AlfaToolEntry> memoryTools() => [
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'save_decision',
          description: 'Logs a decision to the database for future reference. Record what you did, whether it worked, and relevant tags.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'project_cwd': {'type': 'string'},
              'summary': {'type': 'string', 'description': 'What was decided/done'},
              'outcome': {'type': 'string', 'enum': ['success', 'failure', 'partial']},
              'detail': {'type': 'string', 'description': 'Optional longer explanation'},
              'tags': {'type': 'array', 'items': {'type': 'string'}, 'description': 'Categorization tags'},
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

Future<Map<String, dynamic>> _saveDecision(Ref ref, Map<String, dynamic> params) async {
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

Future<Map<String, dynamic>> _searchDecisions(Ref ref, Map<String, dynamic> params) async {
  final db = ref.read(databaseProvider);
  final query = params['query'] as String;
  final projectCwd = params['project_cwd'] as String?;
  final results = await db.alfaDecisionsDao.search(query, projectCwd: projectCwd);
  return {
    'decisions': results.map((d) => {
      'id': d.id, 'summary': d.summary, 'outcome': d.outcome, 'detail': d.detail,
      'tags': d.tags, 'project_cwd': d.projectCwd, 'created_at': d.createdAt.toIso8601String(),
    }).toList(),
    'count': results.length,
  };
}
