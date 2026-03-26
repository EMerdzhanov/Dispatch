import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grace_types.dart';
import '../tool_executor.dart';
import '../../projects/projects_provider.dart';

const _maxOutput = 10000;

List<GraceToolEntry> gitTools() => [
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'git_status',
          description:
              'Run git status --porcelain in a project directory. '
              'Returns parsed list of changed files with their status codes '
              '(M, A, D, ??, etc).',
          inputSchema: {
            'type': 'object',
            'properties': {
              'cwd': {
                'type': 'string',
                'description':
                    'Project directory. Defaults to active project.',
              },
            },
          },
        ),
        handler: _gitStatus,
        timeout: const Duration(seconds: 15),
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'git_diff',
          description:
              'Run git diff (or git diff --cached for staged changes). '
              'Returns the diff output.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'cwd': {
                'type': 'string',
                'description':
                    'Project directory. Defaults to active project.',
              },
              'staged': {
                'type': 'boolean',
                'description':
                    'If true, show staged changes (--cached). Default false.',
              },
              'file': {
                'type': 'string',
                'description': 'Diff a specific file only.',
              },
            },
          },
        ),
        handler: _gitDiff,
        timeout: const Duration(seconds: 15),
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'git_log',
          description:
              'Run git log --oneline. Returns list of {hash, message}.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'cwd': {
                'type': 'string',
                'description':
                    'Project directory. Defaults to active project.',
              },
              'count': {
                'type': 'integer',
                'description': 'Number of commits to show (default 10).',
              },
            },
          },
        ),
        handler: _gitLog,
        timeout: const Duration(seconds: 15),
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'git_branch',
          description:
              'Run git branch. Returns list of branches with current marked.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'cwd': {
                'type': 'string',
                'description':
                    'Project directory. Defaults to active project.',
              },
            },
          },
        ),
        handler: _gitBranch,
        timeout: const Duration(seconds: 15),
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'git_commit',
          description:
              'Stage files and commit. Never force-pushes, never amends '
              'unless explicitly requested.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'cwd': {
                'type': 'string',
                'description':
                    'Project directory. Defaults to active project.',
              },
              'message': {
                'type': 'string',
                'description': 'Commit message (required).',
              },
              'files': {
                'type': 'array',
                'items': {'type': 'string'},
                'description':
                    'Files to stage before committing. If omitted, '
                    'commits whatever is already staged.',
              },
            },
            'required': ['message'],
          },
        ),
        handler: _gitCommit,
        timeout: const Duration(seconds: 30),
      ),
    ];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String? _activeCwd(Ref ref) {
  final state = ref.read(projectsProvider);
  return state.groups
      .where((g) => g.id == state.activeGroupId)
      .firstOrNull
      ?.cwd;
}

String _resolveCwd(Ref ref, Map<String, dynamic> params) {
  final explicit = params['cwd'] as String?;
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final cwd = _activeCwd(ref);
  if (cwd == null) throw StateError('No active project and no cwd provided');
  return cwd;
}

String _truncate(String s) =>
    s.length > _maxOutput ? '${s.substring(0, _maxOutput)}\n[truncated]' : s;

Future<ProcessResult> _git(
  List<String> args,
  String cwd,
) async {
  try {
    return await Process.run('git', args, workingDirectory: cwd)
        .timeout(const Duration(seconds: 15));
  } on TimeoutException {
    throw StateError('git ${args.first} timed out after 15 seconds');
  }
}

// ---------------------------------------------------------------------------
// Tool handlers
// ---------------------------------------------------------------------------

Future<Map<String, dynamic>> _gitStatus(
    Ref ref, Map<String, dynamic> params) async {
  final cwd = _resolveCwd(ref, params);
  final result = await _git(['status', '--porcelain'], cwd);

  if (result.exitCode != 0) {
    return {'error': (result.stderr as String).trim(), 'exit_code': result.exitCode};
  }

  final stdout = result.stdout as String;
  final files = <Map<String, String>>[];
  for (final line in stdout.split('\n')) {
    if (line.isEmpty) continue;
    final status = line.substring(0, 2).trim();
    final path = line.substring(3);
    files.add({'status': status, 'path': path});
  }

  return {'files': files, 'count': files.length, 'cwd': cwd};
}

