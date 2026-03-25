import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grace_types.dart';
import '../tool_executor.dart';

// ---------------------------------------------------------------------------
// Task complexity classification
// ---------------------------------------------------------------------------

enum TaskComplexity { simple, moderate, complex }

enum TaskDomain {
  codeRefactor,
  frontendUi,
  debugging,
  documentation,
  testing,
  dataAnalysis,
  shellScript,
  general,
}

class RoutingDecision {
  final String agent; // 'claude_code', 'gemini', 'codex', 'bash'
  final String command; // actual CLI command to spawn
  final String rationale;
  final TaskComplexity complexity;
  final TaskDomain domain;

  const RoutingDecision({
    required this.agent,
    required this.command,
    required this.rationale,
    required this.complexity,
    required this.domain,
  });

  Map<String, dynamic> toJson() => {
        'agent': agent,
        'command': command,
        'rationale': rationale,
        'complexity': complexity.name,
        'domain': domain.name,
      };
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

class TaskRouter {
  static RoutingDecision route({
    required String task,
    required Map<String, bool> available,
  }) {
    final complexity = _classifyComplexity(task);
    final domain = _classifyDomain(task);
    return _pick(task, complexity, domain, available);
  }

  static TaskComplexity _classifyComplexity(String task) {
    final lower = task.toLowerCase();

    const simpleSignals = [
      'rename', 'move file', 'add comment', 'update readme',
      'fix typo', 'change color', 'update version', 'add import',
      'echo', 'list files', 'run script', 'simple',
    ];
    if (simpleSignals.any((s) => lower.contains(s))) {
      return TaskComplexity.simple;
    }

    const complexSignals = [
      'refactor', 'migrate', 'architect', 'redesign', 'rewrite',
      'implement', 'build', 'integrate', 'auth', 'authentication',
      'payment', 'database schema', 'api design', 'multi-step',
      'pipeline', 'performance', 'security', 'complex',
    ];
    if (complexSignals.any((s) => lower.contains(s))) {
      return TaskComplexity.complex;
    }

    return TaskComplexity.moderate;
  }

  static TaskDomain _classifyDomain(String task) {
    final lower = task.toLowerCase();

    if (_any(lower, ['refactor', 'extract', 'decouple', 'migrate code', 'rename class'])) {
      return TaskDomain.codeRefactor;
    }
    if (_any(lower, ['ui', 'component', 'css', 'style', 'layout', 'design', 'frontend', 'react', 'widget', 'animation', 'color', 'theme'])) {
      return TaskDomain.frontendUi;
    }
    if (_any(lower, ['debug', 'fix bug', 'error', 'crash', 'failing', 'broken', 'exception', 'stack trace'])) {
      return TaskDomain.debugging;
    }
    if (_any(lower, ['test', 'spec', 'coverage', 'unit test', 'integration test'])) {
      return TaskDomain.testing;
    }
    if (_any(lower, ['document', 'readme', 'comment', 'docstring', 'jsdoc', 'explain'])) {
      return TaskDomain.documentation;
    }
    if (_any(lower, ['analyze', 'data', 'csv', 'report', 'chart', 'metrics', 'statistics'])) {
      return TaskDomain.dataAnalysis;
    }
    if (_any(lower, ['script', 'bash', 'shell', 'chmod', 'cron', 'deploy', 'run command'])) {
      return TaskDomain.shellScript;
    }

    return TaskDomain.general;
  }

  static bool _any(String text, List<String> patterns) =>
      patterns.any((p) => text.contains(p));

