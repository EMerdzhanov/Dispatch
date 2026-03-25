import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grace_types.dart';
import '../tool_executor.dart';
import '../../projects/projects_provider.dart';

List<GraceToolEntry> codeTools() => [
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'search_codebase',
          description:
              'Search all code files in the active project for a text pattern. '
              'Uses ripgrep (rg) if available, falls back to grep. '
              'Returns matching lines with file path and line number. '
              'Use to find usages, understand what calls what, or locate '
              'where a concept lives in the codebase.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'Text or regex pattern to search for',
              },
              'file_glob': {
                'type': 'string',
                'description':
                    'Optional glob to restrict search (e.g. "*.dart", "*.ts"). '
                    'Defaults to all code files.',
              },
              'case_sensitive': {
                'type': 'boolean',
                'description': 'Default false (case-insensitive search)',
              },
              'max_results': {
                'type': 'integer',
                'description': 'Max number of matching lines to return (default 50)',
              },
            },
            'required': ['query'],
          },
        ),
        handler: _searchCodebase,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'get_symbol',
          description:
              'Find where a function, class, or variable is defined in the codebase. '
              'Searches for definition patterns like "class Name", "function name(", '
              '"def name(", "const name =", etc. Returns the file and line number.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'name': {
                'type': 'string',
                'description': 'Symbol name to find (function, class, variable, etc.)',
              },
              'kind': {
                'type': 'string',
                'enum': ['any', 'class', 'function', 'const', 'variable'],
                'description': 'Kind of symbol. Default: any',
              },
            },
            'required': ['name'],
          },
        ),
        handler: _getSymbol,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'get_references',
          description:
              'Find all places in the codebase that reference (call or import) a symbol. '
              'Useful for understanding the blast radius of a change before making it.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'name': {
                'type': 'string',
                'description': 'Symbol name to find references for',
              },
              'exclude_definition': {
                'type': 'boolean',
                'description':
                    'If true, try to exclude the definition line (default true)',
              },
            },
            'required': ['name'],
          },
        ),
        handler: _getReferences,
      ),
    ];

Future<Map<String, dynamic>> _searchCodebase(
    Ref ref, Map<String, dynamic> params) async {
  final query = params['query'] as String;
  final fileGlob = params['file_glob'] as String?;
  final caseSensitive = (params['case_sensitive'] as bool?) ?? false;
  final maxResults = (params['max_results'] as int?) ?? 50;

  final cwd = _activeCwd(ref);
  if (cwd == null) return {'error': 'No active project'};

  final rgAvailable = await _commandExists('rg');
  List<String> args;
  String executable;

  if (rgAvailable) {
    executable = 'rg';
    args = [
      '--line-number',
      '--no-heading',
      if (!caseSensitive) '--ignore-case',
      if (fileGlob != null) ...['-g', fileGlob],
      '--max-filesize', '1M',
      query,
      cwd,
    ];
  } else {
    executable = 'grep';
    args = [
      '-rn',
      '--include=${fileGlob ?? '*'}',
      if (!caseSensitive) '-i',
      query,
      cwd,
    ];
  }

  try {
    final result = await Process.run(
      executable,
      args,
      workingDirectory: cwd,
    ).timeout(const Duration(seconds: 10));

    final stdout = (result.stdout as String).trim();
    if (stdout.isEmpty) return {'matches': [], 'count': 0, 'query': query};

    final lines = stdout.split('\n');
    final matches = lines.take(maxResults).map((l) => _rel(l, cwd)).toList();

    return {
      'matches': matches,
      'count': matches.length,
      'total_found': lines.length,
      'truncated': lines.length > maxResults,
      'query': query,
    };
  } on TimeoutException {
    return {'error': 'Search timed out — try a more specific query', 'query': query};
  } catch (e) {
    return {'error': 'Search failed: $e', 'query': query};
  }
}

