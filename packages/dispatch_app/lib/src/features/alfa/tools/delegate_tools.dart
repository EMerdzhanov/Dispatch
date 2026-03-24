import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alfa_types.dart';
import '../agents_state.dart';
import '../tool_executor.dart';
import '../../projects/projects_provider.dart';
import '../../terminal/terminal_provider.dart';
import '../../terminal/session_registry.dart';
import '../../../core/models/terminal_entry.dart';

final _ansiRe = RegExp(
    r'\x1B\[[0-9;]*[A-Za-z]|\x1B\][^\x07]*\x07|\x1B[()][A-B012]');

const _agentCommands = {
  'claude': 'claude --dangerously-skip-permissions',
  'gemini': 'gemini',
  'codex': 'codex --full-auto',
  'bash': 'bash',
};

final _defaultCompletionSignals = [
  RegExp(r'>\s*$', multiLine: true),
  RegExp(r'\bDone\b', caseSensitive: false),
  RegExp(r'\bCompleted\b', caseSensitive: false),
  RegExp(r'\bFinished\b', caseSensitive: false),
  RegExp(r'^\s*\$\s*$', multiLine: true),
  RegExp(r'gemini>\s*$', multiLine: true),
];

List<AlfaToolEntry> delegateTools(
  AgentsState agentsState,
  void Function(AlfaChatEvent) onEvent,
) =>
    [
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'delegate_to_agent',
          description:
              'Delegate a task to a subagent (claude, gemini, codex, or bash) '
              'and wait for it to complete. Returns a structured result with '
              'completed status, summary, and output preview. '
              'This is the correct way to assign work to a subagent — '
              'do NOT manually spawn + run_command + poll. '
              'Alfa is the orchestrator; subagents do the execution. '
              'Call route_task + get_agent_status first if unsure which agent to use.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'agent': {
                'type': 'string',
                'enum': ['claude', 'gemini', 'codex', 'bash'],
                'description': 'Which agent to delegate to.',
              },
              'task': {
                'type': 'string',
                'description':
                    'Full task description sent as the first prompt to the subagent. '
                    'Be specific — include file paths, expected behaviour, output format.',
              },
              'cwd': {
                'type': 'string',
                'description': 'Working directory. Defaults to active project.',
              },
              'success_signal': {
                'type': 'string',
                'description':
                    'Optional regex to detect completion in terminal output. '
                    'Defaults to standard idle prompt detection.',
              },
              'timeout_seconds': {
                'type': 'integer',
                'description': 'Max wait seconds (default 300, max 900).',
              },
              'context': {
                'type': 'string',
                'description':
                    'Optional context injected before the task prompt '
                    '(e.g. output from a previous subagent).',
              },
            },
            'required': ['agent', 'task'],
          },
        ),
        handler: (ref, params) =>
            _delegateToAgent(ref, params, agentsState, onEvent),
      ),

      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'list_subagents',
          description:
              'List all active subagent terminals with ID, agent type, task, '
              'status, and running duration. Use to check delegated work.',
          inputSchema: {'type': 'object', 'properties': {}},
        ),
        handler: (ref, params) => _listSubagents(ref, agentsState),
      ),

      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'read_subagent_output',
          description:
              'Read the latest output from a running subagent without interrupting it.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'terminal_id': {'type': 'string'},
              'lines': {'type': 'integer', 'description': 'Lines to read (default 50)'},
            },
            'required': ['terminal_id'],
          },
        ),
        handler: (ref, params) => _readSubagentOutput(ref, params),
      ),

      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'send_to_subagent',
          description:
              'Send a follow-up message or clarification to a running subagent. '
              'Use when the subagent asks a question mid-task.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'terminal_id': {'type': 'string'},
              'message': {'type': 'string', 'description': 'Message to send'},
            },
            'required': ['terminal_id', 'message'],
          },
        ),
        handler: (ref, params) => _sendToSubagent(ref, params),
      ),

      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'cancel_subagent',
          description:
              'Cancel a running subagent: sends Ctrl-C, kills terminal, removes from UI, cleans agents.json.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'terminal_id': {'type': 'string'},
              'reason': {'type': 'string'},
            },
            'required': ['terminal_id'],
          },
        ),
        handler: (ref, params) => _cancelSubagent(ref, params, agentsState),
      ),
    ];

