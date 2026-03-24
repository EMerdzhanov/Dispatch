import '../alfa_types.dart';
import '../tool_executor.dart';
import '../default_identity.dart';

List<AlfaToolEntry> projectToolsV2() => [
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'read_project',
          description: 'Read the project context file for a given CWD. Path is auto-slugified.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'cwd': {'type': 'string'},
            },
            'required': ['cwd'],
          },
        ),
        handler: (ref, params) => _readProject(params),
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'update_project',
          description: 'Overwrite the project context file. Read first, modify, write back.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'cwd': {'type': 'string'},
              'content': {'type': 'string', 'description': 'Full project context markdown'},
            },
            'required': ['cwd', 'content'],
          },
        ),
        handler: (ref, params) => _updateProject(params),
      ),
    ];

String _projectPath(String cwd) {
  return '${graceDir()}/projects/${slugifyPath(cwd)}.md';
}

Future<Map<String, dynamic>> _readProject(Map<String, dynamic> params) async {
  final cwd = params['cwd'] as String;
  if (cwd.isEmpty) return {'error': 'cwd is required'};
  final content = await loadFile(_projectPath(cwd));
  return {'content': content, 'exists': content.isNotEmpty};
}

Future<Map<String, dynamic>> _updateProject(Map<String, dynamic> params) async {
  final cwd = params['cwd'] as String;
  final content = params['content'] as String;
  if (cwd.isEmpty) return {'error': 'cwd is required'};
  final path = _projectPath(cwd);
  await writeFile(path, content);
  return {'success': true, 'path': path};
}
