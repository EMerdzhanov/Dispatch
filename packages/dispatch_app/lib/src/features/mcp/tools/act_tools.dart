import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp_tools.dart';
import '../../terminal/terminal_provider.dart';
import '../../terminal/session_registry.dart';
import '../../projects/projects_provider.dart';
import '../../../core/models/terminal_entry.dart';

Future<void> _deferStateChange(void Function() fn) async {
  await Future.delayed(Duration.zero);
  fn();
}

List<McpToolDefinition> actTools() => [
      McpToolDefinition(
        name: 'run_command',
        description: 'Sends a command to an existing terminal (writes command + newline)',
        inputSchema: {
          'type': 'object',
          'properties': {
            'terminalId': {'type': 'string'},
            'command': {'type': 'string'},
          },
          'required': ['terminalId', 'command'],
        },
        handler: _runCommand,
      ),
      McpToolDefinition(
        name: 'send_key',
        description:
            'Sends a named key to a terminal PTY. '
            'Supported keys: Enter, Yes, No, ArrowUp, ArrowDown, Escape, Tab. '
            '"Yes" sends y + Enter, "No" sends n + Enter.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'terminalId': {'type': 'string'},
            'key': {
              'type': 'string',
              'enum': ['Enter', 'Yes', 'No', 'ArrowUp', 'ArrowDown', 'Escape', 'Tab'],
            },
          },
          'required': ['terminalId', 'key'],
        },
        handler: _sendKey,
      ),
      McpToolDefinition(
        name: 'spawn_terminal',
        description: 'Creates a new terminal with a command and working directory',
        inputSchema: {
          'type': 'object',
          'properties': {
            'command': {'type': 'string'},
            'cwd': {'type': 'string'},
            'projectId': {'type': 'string'},
            'label': {'type': 'string'},
          },
          'required': ['command', 'cwd'],
        },
        handler: _spawnTerminal,
      ),
      McpToolDefinition(
        name: 'kill_terminal',
        description: 'Kills a terminal PTY process and removes it from the UI',
        inputSchema: {
          'type': 'object',
          'properties': {
            'terminalId': {'type': 'string'},
          },
          'required': ['terminalId'],
        },
        handler: _killTerminal,
      ),
      McpToolDefinition(
        name: 'write_to_terminal',
        description: 'Writes raw text to a terminal PTY (no newline appended)',
        inputSchema: {
          'type': 'object',
          'properties': {
            'terminalId': {'type': 'string'},
            'input': {'type': 'string'},
          },
          'required': ['terminalId', 'input'],
        },
        handler: _writeToTerminal,
      ),
    ];

Future<Map<String, dynamic>> _runCommand(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminalId'] as String?;
  final command = params['command'] as String?;
  if (terminalId == null || command == null) {
    throw ArgumentError('terminalId and command are required');
  }

  Pty? pty;
  for (var i = 0; i < 6; i++) {
    pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
    if (pty != null) break;
    await Future.delayed(const Duration(milliseconds: 500));
  }
  if (pty == null) return {'success': false, 'error': 'Terminal PTY not found'};

  pty.write(const Utf8Encoder().convert('$command\r'));
  return {'success': true};
}

final _agentAutoApproveFlags = <RegExp, String>{
  RegExp(r'^claude\b'): '--dangerously-skip-permissions',
  RegExp(r'^codex\b'): '--full-auto',
};

Future<String> _maybeAutoApprove(String command, String? projectId) async {
  if (projectId == null) return command;
  final config = await _readProjectConfig(projectId);
  if (config['auto_approve'] != true) return command;

  for (final entry in _agentAutoApproveFlags.entries) {
    if (entry.key.hasMatch(command) && !command.contains(entry.value)) {
      return '$command ${entry.value}';
    }
  }
  return command;
}

Future<Map<String, dynamic>> _readProjectConfig(String projectId) async {
  final home = Platform.environment['HOME'] ?? '/tmp';
  final file = File('$home/.config/dispatch/project_configs/$projectId.json');
  if (!await file.exists()) return {};
  try {
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

Future<Map<String, dynamic>> _spawnTerminal(Ref ref, Map<String, dynamic> params) async {
  final rawCommand = params['command'] as String?;
  final cwd = params['cwd'] as String?;
  if (rawCommand == null || cwd == null) {
    throw ArgumentError('command and cwd are required');
  }

  final projectId = params['projectId'] as String?;
  final label = params['label'] as String?;

  final groupId = projectId ??
      ref.read(projectsProvider).activeGroupId ??
      ref.read(projectsProvider.notifier).findOrCreateGroup(cwd);

  final command = await _maybeAutoApprove(rawCommand, groupId);
  final terminalId = 'term-${DateTime.now().millisecondsSinceEpoch}-mcp';

  await _deferStateChange(() {
    ref.read(terminalsProvider.notifier).addTerminal(
          groupId,
          TerminalEntry(
            id: terminalId,
            command: command,
            cwd: cwd,
            status: TerminalStatus.running,
            label: label,
          ),
        );
    ref.read(terminalsProvider.notifier).setActiveTerminal(terminalId);
  });

  return {'terminalId': terminalId, 'projectId': groupId};
}

Future<Map<String, dynamic>> _killTerminal(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminalId'] as String?;
  if (terminalId == null) throw ArgumentError('terminalId is required');

  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);

  // Kill the PTY if it's still alive
  if (pty != null) pty.kill();

  // Always remove from UI registry — covers both live and already-dead PTYs
  await _deferStateChange(() {
    ref.read(terminalsProvider.notifier).removeTerminal(terminalId);
  });

  return {'success': true};
}

Future<Map<String, dynamic>> _writeToTerminal(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminalId'] as String?;
  final input = params['input'] as String?;
  if (terminalId == null || input == null) {
    throw ArgumentError('terminalId and input are required');
  }

  Pty? pty;
  for (var i = 0; i < 6; i++) {
    pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
    if (pty != null) break;
    await Future.delayed(const Duration(milliseconds: 500));
  }
  if (pty == null) return {'success': false, 'error': 'Terminal PTY not found'};

  pty.write(const Utf8Encoder().convert(_interpretEscapes(input)));
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
  final terminalId = params['terminalId'] as String?;
  final key = params['key'] as String?;
  if (terminalId == null || key == null) {
    throw ArgumentError('terminalId and key are required');
  }

  final sequence = _keyMap[key];
  if (sequence == null) {
    return {'success': false, 'error': 'Unknown key: $key. Supported: ${_keyMap.keys.join(", ")}'};
  }

  Pty? pty;
  for (var i = 0; i < 6; i++) {
    pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
    if (pty != null) break;
    await Future.delayed(const Duration(milliseconds: 500));
  }
  if (pty == null) return {'success': false, 'error': 'Terminal PTY not found'};

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
