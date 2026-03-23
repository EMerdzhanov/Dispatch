import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp_tools.dart';
import '../../projects/projects_provider.dart';
import '../../../persistence/auto_save.dart';

List<McpToolDefinition> vaultTools() => [
      McpToolDefinition(
        name: 'get_vault_keys',
        description:
            'Returns the list of key names stored in the vault for the active project. '
            'Does NOT return values — use get_vault_value for that. '
            'Only call vault tools when the task explicitly requires credentials or secrets.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'projectCwd': {
              'type': 'string',
              'description': 'Working directory. Defaults to active project.',
            },
          },
        },
        handler: _getVaultKeys,
      ),
      McpToolDefinition(
        name: 'get_vault_value',
        description:
            'Returns the value for a specific vault key. '
            'SENSITIVE: Only call this when the task explicitly requires '
            'credentials, API keys, or tokens. Do not call speculatively.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'key': {
              'type': 'string',
              'description': 'The vault key (label) to retrieve',
            },
            'projectCwd': {
              'type': 'string',
              'description': 'Working directory. Defaults to active project.',
            },
          },
          'required': ['key'],
        },
        handler: _getVaultValue,
      ),
      McpToolDefinition(
        name: 'set_vault_value',
        description:
            'Stores or updates a key/value pair in the vault. '
            'SENSITIVE: Only call this when the task explicitly requires '
            'storing credentials, API keys, or tokens.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'key': {
              'type': 'string',
              'description': 'The vault key (label) to store',
            },
            'value': {
              'type': 'string',
              'description': 'The secret value to store',
            },
            'projectCwd': {
              'type': 'string',
              'description': 'Working directory. Defaults to active project.',
            },
          },
          'required': ['key', 'value'],
        },
        handler: _setVaultValue,
      ),
    ];

String _resolveCwd(Ref ref, Map<String, dynamic> params) {
  final explicit = params['projectCwd'] as String?;
  if (explicit != null && explicit.isNotEmpty) return explicit;

  final state = ref.read(projectsProvider);
  final group = state.groups
      .where((g) => g.id == state.activeGroupId)
      .firstOrNull;
  final cwd = group?.cwd;
  if (cwd == null) throw StateError('No active project');
  return cwd;
}

Future<Map<String, dynamic>> _getVaultKeys(
    Ref ref, Map<String, dynamic> params) async {
  final cwd = _resolveCwd(ref, params);
  final db = ref.read(databaseProvider);
  final entries = await db.vaultDao.getEntriesForProject(cwd);
  return {
    'keys': entries.map((e) => e.label).toList(),
  };
}

Future<Map<String, dynamic>> _getVaultValue(
    Ref ref, Map<String, dynamic> params) async {
  final key = params['key'] as String?;
  if (key == null || key.isEmpty) throw ArgumentError('key is required');

  final cwd = _resolveCwd(ref, params);
  final db = ref.read(databaseProvider);
  final entry = await db.vaultDao.getEntryByLabel(cwd, key);
  if (entry == null) {
    throw StateError('Vault key not found: $key');
  }
  return {
    'key': entry.label,
    'value': entry.encryptedValue,
  };
}

Future<Map<String, dynamic>> _setVaultValue(
    Ref ref, Map<String, dynamic> params) async {
  final key = params['key'] as String?;
  final value = params['value'] as String?;
  if (key == null || key.isEmpty) throw ArgumentError('key is required');
  if (value == null || value.isEmpty) throw ArgumentError('value is required');

  final cwd = _resolveCwd(ref, params);
  final db = ref.read(databaseProvider);

  // Update existing entry or insert new one
  final existing = await db.vaultDao.getEntryByLabel(cwd, key);
  if (existing != null) {
    await db.vaultDao.updateEntry(existing.id, encryptedValue: value);
    return {'key': key, 'status': 'updated'};
  }

  final id = await db.vaultDao.insertEntry(
    projectCwd: cwd,
    label: key,
    encryptedValue: value,
  );
  return {'id': id, 'key': key, 'status': 'created'};
}