  static RoutingDecision _pick(
    String task,
    TaskComplexity complexity,
    TaskDomain domain,
    Map<String, bool> available,
  ) {
    final claudeOk = available['claude_code'] ?? false;
    final geminiOk = available['gemini'] ?? false;
    final codexOk = available['codex'] ?? false;

    // Simple shell task — skip agent entirely
    if (domain == TaskDomain.shellScript && complexity == TaskComplexity.simple) {
      return RoutingDecision(
        agent: 'bash',
        command: 'bash',
        rationale: 'Simple shell script — no agent overhead needed',
        complexity: complexity,
        domain: domain,
      );
    }

    // Frontend UI — Gemini preferred
    if (domain == TaskDomain.frontendUi &&
        complexity != TaskComplexity.simple &&
        geminiOk) {
      return RoutingDecision(
        agent: 'gemini',
        command: 'gemini',
        rationale: 'Frontend UI work — Gemini performs well on component/CSS tasks',
        complexity: complexity,
        domain: domain,
      );
    }

    // Documentation — Gemini is fast
    if (domain == TaskDomain.documentation && geminiOk) {
      return RoutingDecision(
        agent: 'gemini',
        command: 'gemini',
        rationale: 'Documentation — Gemini is fast and good at prose',
        complexity: complexity,
        domain: domain,
      );
    }

    // Simple tasks — Codex is cheap
    if (complexity == TaskComplexity.simple && codexOk) {
      return RoutingDecision(
        agent: 'codex',
        command: 'codex',
        rationale: 'Simple task — Codex is fast and cheap',
        complexity: complexity,
        domain: domain,
      );
    }

    // Default: Claude Code for everything complex/general
    if (claudeOk) {
      final reason = switch (domain) {
        TaskDomain.codeRefactor =>
          'Complex refactor — Claude Code excels at multi-file reasoning',
        TaskDomain.debugging =>
          'Debugging — Claude Code handles complex error analysis well',
        _ => 'General task — Claude Code as default high-quality agent',
      };
      return RoutingDecision(
        agent: 'claude_code',
        command: 'claude',
        rationale: reason,
        complexity: complexity,
        domain: domain,
      );
    }

    // Fallbacks
    if (geminiOk) {
      return RoutingDecision(
        agent: 'gemini', command: 'gemini',
        rationale: 'Fallback — only Gemini available',
        complexity: complexity, domain: domain,
      );
    }
    if (codexOk) {
      return RoutingDecision(
        agent: 'codex', command: 'codex',
        rationale: 'Fallback — only Codex available',
        complexity: complexity, domain: domain,
      );
    }

    return RoutingDecision(
      agent: 'claude_code', command: 'claude',
      rationale: 'No authenticated agents detected — defaulting to Claude Code',
      complexity: complexity, domain: domain,
    );
  }
}

// ---------------------------------------------------------------------------
// Grace tool entry
// ---------------------------------------------------------------------------

List<GraceToolEntry> routingTools() => [
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'route_task',
          description:
              'Decide which AI agent is best for a task. '
              'Classifies by complexity (simple/moderate/complex) and domain '
              '(refactor, frontend UI, debugging, docs, testing, shell, etc.). '
              'Returns recommended agent + command to spawn. '
              'Pass available_agents from get_agent_status to skip unavailable ones.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'task': {
                'type': 'string',
                'description': 'Description of the task',
              },
              'available_agents': {
                'type': 'object',
                'description':
                    'Map of agent → bool from get_agent_status. '
                    'Keys: claude_code, gemini, codex. Defaults all to true.',
                'additionalProperties': {'type': 'boolean'},
              },
            },
            'required': ['task'],
          },
        ),
        handler: _routeTask,
      ),
    ];

Future<Map<String, dynamic>> _routeTask(
    Ref ref, Map<String, dynamic> params) async {
  final task = params['task'] as String;
  final rawAvailable =
      (params['available_agents'] as Map<String, dynamic>?) ?? {};

  final available = <String, bool>{
    'claude_code': true,
    'gemini': true,
    'codex': true,
    ...rawAvailable.map((k, v) => MapEntry(k, v as bool)),
  };

  final decision = TaskRouter.route(task: task, available: available);
  return decision.toJson();
}