Future<Map<String, dynamic>> _getSymbol(
    Ref ref, Map<String, dynamic> params) async {
  final name = params['name'] as String;
  final kind = (params['kind'] as String?) ?? 'any';

  final cwd = _activeCwd(ref);
  if (cwd == null) return {'error': 'No active project'};

  final patterns = _buildDefinitionPatterns(name, kind);
  final rgAvailable = await _commandExists('rg');
  final results = <Map<String, dynamic>>[];

  for (final pattern in patterns) {
    List<String> args;
    String executable;

    if (rgAvailable) {
      executable = 'rg';
      args = [
        '--line-number', '--no-heading', '--max-count', '1',
        '-e', pattern, '--max-filesize', '1M', cwd,
      ];
    } else {
      executable = 'grep';
      args = ['-rn', '-E', pattern, cwd];
    }

    try {
      final result = await Process.run(executable, args, workingDirectory: cwd)
          .timeout(const Duration(seconds: 8));
      final stdout = (result.stdout as String).trim();
      if (stdout.isNotEmpty) {
        for (final line in stdout.split('\n').take(10)) {
          results.add({'match': _rel(line, cwd), 'pattern': pattern});
        }
      }
    } catch (_) {}
  }

  if (results.isEmpty) return {'symbol': name, 'found': false};
  final seen = <String>{};
  final deduped = results.where((r) => seen.add(r['match'] as String)).toList();
  return {'symbol': name, 'found': true, 'definitions': deduped};
}

List<String> _buildDefinitionPatterns(String name, String kind) {
  final e = RegExp.escape(name);
  if (kind == 'class') {
    return ['class\\s+$e\\b', 'interface\\s+$e\\b', 'struct\\s+$e\\b'];
  }
  if (kind == 'function') {
    return [
      '(function|def|fn)\\s+$e\\s*\\(',
      '(void|Future|String|int)\\s+$e\\s*\\(',
      '(const|let|var)\\s+$e\\s*=\\s*(async\\s*)?\\(',
    ];
  }
  if (kind == 'const') return ['(const|final)\\s+$e\\s*=', 'const\\s+$e\\b'];
  if (kind == 'variable') return ['(var|let|late|final)\\s+$e\\s*[=;]'];

  return [
    'class\\s+$e\\b',
    '(void|Future|String|int|bool|Map|List|dynamic)\\s+$e\\s*\\(',
    '(final|const|var|late)\\s+$e\\s*=',
    '(export\\s+)?(class|interface|type|enum)\\s+$e\\b',
    '(export\\s+)?(function|const|let|var)\\s+$e\\b',
    '(def|class)\\s+$e\\s*[\\(:]',
    '(fn|struct|enum|trait|type|const|let)\\s+$e\\b',
  ];
}

Future<Map<String, dynamic>> _getReferences(
    Ref ref, Map<String, dynamic> params) async {
  final name = params['name'] as String;
  final excludeDefinition = (params['exclude_definition'] as bool?) ?? true;

  final cwd = _activeCwd(ref);
  if (cwd == null) return {'error': 'No active project'};

  final rgAvailable = await _commandExists('rg');
  final args = rgAvailable
      ? ['--line-number', '--no-heading', '--max-filesize', '1M', '--word-regexp', name, cwd]
      : ['-rn', '-w', name, cwd];

  try {
    final result = await Process.run(
      rgAvailable ? 'rg' : 'grep',
      args,
      workingDirectory: cwd,
    ).timeout(const Duration(seconds: 10));

    final stdout = (result.stdout as String).trim();
    if (stdout.isEmpty) return {'symbol': name, 'references': [], 'count': 0};

    var lines = stdout.split('\n');

    if (excludeDefinition) {
      final defRe = [
        RegExp('\\b(class|function|def|fn|const|let|var|final|interface|struct)\\s+${RegExp.escape(name)}'),
        RegExp('\\b(void|Future|String|int|bool)\\s+${RegExp.escape(name)}\\s*\\('),
      ];
      lines = lines.where((l) => !defRe.any((p) => p.hasMatch(l))).toList();
    }

    const maxRefs = 80;
    final references = lines.take(maxRefs).map((l) => _rel(l, cwd)).toList();

    return {
      'symbol': name,
      'references': references,
      'count': references.length,
      'total_found': lines.length,
      'truncated': lines.length > maxRefs,
    };
  } on TimeoutException {
    return {'error': 'Reference search timed out', 'symbol': name};
  } catch (e) {
    return {'error': 'Reference search failed: $e', 'symbol': name};
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
