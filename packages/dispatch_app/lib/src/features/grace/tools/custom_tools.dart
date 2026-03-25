import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../default_identity.dart';
import '../grace_types.dart';
import '../tool_executor.dart';

/// Directory where custom tool JSON files are stored.
String _customToolsDir() => '${graceDir()}/custom_tools';

/// Validate a tool name: lowercase alphanumeric + underscores, max 50 chars.
String? _validateName(String name) {
  if (name.isEmpty) return 'Tool name cannot be empty';
  if (name.length > 50) return 'Tool name must be 50 characters or fewer';
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(name)) {
    return 'Tool name must contain only lowercase letters, digits, and underscores';
  }
  return null;
}

/// Shell-escape a parameter value by wrapping in single quotes.
String _shellEscape(String value) {
  // Replace single quotes with '\'' (end quote, escaped quote, start quote)
  return "'${value.replaceAll("'", "'\\''")}'";
}

/// Substitute {{param_name}} placeholders in a command template.
String _substituteParams(
    String command, Map<String, dynamic> params, Map<String, dynamic>? paramDefs) {
  var result = command;
  // Apply provided params
  params.forEach((key, value) {
    final escaped = _shellEscape(value.toString());
    result = result.replaceAll('{{$key}}', escaped);
  });
  // Apply defaults for any remaining placeholders
  if (paramDefs != null) {
    paramDefs.forEach((key, def) {
      if (result.contains('{{$key}}') && def is Map && def.containsKey('default')) {
        final escaped = _shellEscape(def['default'].toString());
        result = result.replaceAll('{{$key}}', escaped);
      }
    });
  }
  return result;
}

/// Management tools: create, list, delete custom tools.
/// These are always available (registered in constructor).
List<GraceToolEntry> customToolManagement() => [
      _createCustomTool(),
      _listCustomTools(),
      _deleteCustomTool(),
    ];

/// Load all user-created custom tools from disk.
/// Called during initialize() to make custom tools available.
Future<List<GraceToolEntry>> loadCustomTools() async {
  final dir = Directory(_customToolsDir());
  if (!await dir.exists()) return [];

  final entries = <GraceToolEntry>[];
  await for (final entity in dir.list()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    try {
      final content = await entity.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      entries.add(_toolEntryFromJson(json));
    } catch (_) {
      // Skip malformed tool files
    }
  }
  return entries;
}

GraceToolEntry _toolEntryFromJson(Map<String, dynamic> json) {
  final name = json['name'] as String;
  final description = json['description'] as String;
  final command = json['command'] as String;
  final cwd = json['cwd'] as String?;
  final timeoutSeconds = (json['timeout_seconds'] as int?) ?? 30;
  final parameters = json['parameters'] as Map<String, dynamic>?;

  // Build inputSchema from parameters
  final properties = <String, dynamic>{};
  if (parameters != null) {
    for (final entry in parameters.entries) {
      final paramDef = entry.value as Map<String, dynamic>;
      properties[entry.key] = {
        'type': paramDef['type'] ?? 'string',
        if (paramDef['description'] != null)
          'description': paramDef['description'],
      };
    }
  }

  final timeout = Duration(seconds: timeoutSeconds.clamp(1, 120));

  return GraceToolEntry(
    definition: GraceToolDefinition(
      name: name,
      description: '[Custom] $description',
      inputSchema: {
        'type': 'object',
        'properties': properties,
      },
    ),
    handler: (Ref ref, Map<String, dynamic> params) async {
      final substituted = _substituteParams(command, params, parameters);
      try {
        final result = await Process.run(
          '/bin/sh',
          ['-c', substituted],
          workingDirectory: cwd,
        ).timeout(timeout);
        return {
          'tool': name,
          'exit_code': result.exitCode,
          'stdout': (result.stdout as String).length > 10000
              ? '${(result.stdout as String).substring(0, 10000)}\n[truncated]'
              : result.stdout,
          if ((result.stderr as String).isNotEmpty) 'stderr': result.stderr,
        };
      } on ProcessException catch (e) {
        return {'tool': name, 'error': 'Failed to execute: $e'};
      }
    },
    timeout: timeout,
  );
}

// ---------------------------------------------------------------------------
// create_custom_tool
// ---------------------------------------------------------------------------

GraceToolEntry _createCustomTool() => GraceToolEntry(
      definition: const GraceToolDefinition(
        name: 'create_custom_tool',
        description:
            'Create a new custom tool that persists across sessions. '
            'Define a shell command template with optional parameter substitution '
            'using {{param_name}} placeholders. The tool will be available after '
            'the next Grace initialization, or immediately if you reload.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description':
                  'Tool name (lowercase letters, digits, underscores only, max 50 chars)',
            },
            'description': {
              'type': 'string',
              'description': 'What the tool does',
            },
            'command': {
              'type': 'string',
              'description':
                  'Shell command template. Use {{param_name}} for parameter substitution.',
            },
            'cwd': {
              'type': 'string',
              'description': 'Working directory for the command (optional)',
            },
            'timeout_seconds': {
              'type': 'integer',
              'description': 'Execution timeout in seconds (default 30, max 120)',
            },
            'parameters': {
              'type': 'object',
              'description':
                  'Parameter definitions. Each key is a param name, value is '
                  '{type, description, default}.',
            },
          },
          'required': ['name', 'description', 'command'],
        },
      ),
      handler: _handleCreateCustomTool,
    );

