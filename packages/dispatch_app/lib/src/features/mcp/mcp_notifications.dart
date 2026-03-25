import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mcp_protocol.dart';
import 'mcp_server.dart';
import '../terminal/terminal_provider.dart';
import '../terminal/session_registry.dart';
import '../projects/projects_provider.dart';

/// Sets up Riverpod listeners that push SSE notifications when state changes.
class McpNotificationManager {
  final Ref ref;
  final McpServer server;
  Timer? _outputDebounce;
  final Map<String, int> _lastOutputLengths = {};
  final List<ProviderSubscription<dynamic>> _subscriptions = [];

  McpNotificationManager(this.ref, this.server);

  void startListening() {
    // Watch terminal state changes
    _subscriptions.add(ref.listen(terminalsProvider, (prev, next) {
      if (prev == null) return;

      // Detect status changes
      for (final entry in next.terminals.entries) {
        final prevTerminal = prev.terminals[entry.key];
        if (prevTerminal != null && prevTerminal.status != entry.value.status) {
          server.notify(McpNotification(
            method: 'terminal_status_changed',
            params: {
              'terminalId': entry.key,
              'status': entry.value.status.name,
              'exitCode': entry.value.exitCode,
            },
          ));
        }
      }
    }));

    // Watch project changes
    _subscriptions.add(ref.listen(projectsProvider, (prev, next) {
      if (prev == null) return;
      if (prev.groups.length != next.groups.length ||
          prev.activeGroupId != next.activeGroupId) {
        server.notify(McpNotification(
          method: 'project_changed',
          params: {
            'activeProjectId': next.activeGroupId,
            'projectCount': next.groups.length,
          },
        ));
      }
    }));

    // Debounced terminal output notifications
    _subscriptions.add(ref.listen(sessionRegistryProvider, (prev, next) {
      _outputDebounce?.cancel();
      _outputDebounce = Timer(const Duration(milliseconds: 200), () {
        for (final entry in next.entries) {
          final currentLength = entry.value.outputBuffer.length;
          final prevLength = _lastOutputLengths[entry.key] ?? 0;
          if (currentLength > prevLength) {
            server.notify(McpNotification(
              method: 'terminal_output',
              params: {
                'terminalId': entry.key,
                'newLines': currentLength - prevLength,
              },
            ));
          }
          _lastOutputLengths[entry.key] = currentLength;
        }
      });
    }));
  }

  void stopListening() {
    _outputDebounce?.cancel();
    for (final sub in _subscriptions) {
      sub.close();
    }
    _subscriptions.clear();
  }
}
