import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alfa_types.dart';
import '../tool_executor.dart';

List<AlfaToolEntry> filesystemTools() => [
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
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
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
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
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
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
  final file = File(path);
  if (!await file.exists()) return {'error': 'File not found: $path'};
  final stat = await file.stat();
  if (stat.size > 1024 * 1024) return {'error': 'File too large (${stat.size} bytes). Max 1MB.'};
  final content = await file.readAsString();
  return {'content': content, 'size': stat.size};
}

Future<Map<String, dynamic>> _listDirectory(Ref ref, Map<String, dynamic> params) async {
  final path = params['path'] as String;
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

Future<Map<String, dynamic>> _runShellCommand(Ref ref, Map<String, dynamic> params) async {
  final command = params['command'] as String;
  final cwd = params['cwd'] as String;
  final timeoutSeconds = (params['timeout_seconds'] as int?) ?? 30;
  final result = await Process.run('/bin/sh', ['-c', command], workingDirectory: cwd, environment: Platform.environment).timeout(Duration(seconds: timeoutSeconds));
  return {
    'stdout': (result.stdout as String).length > 10000 ? '${(result.stdout as String).substring(0, 10000)}\n[truncated]' : result.stdout,
    'stderr': (result.stderr as String).length > 5000 ? '${(result.stderr as String).substring(0, 5000)}\n[truncated]' : result.stderr,
    'exit_code': result.exitCode,
  };
}
