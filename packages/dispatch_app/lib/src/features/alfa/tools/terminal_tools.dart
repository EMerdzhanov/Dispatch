import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alfa_types.dart';
import '../tool_executor.dart';
import '../../terminal/terminal_provider.dart';
import '../../terminal/session_registry.dart';
import '../../../core/models/terminal_entry.dart';

List<AlfaToolEntry> terminalTools() => [
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'spawn_terminal',
          description: 'Spawns a new terminal with a command in a project group. Returns the terminal ID.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'project_id': {'type': 'string', 'description': 'Project group ID'},
              'command': {'type': 'string', 'description': 'Command to run'},
              'cwd': {'type': 'string', 'description': 'Working directory'},
              'label': {'type': 'string', 'description': 'Optional label for the terminal'},
            },
            'required': ['project_id', 'command', 'cwd'],
          },
        ),
        handler: _spawnTerminal,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'write_to_terminal',
          description: 'Sends raw bytes to a terminal PTY without appending a newline.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'terminal_id': {'type': 'string'},
              'data': {'type': 'string', 'description': 'Raw text to send'},
            },
            'required': ['terminal_id', 'data'],
          },
        ),
        handler: _writeToTerminal,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'run_command',
          description: 'Sends a command to a terminal followed by Enter.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'terminal_id': {'type': 'string'},
              'command': {'type': 'string'},
            },
            'required': ['terminal_id', 'command'],
          },
        ),
        handler: _runCommand,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'read_terminal',
          description: 'Returns the last N lines from a terminal output buffer.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'terminal_id': {'type': 'string'},
              'lines': {'type': 'integer', 'description': 'Number of lines (default 100)'},
            },
            'required': ['terminal_id'],
          },
        ),
        handler: _readTerminal,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'send_key',
          description:
              'Sends a named key to a terminal PTY. '
              'Supported keys: Enter, Yes, No, ArrowUp, ArrowDown, Escape, Tab.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'terminal_id': {'type': 'string'},
              'key': {
                'type': 'string',
                'enum': ['Enter', 'Yes', 'No', 'ArrowUp', 'ArrowDown', 'Escape', 'Tab'],
              },
            },
            'required': ['terminal_id', 'key'],
          },
        ),
        handler: _sendKey,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'kill_terminal',
          description: 'Kills a terminal process and removes it from the UI.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'terminal_id': {'type': 'string'},
            },
            'required': ['terminal_id'],
          },
        ),
        handler: _killTerminal,
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'list_terminals',
          description: 'Lists all terminals with their ID, label, status, cwd, and last activity.',
          inputSchema: {
            'type': 'object',
            'properties': {},
          },
        ),
        handler: _listTerminals,
      ),
    ];

Future<Map<String, dynamic>> _spawnTerminal(Ref ref, Map<String, dynamic> params) async {
  final projectId = params['project_id'] as String;
  final command = params['command'] as String;
  final cwd = params['cwd'] as String;
  final label = params['label'] as String?;
  final id = 'term-${DateTime.now().millisecondsSinceEpoch}-alfa';
  await Future.delayed(Duration.zero);
  ref.read(terminalsProvider.notifier).addTerminal(
        projectId,
        TerminalEntry(id: id, command: command, cwd: cwd, status: TerminalStatus.running, label: label),
      );
  return {'terminal_id': id};
}

Future<Map<String, dynamic>> _writeToTerminal(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminal_id'] as String;
  final data = params['data'] as String;
  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty == null) return {'error': 'Terminal not found or not running'};
  pty.write(const Utf8Encoder().convert(_interpretEscapes(data)));
  return {'success': true};
}

const _keyMap = <String, String>{
  'Enter': '\r',
  'Yes': 'y\r',
  'No': 'n\r',
  'ArrowUp': '\x1B[A',
  'ArrowDown': '\x1B[B',
  'Escape': '\x1B',
  'Tab': '\t',
};

Future<Map<String, dynamic>> _sendKey(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminal_id'] as String;
  final key = params['key'] as String;
  final sequence = _keyMap[key];
  if (sequence == null) {
    return {'error': 'Unknown key: $key. Supported: ${_keyMap.keys.join(", ")}'};
  }
  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty == null) return {'error': 'Terminal not found or not running'};
  pty.write(const Utf8Encoder().convert(sequence));
  return {'success': true, 'key': key};
}

String _interpretEscapes(String s) {
  return s
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\t', '\t')
      .replaceAll(r'\0', '\x00')
      .replaceAll(r'\\', '\\');
}

Future<Map<String, dynamic>> _runCommand(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminal_id'] as String;
  final command = params['command'] as String;
  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty == null) return {'error': 'Terminal not found or not running'};
  pty.write(const Utf8Encoder().convert('$command\r'));
  return {'success': true};
}

Future<Map<String, dynamic>> _readTerminal(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminal_id'] as String;
  final lines = (params['lines'] as int?) ?? 100;
  final output = ref.read(sessionRegistryProvider.notifier).readOutput(terminalId, lines: lines);
  return {'output': output};
}

Future<Map<String, dynamic>> _killTerminal(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminal_id'] as String;

  // Kill the PTY if still alive
  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty != null) pty.kill();

  // Always remove from UI registry — handles both live and ghost entries
  await Future.delayed(Duration.zero);
  ref.read(terminalsProvider.notifier).removeTerminal(terminalId);

  return {'success': true};
}

Future<Map<String, dynamic>> _listTerminals(Ref ref, Map<String, dynamic> params) async {
  final terminals = ref.read(terminalsProvider).terminals;
  final registry = ref.read(sessionRegistryProvider.notifier);
  final list = terminals.values.map((t) {
    final meta = registry.getMeta(t.id);
    return {
      'id': t.id, 'command': t.command, 'cwd': t.cwd, 'status': t.status.name,
      if (t.label != null) 'label': t.label,
      if (t.exitCode != null) 'exit_code': t.exitCode,
      if (meta != null) 'idle_ms': meta.idleDurationMs,
      if (meta != null) 'activity': meta.activityStatus,
      'is_alfa': t.id.endsWith('-alfa'),
    };
  }).toList();
  return {'terminals': list, 'count': list.length};
}