Future<Map<String, dynamic>> _delegateToAgent(
  Ref ref,
  Map<String, dynamic> params,
  AgentsState agentsState,
  void Function(AlfaChatEvent) onEvent,
) async {
  final agent = params['agent'] as String;
  final task = params['task'] as String;
  final cwd = (params['cwd'] as String?) ?? _activeCwd(ref);
  final customSignal = params['success_signal'] as String?;
  final timeoutSeconds =
      ((params['timeout_seconds'] as int?) ?? 300).clamp(10, 900);
  final context = params['context'] as String?;

  if (cwd == null) return {'error': 'No active project and no cwd provided'};

  final command = _agentCommands[agent];
  if (command == null) return {'error': 'Unknown agent: $agent'};

  final terminalId = 'term-${DateTime.now().millisecondsSinceEpoch}-alfa';
  final projectId = _activeProjectId(ref) ?? '';
  final label =
      '[$agent] ${task.length > 40 ? '${task.substring(0, 40)}...' : task}';

  await Future.delayed(Duration.zero);
  ref.read(terminalsProvider.notifier).addTerminal(
        projectId,
        TerminalEntry(
          id: terminalId,
          command: command,
          cwd: cwd,
          status: TerminalStatus.running,
          label: label,
        ),
      );

  await agentsState.registerAgent(
    terminalId: terminalId,
    task: task,
    project: cwd,
    successSignal: customSignal,
    isAgent: true,
  );

  final shortTask = task.length > 80 ? '${task.substring(0, 80)}...' : task;
  onEvent(AlfaChatEvent.alfa(
      '[Delegate] Spawned $agent → $terminalId\nTask: "$shortTask"'));

  // Wait for PTY (up to 5s)
  var ptyReady = false;
  for (var i = 0; i < 10; i++) {
    await Future.delayed(const Duration(milliseconds: 500));
    if (ref.read(sessionRegistryProvider.notifier).getPty(terminalId) != null) {
      ptyReady = true;
      break;
    }
  }

  if (!ptyReady) {
    await agentsState.removeAgent(terminalId);
    await Future.delayed(Duration.zero);
    ref.read(terminalsProvider.notifier).removeTerminal(terminalId);
    return {'error': 'PTY failed to start for $agent in $cwd'};
  }

  // Wait for agent welcome screen to render
  await Future.delayed(const Duration(seconds: 2));

  if (context != null && context.isNotEmpty) {
    _writeToPty(ref, terminalId,
        'Context from orchestrator:\n$context\n\nNow complete the following task:');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Send the task text
  _writeToPty(ref, terminalId, task);

  // FIX: Claude Code's multi-line paste detection holds the text waiting for
  // confirmation. Send an explicit Enter 1 second later to force submission.
  await Future.delayed(const Duration(seconds: 1));
  _sendEnter(ref, terminalId);

  // Poll for completion
  final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
  final signals = [
    if (customSignal != null) RegExp(customSignal, caseSensitive: false),
    ..._defaultCompletionSignals,
  ];

  var lastOutput = '';
  var completed = false;
  var idleCount = 0;

  while (DateTime.now().isBefore(deadline)) {
    await Future.delayed(const Duration(seconds: 3));

    final raw = ref
        .read(sessionRegistryProvider.notifier)
        .readOutput(terminalId, lines: 30);
    final stripped = raw.replaceAll(_ansiRe, '');

    if (signals.any((p) => p.hasMatch(stripped)) &&
        stripped.trim().length > 50) {
      lastOutput = stripped;
      completed = true;
      break;
    }

    if (stripped == lastOutput) {
      idleCount++;
      if (idleCount >= 10) {
        completed = true;
        break;
      }
    } else {
      idleCount = 0;
      lastOutput = stripped;
    }
  }

  final result = _extractResult(lastOutput, completed);
  await agentsState.updateAgent(terminalId,
      status: completed ? 'done' : 'timeout');

  onEvent(AlfaChatEvent.alfa(
      '[Delegate] $agent $terminalId ${completed ? "✓ done" : "✗ timeout"}: ${result['summary']}'));

  return {
    'terminal_id': terminalId,
    'agent': agent,
    'completed': completed,
    'timed_out': !completed,
    ...result,
  };
}

/// Write text followed by carriage return.
void _writeToPty(Ref ref, String terminalId, String text) {
  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty == null) return;
  pty.write(utf8.encode('$text\r'));
}

/// Send a bare carriage return — used to confirm multi-line pastes.
void _sendEnter(Ref ref, String terminalId) {
  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty == null) return;
  pty.write(utf8.encode('\r'));
}