Future<Map<String, dynamic>> _gitDiff(
    Ref ref, Map<String, dynamic> params) async {
  final cwd = _resolveCwd(ref, params);
  final staged = (params['staged'] as bool?) ?? false;
  final file = params['file'] as String?;

  final args = <String>['diff'];
  if (staged) args.add('--cached');
  if (file != null && file.isNotEmpty) {
    args.add('--');
    args.add(file);
  }

  final result = await _git(args, cwd);

  if (result.exitCode != 0) {
    return {'error': (result.stderr as String).trim(), 'exit_code': result.exitCode};
  }

  final output = _truncate((result.stdout as String));
  return {
    'diff': output,
    'truncated': output.length >= _maxOutput,
    'cwd': cwd,
  };
}

Future<Map<String, dynamic>> _gitLog(
    Ref ref, Map<String, dynamic> params) async {
  final cwd = _resolveCwd(ref, params);
  final count = ((params['count'] as int?) ?? 10).clamp(1, 100);

  final result = await _git(['log', '--oneline', '-$count'], cwd);

  if (result.exitCode != 0) {
    return {'error': (result.stderr as String).trim(), 'exit_code': result.exitCode};
  }

  final stdout = _truncate(result.stdout as String);
  final commits = <Map<String, String>>[];
  for (final line in stdout.split('\n')) {
    if (line.isEmpty) continue;
    final spaceIdx = line.indexOf(' ');
    if (spaceIdx == -1) continue;
    commits.add({
      'hash': line.substring(0, spaceIdx),
      'message': line.substring(spaceIdx + 1),
    });
  }

  return {'commits': commits, 'count': commits.length, 'cwd': cwd};
}

Future<Map<String, dynamic>> _gitBranch(
    Ref ref, Map<String, dynamic> params) async {
  final cwd = _resolveCwd(ref, params);
  final result = await _git(['branch'], cwd);

  if (result.exitCode != 0) {
    return {'error': (result.stderr as String).trim(), 'exit_code': result.exitCode};
  }

  final stdout = result.stdout as String;
  final branches = <Map<String, dynamic>>[];
  for (final line in stdout.split('\n')) {
    if (line.isEmpty) continue;
    final isCurrent = line.startsWith('* ');
    final name = line.replaceFirst(RegExp(r'^\*?\s+'), '');
    branches.add({'name': name, 'current': isCurrent});
  }

  return {'branches': branches, 'count': branches.length, 'cwd': cwd};
}

Future<Map<String, dynamic>> _gitCommit(
    Ref ref, Map<String, dynamic> params) async {
  final cwd = _resolveCwd(ref, params);
  final message = params['message'] as String?;
  if (message == null || message.isEmpty) {
    return {'error': 'Commit message is required'};
  }

  final files = (params['files'] as List<dynamic>?)?.cast<String>();

  // Stage files if provided
  if (files != null && files.isNotEmpty) {
    final addResult = await _git(['add', '--', ...files], cwd);
    if (addResult.exitCode != 0) {
      return {
        'error': 'git add failed: ${(addResult.stderr as String).trim()}',
        'exit_code': addResult.exitCode,
      };
    }
  }

  // Commit
  final commitResult = await _git(['commit', '-m', message], cwd);

  if (commitResult.exitCode != 0) {
    return {
      'error': (commitResult.stderr as String).trim(),
      'stdout': (commitResult.stdout as String).trim(),
      'exit_code': commitResult.exitCode,
    };
  }

  return {
    'success': true,
    'output': _truncate((commitResult.stdout as String).trim()),
    'cwd': cwd,
  };
}
