import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp_tools.dart';
import '../../terminal/terminal_provider.dart';
import '../../terminal/session_registry.dart';
import '../../projects/projects_provider.dart';
import '../../../core/models/terminal_entry.dart';

/// Schedule a state modification outside Flutter's build phase.
Future<void> _deferStateChange(void Function() fn) {
  final completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    fn();
    completer.complete();
  });
  return completer.future;
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
        description: 'Kills a terminal PTY process',
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

  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty == null) return {'success': false, 'error': 'Terminal PTY not found'};

  pty.write(const Utf8Encoder().convert('$command\n'));
  return {'success': true};
}

Future<Map<String, dynamic>> _spawnTerminal(Ref ref, Map<String, dynamic> params) async {
  final command = params['command'] as String?;
  final cwd = params['cwd'] as String?;
  if (command == null || cwd == null) {
    throw ArgumentError('command and cwd are required');
  }

  final projectId = params['projectId'] as String?;
  final label = params['label'] as String?;

  // Find or create group
  final groupId = projectId ??
      ref.read(projectsProvider).activeGroupId ??
      ref.read(projectsProvider.notifier).findOrCreateGroup(cwd);

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
  if (pty == null) return {'success': false, 'error': 'Terminal PTY not found'};

  pty.kill();
  return {'success': true};
}

Future<Map<String, dynamic>> _writeToTerminal(Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminalId'] as String?;
  final input = params['input'] as String?;
  if (terminalId == null || input == null) {
    throw ArgumentError('terminalId and input are required');
  }

  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty == null) return {'success': false, 'error': 'Terminal PTY not found'};

  pty.write(const Utf8Encoder().convert(input));
  return {'success': true};
}
