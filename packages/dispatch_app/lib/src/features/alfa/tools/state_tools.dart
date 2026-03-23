import 'dart:io';

import '../alfa_types.dart';
import '../tool_executor.dart';
import '../agents_state.dart';
import '../default_identity.dart';

List<AlfaToolEntry> stateTools(AgentsState agentsState) => [
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'update_agents',
          description: 'Read or modify agents.json. Actions: read, register, update, remove, cleanup_stale.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'action': {'type': 'string', 'enum': ['read', 'register', 'update', 'remove', 'cleanup_stale']},
              'terminal_id': {'type': 'string'},
              'task': {'type': 'string'},
              'project': {'type': 'string'},
              'status': {'type': 'string'},
              'plan_step_id': {'type': 'string'},
              'success_signal': {'type': 'string'},
              'files_claimed': {'type': 'array', 'items': {'type': 'string'}},
            },
            'required': ['action'],
          },
        ),
        handler: (ref, params) => _updateAgents(agentsState, params),
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'append_log',
          description: 'Append an entry to log.md with timestamp. Auto-prunes at 500 entries.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'entry': {'type': 'string', 'description': 'Log entry text'},
            },
            'required': ['entry'],
          },
        ),
        handler: (ref, params) => _appendLog(params),
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'read_memory',
          description: 'Read memory.md — long-term user preferences and observations.',
          inputSchema: {'type': 'object', 'properties': {}},
        ),
        handler: (ref, params) => _readMemory(),
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'update_memory',
          description: 'Overwrite memory.md. Read first, modify, write back. If over 1500 tokens, propose summarization to human first.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'content': {'type': 'string', 'description': 'Full memory.md content'},
            },
            'required': ['content'],
          },
        ),
        handler: (ref, params) => _updateMemory(params),
      ),
    ];

Future<Map<String, dynamic>> _updateAgents(AgentsState agentsState, Map<String, dynamic> params) async {
  final action = params['action'] as String;
  switch (action) {
    case 'read':
      return agentsState.readState();
    case 'register':
      await agentsState.registerAgent(
        terminalId: params['terminal_id'] as String,
        task: params['task'] as String,
        project: params['project'] as String,
        planStepId: params['plan_step_id'] as String?,
        successSignal: params['success_signal'] as String?,
        filesClaimed: (params['files_claimed'] as List<dynamic>?)?.cast<String>() ?? [],
      );
      return {'success': true};
    case 'update':
      await agentsState.updateAgent(
        params['terminal_id'] as String,
        status: params['status'] as String?,
        filesClaimed: (params['files_claimed'] as List<dynamic>?)?.cast<String>(),
      );
      return {'success': true};
    case 'remove':
      await agentsState.removeAgent(params['terminal_id'] as String);
      return {'success': true};
    case 'cleanup_stale':
      final stale = await agentsState.cleanupStale();
      return {'cleaned': stale, 'count': stale.length};
    default:
      return {'error': 'Unknown action: $action'};
  }
}

Future<Map<String, dynamic>> _appendLog(Map<String, dynamic> params) async {
  final entry = params['entry'] as String;
  final path = '${alfaDir()}/log.md';
  final file = File(path);

  var content = '';
  if (await file.exists()) content = await file.readAsString();

  final timestamp = DateTime.now().toUtc().toIso8601String();
  final newEntry = '- [$timestamp] $entry\n';
  content = newEntry + content;

  // Prune to 500 entries
  final lines = content.split('\n').where((l) => l.startsWith('- [')).toList();
  if (lines.length > 500) {
    content = '${lines.sublist(0, 500).join('\n')}\n';
  }

  await writeFile(path, content);
  return {'success': true};
}

Future<Map<String, dynamic>> _readMemory() async {
  final content = await loadFile('${alfaDir()}/memory.md');
  return {'content': content};
}

Future<Map<String, dynamic>> _updateMemory(Map<String, dynamic> params) async {
  final content = params['content'] as String;
  await writeFile('${alfaDir()}/memory.md', content);
  return {'success': true};
}
