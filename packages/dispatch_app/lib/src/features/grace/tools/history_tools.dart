import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grace_types.dart';
import '../tool_executor.dart';
import '../../terminal/session_registry.dart';
import '../../terminal/terminal_provider.dart';
import '../../projects/projects_provider.dart';

List<GraceToolEntry> historyTools() => [
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'get_terminal_history',
          description:
              'Returns the recent output from a terminal, including commands and their output. '
              'Use this to understand what the user has been doing, see error messages, '
              'or suggest the next command. Returns the last N lines of terminal output.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'terminalId': {
                'type': 'string',
                'description':
                    'Terminal ID. Omit to use the active terminal.',
              },
              'lines': {
                'type': 'integer',
                'description':
                    'Number of recent lines to return (default 50, max 200)',
              },
            },
          },
        ),
        handler: _getTerminalHistory,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'get_all_terminal_summaries',
          description:
              'Returns a summary of all open terminals in the active project: '
              'terminal ID, label/name, status, last few lines of output. '
              'Use this to get an overview of what is running.',
          inputSchema: {
            'type': 'object',
            'properties': {},
          },
        ),
        handler: _getAllTerminalSummaries,
      ),
    ];

Future<Map<String, dynamic>> _getTerminalHistory(
    Ref ref, Map<String, dynamic> params) async {
  final registry = ref.read(sessionRegistryProvider.notifier);
  final terminals = ref.read(terminalsProvider);

  var terminalId = params['terminalId'] as String?;
  terminalId ??= terminals.activeTerminalId;
  if (terminalId == null) return {'error': 'No active terminal'};

  final lines = (params['lines'] as int?) ?? 50;
  final clamped = lines.clamp(1, 200);

  final output = registry.readOutput(terminalId, lines: clamped);
  final entry = terminals.terminals[terminalId];

  return {
    'terminalId': terminalId,
    'label': entry?.label ?? entry?.command.split(' ').first ?? 'unknown',
    'status': entry?.status.name ?? 'unknown',
    'cwd': entry?.cwd ?? 'unknown',
    'output': output,
    'lineCount': output.split('\n').length,
  };
}

Future<Map<String, dynamic>> _getAllTerminalSummaries(
    Ref ref, Map<String, dynamic> params) async {
  final registry = ref.read(sessionRegistryProvider.notifier);
  final terminals = ref.read(terminalsProvider);
  final projects = ref.read(projectsProvider);

  final activeGroup = projects.groups
      .where((g) => g.id == projects.activeGroupId)
      .firstOrNull;
  if (activeGroup == null) return {'terminals': <dynamic>[], 'count': 0};

  final groupTerminalIds = activeGroup.terminalIds;

  final summaries = groupTerminalIds.map((id) {
    final entry = terminals.terminals[id];
    if (entry == null) return null;
    final lastLines = registry.readOutput(id, lines: 5);
    return {
      'id': id,
      'label': entry.label ?? entry.command.split(' ').first.split('/').last,
      'command': entry.command,
      'status': entry.status.name,
      'cwd': entry.cwd,
      'lastOutput': lastLines,
    };
  }).whereType<Map<String, dynamic>>().toList();

  return {
    'terminals': summaries,
    'count': summaries.length,
    'activeTerminalId': terminals.activeTerminalId,
  };
}
