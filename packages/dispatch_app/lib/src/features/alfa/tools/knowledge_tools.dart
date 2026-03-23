import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alfa_types.dart';
import '../tool_executor.dart';

List<AlfaToolEntry> knowledgeTools() => [
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'read_project_knowledge',
          description: 'Reads the project knowledge markdown file. Returns empty string if none exists yet.',
          inputSchema: {
            'type': 'object',
            'properties': {'cwd': {'type': 'string'}},
            'required': ['cwd'],
          },
        ),
        handler: _readKnowledge,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'update_project_knowledge',
          description: 'Overwrites the project knowledge file. You manage the full content — preserve what matters, add new learnings.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'cwd': {'type': 'string'},
              'content': {'type': 'string', 'description': 'Full markdown content'},
            },
            'required': ['cwd', 'content'],
          },
        ),
        handler: _updateKnowledge,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'scan_project',
          description: 'Quick filesystem scan of a project directory. Detects language, framework, build files, entry points, test commands.',
          inputSchema: {
            'type': 'object',
            'properties': {'cwd': {'type': 'string'}},
            'required': ['cwd'],
          },
        ),
        handler: _scanProject,
        timeout: const Duration(seconds: 10),
      ),
    ];

String _knowledgePath(String cwd) {
  final hash = sha256.convert(utf8.encode(cwd)).toString();
  final home = Platform.environment['HOME'] ?? '/tmp';
  return '$home/.config/dispatch/alfa/projects/$hash/knowledge.md';
}

Future<Map<String, dynamic>> _readKnowledge(Ref ref, Map<String, dynamic> params) async {
  final cwd = params['cwd'] as String;
  if (cwd.isEmpty) return {'error': 'cwd is required'};
  final file = File(_knowledgePath(cwd));
  if (!await file.exists()) return {'content': '', 'exists': false};
  final content = await file.readAsString();
  return {'content': content, 'exists': true};
}

Future<Map<String, dynamic>> _updateKnowledge(Ref ref, Map<String, dynamic> params) async {
  final cwd = params['cwd'] as String;
  final content = params['content'] as String;
  if (cwd.isEmpty) return {'error': 'cwd is required'};
  final file = File(_knowledgePath(cwd));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
  return {'success': true, 'path': file.path};
}

Future<Map<String, dynamic>> _scanProject(Ref ref, Map<String, dynamic> params) async {
  final cwd = params['cwd'] as String;
  final dir = Directory(cwd);
  if (!await dir.exists()) return {'error': 'Directory does not exist'};
  final result = <String, dynamic>{'cwd': cwd, 'name': cwd.split('/').last};
  final markers = <String, String>{
    'pubspec.yaml': 'dart/flutter', 'package.json': 'node', 'Cargo.toml': 'rust',
    'go.mod': 'go', 'pyproject.toml': 'python', 'requirements.txt': 'python',
    'Gemfile': 'ruby', 'pom.xml': 'java/maven', 'build.gradle': 'java/gradle',
    'CMakeLists.txt': 'c/cpp', 'Makefile': 'make', 'melos.yaml': 'melos-monorepo',
  };
  final detected = <String>[];
  final buildFiles = <String>[];
  await for (final entity in dir.list()) {
    final name = entity.path.split('/').last;
    if (markers.containsKey(name)) { detected.add(markers[name]!); buildFiles.add(name); }
  }
  result['detected_stacks'] = detected;
  result['build_files'] = buildFiles;
  final commonDirs = ['src', 'lib', 'test', 'tests', 'packages', 'apps'];
  final foundDirs = <String>[];
  for (final d in commonDirs) {
    if (await Directory('$cwd/$d').exists()) foundDirs.add(d);
  }
  result['directories'] = foundDirs;
  result['has_git'] = await Directory('$cwd/.git').exists();
  return result;
}
