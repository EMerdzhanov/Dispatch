import '../alfa_types.dart';
import '../tool_executor.dart';
import '../playbook_loader.dart';

List<AlfaToolEntry> playbookTools(PlaybookLoader loader) => [
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'load_playbook',
          description: 'List available playbooks or load one by name. Use action "list" or "load".',
          inputSchema: {
            'type': 'object',
            'properties': {
              'action': {'type': 'string', 'enum': ['list', 'load']},
              'name': {'type': 'string', 'description': 'Playbook name (for load action)'},
            },
            'required': ['action'],
          },
        ),
        handler: (ref, params) => _loadPlaybook(loader, params),
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'save_playbook',
          description: 'Create or update a playbook markdown file. Only after human approval.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'content': {'type': 'string', 'description': 'Full playbook markdown with frontmatter'},
            },
            'required': ['name', 'content'],
          },
        ),
        handler: (ref, params) => _savePlaybook(loader, params),
      ),
    ];

Future<Map<String, dynamic>> _loadPlaybook(PlaybookLoader loader, Map<String, dynamic> params) async {
  final action = params['action'] as String;
  if (action == 'list') {
    final playbooks = await loader.listPlaybooks();
    return {
      'playbooks': playbooks.map((p) => {
        'name': p.name,
        'description': p.description,
        'triggers': p.triggers,
        'draft': p.draft,
      }).toList(),
      'count': playbooks.length,
    };
  } else if (action == 'load') {
    final name = params['name'] as String?;
    if (name == null) return {'error': 'name is required for load action'};
    final content = await loader.loadPlaybook(name);
    if (content == null) return {'error': 'Playbook not found: $name'};

    // Check if draft
    final meta = (await loader.listPlaybooks()).where((p) => p.name.toLowerCase() == name.toLowerCase()).firstOrNull;
    final prefix = (meta?.draft == true) ? '[DRAFT PLAYBOOK — not yet reviewed] Proceeding with $name...\n\n' : '';

    return {'content': '$prefix$content'};
  }
  return {'error': 'Unknown action: $action'};
}

Future<Map<String, dynamic>> _savePlaybook(PlaybookLoader loader, Map<String, dynamic> params) async {
  final name = params['name'] as String;
  final content = params['content'] as String;
  final path = await loader.savePlaybook(name, content);
  return {'success': true, 'path': path};
}
