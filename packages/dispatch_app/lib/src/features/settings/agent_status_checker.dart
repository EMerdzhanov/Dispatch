import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgentStatus {
  final String name;
  final String command;
  final String state; // 'ok', 'auth_required', 'not_installed', 'checking'
  final String? version;
  final String? detail;

  const AgentStatus({
    required this.name,
    required this.command,
    required this.state,
    this.version,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'state': state,
        if (version != null) 'version': version,
        if (detail != null) 'detail': detail,
      };
}

/// Known agent definitions: name, version command, and fix action info.
class AgentDef {
  final String name;
  final String versionCommand;
  final String fixAction; // 'browser', 'terminal', 'instructions'
  final String fixDetail; // URL, command, or text

  const AgentDef({
    required this.name,
    required this.versionCommand,
    required this.fixAction,
    required this.fixDetail,
  });
}

const knownAgents = [
  AgentDef(
    name: 'Claude Code',
    versionCommand: 'claude --version',
    fixAction: 'instructions',
    fixDetail: 'Run: claude login',
  ),
  AgentDef(
    name: 'Gemini CLI',
    versionCommand: 'gemini --version',
    fixAction: 'terminal',
    fixDetail: 'gemini auth login',
  ),
  AgentDef(
    name: 'Codex CLI',
    versionCommand: 'codex --version',
    fixAction: 'instructions',
    fixDetail: 'Set OPENAI_API_KEY environment variable',
  ),
  AgentDef(
    name: 'GitHub Copilot',
    versionCommand: 'gh copilot --version',
    fixAction: 'instructions',
    fixDetail: 'Run: gh auth login && gh extension install github/gh-copilot',
  ),
  AgentDef(
    name: 'Grok CLI',
    versionCommand: 'grok --version',
    fixAction: 'instructions',
    fixDetail: 'Run: grok auth login',
  ),
  AgentDef(
    name: 'Kimi CLI',
    versionCommand: 'kimi --version',
    fixAction: 'instructions',
    fixDetail: 'Run: kimi auth login',
  ),
];

class AgentStatusChecker extends Notifier<Map<String, AgentStatus>> {
  DateTime? _lastCheck;
  static const _cacheDuration = Duration(seconds: 60);

  @override
  Map<String, AgentStatus> build() {
    // Initialize with 'checking' state for all agents
    return {
      for (final agent in knownAgents)
        agent.name: AgentStatus(
          name: agent.name,
          command: agent.versionCommand,
          state: 'checking',
        ),
    };
  }

  /// Check all agents, respecting cache.
  Future<void> checkAll({bool force = false}) async {
    if (!force && _lastCheck != null) {
      final elapsed = DateTime.now().difference(_lastCheck!);
      if (elapsed < _cacheDuration) return;
    }

    final results = await Future.wait(
      knownAgents.map((a) => _checkAgent(a)),
    );

    state = {for (final s in results) s.name: s};
    _lastCheck = DateTime.now();
  }

  /// Re-check a single agent (bypasses cache for that agent).
  Future<void> checkOne(String name) async {
    final agentDef = knownAgents.where((a) => a.name == name).firstOrNull;
    if (agentDef == null) return;

    // Set to 'checking' first
    state = {
      ...state,
      name: AgentStatus(
        name: name,
        command: agentDef.versionCommand,
        state: 'checking',
      ),
    };

    final result = await _checkAgent(agentDef);
    state = {...state, name: result};
  }

  static Future<AgentStatus> _checkAgent(AgentDef agent) async {
    try {
      final result = await Process.run(
        '/bin/sh',
        ['-c', agent.versionCommand],
        environment: Platform.environment,
      ).timeout(const Duration(seconds: 5));

      if (result.exitCode == 0) {
        final output = (result.stdout as String).trim();
        final version = output.split('\n').first.trim();
        return AgentStatus(
          name: agent.name,
          command: agent.versionCommand,
          state: 'ok',
          version: version,
        );
      } else {
        final stderr = (result.stderr as String).trim();
        if (stderr.contains('auth') ||
            stderr.contains('login') ||
            stderr.contains('credential')) {
          return AgentStatus(
            name: agent.name,
            command: agent.versionCommand,
            state: 'auth_required',
            detail: agent.fixDetail,
          );
        }
        return AgentStatus(
          name: agent.name,
          command: agent.versionCommand,
          state: 'auth_required',
          detail: stderr.split('\n').first,
        );
      }
    } on TimeoutException {
      return AgentStatus(
        name: agent.name,
        command: agent.versionCommand,
        state: 'auth_required',
        detail: 'Timed out',
      );
    } catch (_) {
      return AgentStatus(
        name: agent.name,
        command: agent.versionCommand,
        state: 'not_installed',
      );
    }
  }
}

final agentStatusProvider =
    NotifierProvider<AgentStatusChecker, Map<String, AgentStatus>>(
  AgentStatusChecker.new,
);