Map<String, dynamic> _extractResult(String output, bool completed) {
  if (output.isEmpty) {
    return {
      'summary': completed ? 'Task completed (no output captured)' : 'Timed out — no output captured',
      'output_preview': '',
    };
  }

  final lines = output
      .split('\n')
      .map((l) => l.trim())
      .where((l) =>
          l.isNotEmpty &&
          l != '>' &&
          l != r'$' &&
          l != 'gemini>' &&
          !l.startsWith('\x1B'))
      .toList();

  final preview = lines.length > 10
      ? lines.sublist(lines.length - 10).join('\n')
      : lines.join('\n');

  final summaryMatch = RegExp(
    r'(?:summary|completed|done|finished)[:\s]+(.+)',
    caseSensitive: false,
  ).firstMatch(output);

  final summary = summaryMatch != null
      ? (summaryMatch.group(1)?.trim() ?? preview)
      : (lines.isNotEmpty ? lines.last : 'Task processed');

  return {
    'summary': summary.length > 500 ? '${summary.substring(0, 500)}...' : summary,
    'output_preview': preview.length > 1000
        ? '${preview.substring(0, 1000)}...'
        : preview,
  };
}

Future<Map<String, dynamic>> _listSubagents(
    Ref ref, AgentsState agentsState) async {
  final state = await agentsState.readState();
  final agents = (state['agents'] as Map<String, dynamic>?) ?? {};
  if (agents.isEmpty) return {'subagents': [], 'count': 0};

  final terminals = ref.read(terminalsProvider).terminals;
  final now = DateTime.now().toUtc();

  final list = agents.entries.map((e) {
    final a = e.value as Map<String, dynamic>;
    final spawnedAt = DateTime.tryParse(a['spawned_at'] as String? ?? '');
    final t = terminals[e.key];
    return {
      'terminal_id': e.key,
      'agent': _inferAgent(t?.command ?? ''),
      'task': a['task'],
      'status': a['status'],
      'running_for': spawnedAt != null
          ? '${now.difference(spawnedAt).inSeconds}s'
          : 'unknown',
      'is_alive': t != null,
      if ((a['files_claimed'] as List?)?.isNotEmpty ?? false)
        'files_claimed': a['files_claimed'],
    };
  }).toList();

  return {'subagents': list, 'count': list.length};
}

String _inferAgent(String cmd) {
  if (cmd.contains('claude')) return 'claude';
  if (cmd.contains('gemini')) return 'gemini';
  if (cmd.contains('codex')) return 'codex';
  if (cmd.contains('bash')) return 'bash';
  return 'unknown';
}

Future<Map<String, dynamic>> _readSubagentOutput(
    Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminal_id'] as String;
  final lines = (params['lines'] as int?) ?? 50;
  final raw = ref
      .read(sessionRegistryProvider.notifier)
      .readOutput(terminalId, lines: lines);
  return {
    'terminal_id': terminalId,
    'output': raw.replaceAll(_ansiRe, ''),
  };
}

Future<Map<String, dynamic>> _sendToSubagent(
    Ref ref, Map<String, dynamic> params) async {
  final terminalId = params['terminal_id'] as String;
  final message = params['message'] as String;
  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty == null) return {'error': 'Terminal $terminalId not found'};
  pty.write(utf8.encode('$message\r'));
  return {'success': true, 'terminal_id': terminalId};
}

Future<Map<String, dynamic>> _cancelSubagent(
  Ref ref,
  Map<String, dynamic> params,
  AgentsState agentsState,
) async {
  final terminalId = params['terminal_id'] as String;
  final reason = (params['reason'] as String?) ?? 'Cancelled by Alfa';

  final pty = ref.read(sessionRegistryProvider.notifier).getPty(terminalId);
  if (pty != null) {
    pty.write(utf8.encode('\x03'));
    await Future.delayed(const Duration(milliseconds: 300));
    pty.kill();
  }

  await Future.delayed(Duration.zero);
  ref.read(terminalsProvider.notifier).removeTerminal(terminalId);

  await agentsState.updateAgent(terminalId, status: 'cancelled');
  await agentsState.removeAgent(terminalId);

  return {'success': true, 'terminal_id': terminalId, 'reason': reason};
}

String? _activeCwd(Ref ref) {
  final state = ref.read(projectsProvider);
  return state.groups
      .where((g) => g.id == state.activeGroupId)
      .firstOrNull
      ?.cwd;
}

String? _activeProjectId(Ref ref) => ref.read(projectsProvider).activeGroupId;
