import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../persistence/auto_save.dart';
import '../mcp_tools.dart';
import '../../projects/projects_provider.dart';
import '../../grace/default_identity.dart';

List<McpToolDefinition> memoryTools() => [
      McpToolDefinition(
        name: 'read_memory',
        description:
            'Reads Grace\'s persistent memory file (~/.config/dispatch/grace/memory.md). '
            'Contains user preferences, communication style, technical preferences, '
            'and known context that persists across sessions.',
        inputSchema: {'type': 'object', 'properties': {}},
        handler: _readMemory,
      ),
      McpToolDefinition(
        name: 'update_memory',
        description:
            'Overwrites Grace\'s persistent memory file. Read first with read_memory, '
            'modify the content, then write back the full content. '
            'Use this to record user preferences, corrections, and learned context.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'content': {
              'type': 'string',
              'description': 'Full markdown content to write to memory.md',
            },
          },
          'required': ['content'],
        },
        handler: _updateMemory,
      ),
      McpToolDefinition(
        name: 'read_project_knowledge',
        description:
            'Reads the project knowledge file for a specific project. '
            'Contains tech stack, architecture, conventions, known issues, '
            'and recent decisions. Auto-resolves to active project if projectCwd is omitted.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'projectCwd': {
              'type': 'string',
              'description':
                  'Working directory of the project. Defaults to active project.',
            },
          },
        },
        handler: _readProjectKnowledge,
      ),
      McpToolDefinition(
        name: 'update_project_knowledge',
        description:
            'Overwrites the project knowledge file. Read first with read_project_knowledge, '
            'modify, then write back. Use after architectural decisions, tech stack changes, '
            'or convention updates.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'content': {
              'type': 'string',
              'description': 'Full markdown content for the project file',
            },
            'projectCwd': {
              'type': 'string',
              'description':
                  'Working directory of the project. Defaults to active project.',
            },
          },
          'required': ['content'],
        },
        handler: _updateProjectKnowledge,
      ),
      McpToolDefinition(
        name: 'append_log',
        description:
            'Appends a timestamped entry to Grace\'s log file. '
            'Use for decisions, task completions, errors, and significant events. '
            'Automatically prunes oldest entries when file exceeds 500 lines.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'entry': {
              'type': 'string',
              'description': 'Log entry text (timestamp is added automatically)',
            },
          },
          'required': ['entry'],
        },
        handler: _appendLog,
      ),
      McpToolDefinition(
        name: 'read_log',
        description:
            'Reads the last N entries from Grace\'s log file. '
            'Default: 20 lines.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'lines': {
              'type': 'integer',
              'description': 'Number of recent log lines to return (default 20)',
            },
          },
        },
        handler: _readLog,
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

Future<Map<String, dynamic>> _readMemory(
    Ref ref, Map<String, dynamic> params) async {
  final db = ref.read(databaseProvider);
  final pinned = await db.graceMemoriesDao.getPinned();
  final recent = await db.graceMemoriesDao.getCandidates(null, limit: 20);

  final sections = <String>[];
  if (pinned.isNotEmpty) {
    sections.add(
        '## Pinned\n${pinned.map((m) => '- [${m.category}] ${m.content}').join('\n')}');
  }
  if (recent.isNotEmpty) {
    sections.add(
        '## Recent\n${recent.map((m) => '- [${m.category}] ${m.content}').join('\n')}');
  }

  return {
    'content': sections.isEmpty ? 'No memories stored.' : sections.join('\n\n'),
    'pinned_count': pinned.length,
    'total_count': recent.length,
  };
}

Future<Map<String, dynamic>> _updateMemory(
    Ref ref, Map<String, dynamic> params) async {
  final content = params['content'] as String?;
  if (content == null || content.isEmpty) {
    throw ArgumentError('content is required');
  }
  final db = ref.read(databaseProvider);

  final existing = await db.graceMemoriesDao.findDuplicate(content, null);
  if (existing != null) {
    return {'id': existing.id, 'status': 'already_exists'};
  }

  final id = await db.graceMemoriesDao.insertMemory(
    GraceMemoriesCompanion.insert(
      category: 'preference',
      content: content,
      source: 'user_explicit',
    ),
  );
  return {'id': id, 'status': 'saved'};
}

Future<Map<String, dynamic>> _readProjectKnowledge(
    Ref ref, Map<String, dynamic> params) async {
  final cwd = _resolveCwd(ref, params);
  final path = '${graceDir()}/projects/${slugifyPath(cwd)}.md';
  final content = await loadFile(path);
  return {
    'content': content,
    'exists': content.isNotEmpty,
    'projectCwd': cwd,
  };
}

Future<Map<String, dynamic>> _updateProjectKnowledge(
    Ref ref, Map<String, dynamic> params) async {
  final content = params['content'] as String?;
  if (content == null || content.isEmpty) {
    throw ArgumentError('content is required');
  }
  final cwd = _resolveCwd(ref, params);
  final path = '${graceDir()}/projects/${slugifyPath(cwd)}.md';
  await writeFile(path, content);
  return {'status': 'updated', 'path': path, 'projectCwd': cwd};
}

Future<Map<String, dynamic>> _appendLog(
    Ref ref, Map<String, dynamic> params) async {
  final entry = params['entry'] as String?;
  if (entry == null || entry.isEmpty) {
    throw ArgumentError('entry is required');
  }

  final logPath = '${graceDir()}/log.md';
  final timestamp = DateTime.now().toUtc().toIso8601String();
  final line = '- [$timestamp] $entry\n';

  final file = File(logPath);
  String existing = '';
  if (await file.exists()) {
    existing = await file.readAsString();
  }

  final newContent = line + existing;

  // Prune to 500 lines max
  final lines = newContent.split('\n');
  final pruned = lines.sublist(0, min(lines.length, 500)).join('\n');
  await writeFile(logPath, pruned);

  return {'status': 'appended', 'timestamp': timestamp};
}

Future<Map<String, dynamic>> _readLog(
    Ref ref, Map<String, dynamic> params) async {
  final lineCount = (params['lines'] as int?) ?? 20;
  final logPath = '${graceDir()}/log.md';
  final content = await loadFile(logPath);

  if (content.isEmpty) {
    return {'entries': <String>[], 'count': 0};
  }

  final allLines = content
      .split('\n')
      .where((l) => l.startsWith('- ['))
      .take(lineCount)
      .toList();

  return {
    'entries': allLines,
    'count': allLines.length,
  };
}
