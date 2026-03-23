import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alfa_types.dart';
import '../tool_executor.dart';

List<AlfaToolEntry> knowledgeTools() => [
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
