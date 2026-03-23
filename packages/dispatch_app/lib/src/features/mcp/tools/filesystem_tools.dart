import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp_tools.dart';

List<McpToolDefinition> filesystemTools() => [
      McpToolDefinition(
        name: 'read_file',
        description: 'Reads the contents of a file. Max 1MB.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Absolute file path'},
          },
          'required': ['path'],
        },
        handler: _readFile,
      ),
      McpToolDefinition(
        name: 'write_file',
        description: 'Writes content to a file. Creates parent directories if needed.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Absolute file path'},
            'content': {'type': 'string', 'description': 'File content to write'},
          },
          'required': ['path', 'content'],
        },
        handler: _writeFile,
      ),
      McpToolDefinition(
        name: 'list_directory',
        description: 'Lists directory contents. Returns file names and types.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Absolute directory path'},
            'recursive': {
              'type': 'boolean',
              'description': 'List recursively (default false)',
            },
          },
          'required': ['path'],
        },
        handler: _listDirectory,
      ),
    ];

Future<Map<String, dynamic>> _readFile(
    Ref ref, Map<String, dynamic> params) async {
  final path = params['path'] as String?;
  if (path == null) throw ArgumentError('path is required');

  final file = File(path);
  if (!await file.exists()) return {'error': 'File not found: $path'};

  final stat = await file.stat();
  if (stat.size > 1024 * 1024) {
    return {'error': 'File too large (${stat.size} bytes). Max 1MB.'};
  }

  final content = await file.readAsString();
  return {'content': content, 'size': stat.size};
}

Future<Map<String, dynamic>> _writeFile(
    Ref ref, Map<String, dynamic> params) async {
  final path = params['path'] as String?;
  final content = params['content'] as String?;
  if (path == null || content == null) {
    throw ArgumentError('path and content are required');
  }

  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
  final stat = await file.stat();
  return {'success': true, 'size': stat.size};
}

Future<Map<String, dynamic>> _listDirectory(
    Ref ref, Map<String, dynamic> params) async {
  final path = params['path'] as String?;
  if (path == null) throw ArgumentError('path is required');

  final recursive = (params['recursive'] as bool?) ?? false;
  final dir = Directory(path);
  if (!await dir.exists()) return {'error': 'Directory not found: $path'};

  final entries = <Map<String, dynamic>>[];
  await for (final entity in dir.list(recursive: recursive)) {
    if (entries.length >= 500) break;
    final name =
        entity.path.substring(path.length).replaceFirst(RegExp(r'^/'), '');
    if (name.startsWith('.')) continue;
    entries.add({
      'name': name,
      'type': entity is Directory ? 'directory' : 'file',
    });
  }
  return {
    'entries': entries,
    'count': entries.length,
    'truncated': entries.length >= 500,
  };
}
