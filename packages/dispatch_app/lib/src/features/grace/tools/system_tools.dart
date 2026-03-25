import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grace_types.dart';
import '../tool_executor.dart';
import '../../terminal/session_registry.dart';
import '../../terminal/terminal_provider.dart';
import '../../../core/models/terminal_entry.dart';

final _ansiStripper = RegExp(
    r'\x1B\[[0-9;]*[a-zA-Z]|\x1B\].*?\x07|\x1B[()][AB012]|\x1B\[[\?]?[0-9;]*[hlm]');

List<GraceToolEntry> systemTools() => [
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'notify',
          description:
              'Send a macOS system notification. Use to alert the user about '
              'completed tasks, errors, or events that need attention.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'title': {
                'type': 'string',
                'description': 'Notification title',
              },
              'message': {
                'type': 'string',
                'description': 'Notification body text',
              },
              'sound': {
                'type': 'boolean',
                'description': 'Play notification sound (default true)',
              },
            },
            'required': ['title', 'message'],
          },
        ),
        handler: _notify,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'screenshot_terminal',
          description:
              'Capture the current text content of a terminal as plain text '
              '(ANSI codes stripped). Use to inspect what is currently visible '
              'in a terminal without running a command.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'terminal_id': {
                'type': 'string',
                'description':
                    'Terminal to capture. Defaults to the active terminal.',
              },
              'lines': {
                'type': 'integer',
                'description': 'Number of lines to capture (default 100)',
              },
            },
          },
        ),
        handler: _screenshotTerminal,
      ),
    ];

String _escapeOsascript(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

Future<Map<String, dynamic>> _notify(
    Ref ref, Map<String, dynamic> params) async {
  final title = params['title'] as String;
  final message = params['message'] as String;
  final sound = (params['sound'] as bool?) ?? true;

  final safeTitle = _escapeOsascript(title);
  final safeMessage = _escapeOsascript(message);

  final script = StringBuffer()
    ..write('display notification "$safeMessage" with title "$safeTitle"');
  if (sound) script.write(' sound name "default"');

  final result = await Process.run('osascript', ['-e', script.toString()]);

  if (result.exitCode != 0) {
    return {'error': 'osascript failed: ${result.stderr}'};
  }
  return {'success': true};
}

Future<Map<String, dynamic>> _screenshotTerminal(
    Ref ref, Map<String, dynamic> params) async {
  final lines = (params['lines'] as int?) ?? 100;
  final registry = ref.read(sessionRegistryProvider.notifier);

  String? terminalId = params['terminal_id'] as String?;

  // If no terminal_id provided, find the active terminal
  if (terminalId == null) {
    final terminals = ref.read(terminalsProvider).terminals;
    if (terminals.isEmpty) {
      return {'error': 'No terminals available'};
    }
    // Pick the active terminal (first running one, or just the first)
    final active = terminals.values.firstWhere(
      (t) => t.status == TerminalStatus.running,
      orElse: () => terminals.values.first,
    );
    terminalId = active.id;
  }

  final rawOutput = registry.readOutput(terminalId, lines: lines);
  if (rawOutput.isEmpty) {
    return {
      'terminal_id': terminalId,
      'content': '',
      'rows': 0,
    };
  }

  final stripped = rawOutput.replaceAll(_ansiStripper, '');
  final outputLines = stripped.split('\n');

  // Look up terminal label
  final entry = ref.read(terminalsProvider).terminals[terminalId];

  return {
    'terminal_id': terminalId,
    if (entry?.label != null) 'label': entry!.label,
    'rows': outputLines.length,
    'content': stripped,
  };
}
