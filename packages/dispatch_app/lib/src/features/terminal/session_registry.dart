import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dispatch_terminal/dispatch_terminal.dart';

/// Global registry of active PTY sessions, keyed by terminal ID.
/// TerminalPane looks up its session here to wire data streams.
class SessionRegistry extends Notifier<Map<String, PtySession>> {
  @override
  Map<String, PtySession> build() => {};

  void register(String terminalId, PtySession session) {
    state = {...state, terminalId: session};
  }

  void unregister(String terminalId) {
    state = Map.of(state)..remove(terminalId);
  }

  PtySession? get(String terminalId) => state[terminalId];
}

final sessionRegistryProvider =
    NotifierProvider<SessionRegistry, Map<String, PtySession>>(
        SessionRegistry.new);
