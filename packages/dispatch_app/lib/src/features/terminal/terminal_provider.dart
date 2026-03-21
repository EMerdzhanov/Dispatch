import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/terminal_entry.dart';
import '../projects/projects_provider.dart';

class TerminalsState {
  final Map<String, TerminalEntry> terminals;
  final String? activeTerminalId;
  final bool zenMode;

  const TerminalsState({
    this.terminals = const {},
    this.activeTerminalId,
    this.zenMode = false,
  });

  TerminalsState copyWith({
    Map<String, TerminalEntry>? terminals,
    String? Function()? activeTerminalId,
    bool? zenMode,
  }) {
    return TerminalsState(
      terminals: terminals ?? this.terminals,
      activeTerminalId:
          activeTerminalId != null ? activeTerminalId() : this.activeTerminalId,
      zenMode: zenMode ?? this.zenMode,
    );
  }
}

class TerminalsNotifier extends Notifier<TerminalsState> {
  @override
  TerminalsState build() => const TerminalsState();

  void addTerminal(String groupId, TerminalEntry terminal) {
    final updated = Map<String, TerminalEntry>.from(state.terminals);
    updated[terminal.id] = terminal;
    state = state.copyWith(terminals: updated);
    ref.read(projectsProvider.notifier).addTerminalToGroup(groupId, terminal.id);
  }

  void removeTerminal(String id) {
    final updated = Map<String, TerminalEntry>.from(state.terminals)..remove(id);
    ref.read(projectsProvider.notifier).removeTerminalFromGroup(id);
    state = state.copyWith(
      terminals: updated,
      activeTerminalId:
          state.activeTerminalId == id ? () => null : null,
    );
  }

  void setActiveTerminal(String id) {
    state = state.copyWith(activeTerminalId: () => id);
  }

  void updateStatus(String id, TerminalStatus status, {int? exitCode}) {
    final terminal = state.terminals[id];
    if (terminal == null) return;
    final updated = Map<String, TerminalEntry>.from(state.terminals);
    updated[id] = terminal.copyWith(status: status, exitCode: exitCode);
    state = state.copyWith(terminals: updated);
  }

  void renameTerminal(String id, String label) {
    final terminal = state.terminals[id];
    if (terminal == null) return;
    final updated = Map<String, TerminalEntry>.from(state.terminals);
    updated[id] = terminal.copyWith(label: label);
    state = state.copyWith(terminals: updated);
  }

  void toggleZenMode() {
    state = state.copyWith(zenMode: !state.zenMode);
  }
}

final terminalsProvider =
    NotifierProvider<TerminalsNotifier, TerminalsState>(TerminalsNotifier.new);
