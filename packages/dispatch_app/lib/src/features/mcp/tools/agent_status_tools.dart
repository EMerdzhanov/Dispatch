import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp_tools.dart';
import '../../settings/agent_status_checker.dart';

List<McpToolDefinition> agentStatusTools() => [
      McpToolDefinition(
        name: 'get_agent_status',
        description:
            'Returns the current auth/health status of all known AI coding agents '
            '(Claude Code, Gemini CLI, Codex CLI, GitHub Copilot, Grok CLI, Kimi CLI). '
            'Use this before spawning an agent to verify it is authenticated and ready. '
            'If an agent shows auth_required or not_installed, inform the user instead '
            'of spawning a broken terminal.',
        inputSchema: {'type': 'object', 'properties': {}},
        handler: _getAgentStatus,
      ),
    ];

Future<Map<String, dynamic>> _getAgentStatus(
    Ref ref, Map<String, dynamic> params) async {
  // Trigger a check (respects cache)
  await ref.read(agentStatusProvider.notifier).checkAll();

  final statuses = ref.read(agentStatusProvider);
  return {
    'agents': statuses.values.map((s) => s.toJson()).toList(),
  };
}
