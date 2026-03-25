import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grace_types.dart';
import '../tool_executor.dart';

/// Max file size for write_file: 1 MB.
const _maxWriteBytes = 1024 * 1024;

List<GraceToolEntry> fileTools() => [
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'write_file',
          description:
              'Write content to a file. Creates parent directories if needed. '
              'Path must be within a known project CWD or home directory. Max 1 MB.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Absolute file path'},
              'content': {'type': 'string', 'description': 'File content to write'},
            },
            'required': ['path', 'content'],
          },
        ),
        handler: _writeFile,
        timeout: const Duration(seconds: 10),
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'edit_file',
          description:
              'Find and replace text in a file. The old_text must appear exactly '
              'once in the file — errors if not found or found multiple times.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Absolute file path'},
              'old_text': {'type': 'string', 'description': 'Exact text to find'},
              'new_text': {'type': 'string', 'description': 'Replacement text'},
            },
            'required': ['path', 'old_text', 'new_text'],
          },
        ),
        handler: _editFile,
        timeout: const Duration(seconds: 10),
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'create_directory',
          description: 'Create a directory recursively.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Absolute directory path'},
            },
            'required': ['path'],
          },
        ),
        handler: _createDirectory,
      ),
    ];

/// Returns true if [path] is within the user's home directory.
/// Resolves symlinks to prevent symlink traversal attacks.
Future<bool> _isSafePath(String path) async {
  final home = Platform.environment['HOME'] ?? '/tmp';
  String resolved;
  try {
    resolved = await File(path).resolveSymbolicLinks();
  } on FileSystemException {
    // File doesn't exist yet (e.g. write_file creating a new file).
    // Resolve the parent directory instead.
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

Future<Map<String, dynamic>> _writeFile(
    Ref ref, Map<String, dynamic> params) async {
  final path = params['path'] as String;
  final content = params['content'] as String;

  if (!await _isSafePath(path)) {
    return {'error': 'Refused: path is outside home directory.'};
  }

  final bytes = content.length;
  if (bytes > _maxWriteBytes) {
    return {'error': 'Content too large ($bytes bytes). Max $_maxWriteBytes bytes.'};
  }

  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);

  return {'status': 'written', 'path': path, 'bytes': bytes};
}

Future<Map<String, dynamic>> _editFile(
    Ref ref, Map<String, dynamic> params) async {
  final path = params['path'] as String;
  final oldText = params['old_text'] as String;
  final newText = params['new_text'] as String;

  if (!await _isSafePath(path)) {
    return {'error': 'Refused: path is outside home directory.'};
  }

  final file = File(path);
  if (!await file.exists()) {
    return {'error': 'File not found: $path'};
  }

  final content = await file.readAsString();
  final occurrences = _countOccurrences(content, oldText);

  if (occurrences == 0) {
    return {'error': 'old_text not found in file.'};
  }
  if (occurrences > 1) {
    return {
      'error': 'old_text found $occurrences times — must appear exactly once. '
          'Provide more surrounding context to make it unique.',
    };
  }

  final updated = content.replaceFirst(oldText, newText);
  await file.writeAsString(updated);

  return {'status': 'edited', 'path': path, 'bytes': updated.length};
}

Future<Map<String, dynamic>> _createDirectory(
    Ref ref, Map<String, dynamic> params) async {
  final path = params['path'] as String;

  if (!await _isSafePath(path)) {
    return {'error': 'Refused: path is outside home directory.'};
  }

  await Directory(path).create(recursive: true);
  return {'status': 'created', 'path': path};
}

int _countOccurrences(String source, String pattern) {
  if (pattern.isEmpty) return 0;
  var count = 0;
  var index = 0;
  while (true) {
    index = source.indexOf(pattern, index);
    if (index == -1) break;
    count++;
    index += pattern.length;
  }
  return count;
}
