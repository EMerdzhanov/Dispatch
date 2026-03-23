import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp_tools.dart';
import '../../projects/projects_provider.dart';

/// MCP-exposed code search tools — mirrors the Alfa tools but accessible
/// from external agents via the MCP server.
List<McpToolDefinition> codeSearchTools() => [
      McpToolDefinition(
        name: 'search_codebase',
        description:
            'Search all code files in the active project for a text or regex pattern. '
            'Uses ripgrep if available, falls back to grep. '
            'Returns matching lines with file path and line number.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': 'Text or regex to search for'},
            'file_glob': {
              'type': 'string',
              'description': 'Optional glob filter, e.g. "*.dart" or "*.ts"',
            },
            'case_sensitive': {'type': 'boolean'},
            'max_results': {'type': 'integer', 'description': 'Default 50'},
            'cwd': {
              'type': 'string',
              'description': 'Override project directory (defaults to active)',
            },
          },
          'required': ['query'],
        },
        handler: _searchCodebase,
      ),
      McpToolDefinition(
        name: 'get_symbol',
        description:
            'Find where a function, class, or variable is defined in the codebase.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'kind': {
              'type': 'string',
              'enum': ['any', 'class', 'function', 'const', 'variable'],
            },
            'cwd': {'type': 'string'},
          },
          'required': ['name'],
        },
        handler: _getSymbol,
      ),
      McpToolDefinition(
        name: 'get_references',
        description:
            'Find all places in the codebase that reference a symbol. '
            'Useful before refactoring to understand blast radius.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'exclude_definition': {'type': 'boolean'},
            'cwd': {'type': 'string'},
          },
          'required': ['name'],
        },
        handler: _getReferences,
      ),
    ];

// ---------------------------------------------------------------------------
// Handlers (duplicated from alfa/tools/code_tools.dart to avoid circular deps)
// ---------------------------------------------------------------------------

Future<Map<String, dynamic>> _searchCodebase(
    Ref ref, Map<String, dynamic> params) async {
  final query = params['query'] as String;
  final fileGlob = params['file_glob'] as String?;
  final caseSensitive = (params['case_sensitive'] as bool?) ?? false;
  final maxResults = (params['max_results'] as int?) ?? 50;
  final cwd = (params['cwd'] as String?) ?? _activeCwd(ref);
  if (cwd == null) return {'error': 'No active project'};

  final rgAvailable = await _commandExists('rg');
  List<String> args;
  String executable;

  if (rgAvailable) {
    executable = 'rg';
    args = [
      '--line-number', '--no-heading',
      if (!caseSensitive) '--ignore-case',
      if (fileGlob != null) ...['-g', fileGlob],
      '--max-filesize', '1M',
      query, cwd,
    ];
  } else {
    executable = 'grep';
    args = [
      '-rn',
      '--include=${fileGlob ?? '*'}',
      if (!caseSensitive) '-i',
      query, cwd,
    ];
  }

  try {
    final result = await Process.run(executable, args, workingDirectory: cwd)
        .timeout(const Duration(seconds: 10));
    final stdout = (result.stdout as String).trim();
    if (stdout.isEmpty) return {'matches': [], 'count': 0};
    final lines = stdout.split('\n');
    final matches = lines
        .take(maxResults)
        .map((l) => _rel(l, cwd))
        .toList();
    return {'matches': matches, 'count': matches.length, 'truncated': lines.length > maxResults};
  } catch (e) {
    return {'error': '$e'};
  }
}

Future<Map<String, dynamic>> _getSymbol(
    Ref ref, Map<String, dynamic> params) async {
  final name = params['name'] as String;
  final kind = (params['kind'] as String?) ?? 'any';
  final cwd = (params['cwd'] as String?) ?? _activeCwd(ref);
  if (cwd == null) return {'error': 'No active project'};

  final escaped = RegExp.escape(name);
  final patterns = kind == 'class'
      ? ['class\\s+$escaped\\b', 'interface\\s+$escaped\\b', 'struct\\s+$escaped\\b']
      : kind == 'function'
          ? ['(function|def|fn)\\s+$escaped\\s*\\(', '(void|Future|String|int)\\s+$escaped\\s*\\(']
          : [
              'class\\s+$escaped\\b',
              '(function|def|fn)\\s+$escaped\\s*\\(',
              '(const|final|let|var)\\s+$escaped\\s*=',
              '(void|Future|String|int)\\s+$escaped\\s*\\(',
            ];

  final rgAvailable = await _commandExists('rg');
  final results = <String>[];

  for (final pattern in patterns) {
    try {
      final args = rgAvailable
          ? ['--line-number', '--no-heading', '-e', pattern, '--max-filesize', '1M', cwd]
          : ['-rn', '-E', pattern, cwd];
      final result = await Process.run(
              rgAvailable ? 'rg' : 'grep', args, workingDirectory: cwd)
          .timeout(const Duration(seconds: 5));
      final out = (result.stdout as String).trim();
      if (out.isNotEmpty) {
        results.addAll(out.split('\n').take(5).map((l) => _rel(l, cwd)));
      }
    } catch (_) {}
  }

  if (results.isEmpty) return {'symbol': name, 'found': false};
  final seen = <String>{};
  final deduped = results.where(seen.add).toList();
  return {'symbol': name, 'found': true, 'definitions': deduped};
}

Future<Map<String, dynamic>> _getReferences(
    Ref ref, Map<String, dynamic> params) async {
  final name = params['name'] as String;
  final excludeDef = (params['exclude_definition'] as bool?) ?? true;
  final cwd = (params['cwd'] as String?) ?? _activeCwd(ref);
  if (cwd == null) return {'error': 'No active project'};

  final rgAvailable = await _commandExists('rg');
  final args = rgAvailable
      ? ['--line-number', '--no-heading', '--max-filesize', '1M', '--word-regexp', name, cwd]
      : ['-rn', '-w', name, cwd];

  try {
    final result = await Process.run(
            rgAvailable ? 'rg' : 'grep', args, workingDirectory: cwd)
        .timeout(const Duration(seconds: 10));
    var lines = (result.stdout as String).trim().split('\n');
    if (excludeDef) {
      final defRe = RegExp(
          r'\b(class|function|def|fn|const|let|var|final|interface|struct)\s+' +
              RegExp.escape(name));
      lines = lines.where((l) => !defRe.hasMatch(l)).toList();
    }
    final refs = lines.take(80).map((l) => _rel(l, cwd)).toList();
    return {'symbol': name, 'references': refs, 'count': refs.length};
  } catch (e) {
    return {'error': '$e'};
  }
}

String? _activeCwd(Ref ref) {
  final state = ref.read(projectsProvider);
  return state.groups
      .where((g) => g.id == state.activeGroupId)
      .firstOrNull
      ?.cwd;
}

Future<bool> _commandExists(String cmd) async {
  try {
    final r = await Process.run('which', [cmd]).timeout(const Duration(seconds: 2));
    return r.exitCode == 0;
  } catch (_) {
    return false;
  }
}

String _rel(String line, String cwd) {
  final prefix = cwd.endsWith('/') ? cwd : '$cwd/';
  return line.startsWith(prefix) ? line.substring(prefix.length) : line;
}