Future<Map<String, dynamic>> _handleCreateCustomTool(
    Ref ref, Map<String, dynamic> params) async {
  final name = params['name'] as String;
  final description = params['description'] as String;
  final command = params['command'] as String;
  final cwd = params['cwd'] as String?;
  final timeoutSeconds =
      ((params['timeout_seconds'] as int?) ?? 30).clamp(1, 120);
  final parameters = params['parameters'] as Map<String, dynamic>?;

  // Validate name
  final nameError = _validateName(name);
  if (nameError != null) return {'error': nameError};

  // Prevent overwriting built-in tools
  const builtInNames = {
    // Management tools
    'create_custom_tool', 'list_custom_tools', 'delete_custom_tool',
    // Terminal
    'spawn_terminal', 'run_command', 'write_to_terminal', 'read_terminal',
    'list_terminals', 'kill_terminal', 'get_terminal_status',
    'set_active_terminal', 'send_key', 'split_terminal',
    // Project
    'scan_project', 'search_codebase', 'get_active_project',
    'set_active_project', 'list_projects', 'close_project',
    // Files
    'read_file', 'write_file', 'list_directory',
    // Memory
    'save_memory', 'search_memory', 'read_memory', 'update_memory',
    // State
    'add_task', 'get_tasks', 'complete_task', 'update_task', 'delete_task',
    'get_notes', 'update_notes', 'append_notes',
    'get_vault_keys', 'get_vault_value', 'set_vault_value',
    // Knowledge
    'update_project_knowledge', 'read_project_knowledge',
    // System
    'notify', 'screenshot_terminal',
    // Git
    'git_status', 'git_log', 'git_diff', 'git_branch',
    // Web
    'web_fetch', 'web_search',
    // Loop
    'get_loop_status', 'generate_grace_md',
    // Playbooks / delegates / routing
    'run_playbook', 'list_playbooks', 'save_playbook',
    'delegate_task', 'get_agent_status',
    'route_request',
    // Code & test
    'run_tests', 'get_test_status',
    'analyze_code', 'format_code',
    // Workspace
    'get_project_config', 'set_project_config',
    // History
    'read_log', 'append_log',
    // Misc
    'get_references', 'get_symbol',
  };

  if (builtInNames.contains(name)) {
    return {'error': 'Cannot overwrite built-in tool: $name'};
  }

  // Write the JSON file
  final dir = Directory(_customToolsDir());
  await dir.create(recursive: true);

  final toolJson = <String, dynamic>{
    'name': name,
    'description': description,
    'command': command,
    if (cwd != null) 'cwd': cwd,
    'timeout_seconds': timeoutSeconds,
    if (parameters != null) 'parameters': parameters,
  };

  final filePath = '${dir.path}/$name.json';
  await File(filePath)
      .writeAsString(const JsonEncoder.withIndent('  ').convert(toolJson));

  return {
    'status': 'created',
    'name': name,
    'path': filePath,
  };
}

// ---------------------------------------------------------------------------
// list_custom_tools
// ---------------------------------------------------------------------------

GraceToolEntry _listCustomTools() => GraceToolEntry(
      definition: const GraceToolDefinition(
        name: 'list_custom_tools',
        description:
            'List all user-created custom tools. Returns name, description, '
            'command, and parameters for each tool.',
        inputSchema: {
          'type': 'object',
          'properties': {},
        },
      ),
      handler: _handleListCustomTools,
    );

Future<Map<String, dynamic>> _handleListCustomTools(
    Ref ref, Map<String, dynamic> params) async {
  final dir = Directory(_customToolsDir());
  if (!await dir.exists()) return {'tools': <Map<String, dynamic>>[]};

  final tools = <Map<String, dynamic>>[];
  await for (final entity in dir.list()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    try {
      final content = await entity.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      tools.add({
        'name': json['name'],
        'description': json['description'],
        'command': json['command'],
        if (json['parameters'] != null) 'parameters': json['parameters'],
      });
    } catch (_) {
      // Skip malformed files
    }
  }

  return {'tools': tools};
}

// ---------------------------------------------------------------------------
// delete_custom_tool
// ---------------------------------------------------------------------------

GraceToolEntry _deleteCustomTool() => GraceToolEntry(
      definition: const GraceToolDefinition(
        name: 'delete_custom_tool',
        description: 'Delete a user-created custom tool by name.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description': 'Name of the custom tool to delete',
            },
          },
          'required': ['name'],
        },
      ),
      handler: _handleDeleteCustomTool,
    );

Future<Map<String, dynamic>> _handleDeleteCustomTool(
    Ref ref, Map<String, dynamic> params) async {
  final name = params['name'] as String;

  final nameError = _validateName(name);
  if (nameError != null) return {'error': nameError};

  final file = File('${_customToolsDir()}/$name.json');
  if (!await file.exists()) {
    return {'error': 'Custom tool not found: $name'};
  }

  await file.delete();
  return {'status': 'deleted', 'name': name};
}
