import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grace_types.dart';
import '../tool_executor.dart';

/// Returns true if [path] is within the user's home directory.
/// Resolves symlinks to prevent symlink traversal attacks.
Future<bool> _isSafePath(String path) async {
  final home = Platform.environment['HOME'] ?? '/tmp';
  String resolved;
  try {
    resolved = await File(path).resolveSymbolicLinks();
  } on FileSystemException {
    try {
      final parentResolved =
          await Directory(File(path).parent.path).resolveSymbolicLinks();
      resolved = '$parentResolved/${File(path).uri.pathSegments.last}';
    } on FileSystemException {
      return false;
    }
  }
  return resolved.startsWith(home);
}

List<GraceToolEntry> filesystemTools() => [
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'read_file',
          description: 'Reads a file contents. Path must be within a known project CWD.',
          inputSchema: {
            'type': 'object',
            'properties': {'path': {'type': 'string'}},
            'required': ['path'],
          },
        ),
        handler: _readFile,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'list_directory',
          description: 'Lists directory contents.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'path': {'type': 'string'},
              'recursive': {'type': 'boolean', 'description': 'List recursively (default false)'},
            },
            'required': ['path'],
          },
        ),
        handler: _listDirectory,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'run_shell_command',
          description: 'Runs a shell command and returns stdout/stderr. 30-second default timeout. For quick operations only — use spawn_terminal for long-running processes.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'command': {'type': 'string'},
              'cwd': {'type': 'string'},
              'timeout_seconds': {'type': 'integer', 'description': 'Timeout in seconds (default 30)'},
            },
            'required': ['command', 'cwd'],
          },
        ),
        handler: _runShellCommand,
        timeout: const Duration(seconds: 35),
      ),
    ];

Future<Map<String, dynamic>> _readFile(Ref ref, Map<String, dynamic> params) async {
  final path = params['path'] as String;
  if (!await _isSafePath(path)) {
    return {'error': 'Refused: path is outside home directory.'};
  }
  final file = File(path);
  if (!await file.exists()) return {'error': 'File not found: $path'};
  final stat = await file.stat();
  if (stat.size > 1024 * 1024) return {'error': 'File too large (${stat.size} bytes). Max 1MB.'};
  final content = await file.readAsString();
  return {'content': content, 'size': stat.size};
}

Future<Map<String, dynamic>> _listDirectory(Ref ref, Map<String, dynamic> params) async {
  final path = params['path'] as String;
  if (!await _isSafePath(path)) {
    return {'error': 'Refused: path is outside home directory.'};
  }
  final recursive = (params['recursive'] as bool?) ?? false;
  final dir = Directory(path);
  if (!await dir.exists()) return {'error': 'Directory not found: $path'};
  final entries = <Map<String, dynamic>>[];
  await for (final entity in dir.list(recursive: recursive)) {
    if (entries.length >= 500) break;
    final name = entity.path.substring(path.length).replaceFirst(RegExp(r'^/'), '');
    if (name.startsWith('.')) continue;
    entries.add({'name': name, 'type': entity is Directory ? 'directory' : 'file'});
  }
  return {'entries': entries, 'count': entries.length, 'truncated': entries.length >= 500};
}

/// Blocklist of obviously dangerous command patterns.
final _blockedCommandPatterns = [
  RegExp(r'rm\s+(-[a-zA-Z]*f[a-zA-Z]*\s+|--force\s+)*/\s*$'),  // rm -rf /
  RegExp(r'rm\s+(-[a-zA-Z]*f[a-zA-Z]*\s+|--force\s+)*/$'),      // rm -rf /
  RegExp(r'mkfs\.'),                                               // mkfs.*
  RegExp(r'dd\s+.*of=/dev/'),                                      // dd of=/dev/*
  RegExp(r':\(\)\{.*\|.*\};:'),                                    // fork bomb
  RegExp(r'curl\s+.*\|\s*(ba)?sh'),                                // curl|sh
  RegExp(r'wget\s+.*\|\s*(ba)?sh'),                                // wget|sh
  RegExp(r'curl\s+.*\|\s*sudo'),                                   // curl|sudo
  RegExp(r'chmod\s+(-[a-zA-Z]*\s+)*777\s+/'),                     // chmod 777 /
];

Future<Map<String, dynamic>> _runShellCommand(Ref ref, Map<String, dynamic> params) async {
  final command = params['command'] as String;
  final cwd = params['cwd'] as String;
  final timeoutSeconds = (params['timeout_seconds'] as int?) ?? 30;

  // Validate cwd is within home directory
  if (!await _isSafePath(cwd)) {
    return {'error': 'Refused: cwd is outside home directory.'};
  }

  // Check against command blocklist
  for (final pattern in _blockedCommandPatterns) {
    if (pattern.hasMatch(command)) {
      return {'error': 'Refused: command matches a blocked dangerous pattern.'};
    }
  }

  final result = await Process.run('/bin/sh', ['-c', command], workingDirectory: cwd, environment: Platform.environment).timeout(Duration(seconds: timeoutSeconds));
  return {
    'stdout': (result.stdout as String).length > 10000 ? '${(result.stdout as String).substring(0, 10000)}\n[truncated]' : result.stdout,
    'stderr': (result.stderr as String).length > 5000 ? '${(result.stderr as String).substring(0, 5000)}\n[truncated]' : result.stderr,
    'exit_code': result.exitCode,
  };
}
