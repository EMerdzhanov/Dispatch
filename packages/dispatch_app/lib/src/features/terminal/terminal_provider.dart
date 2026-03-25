import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/terminal_entry.dart';
import '../projects/projects_provider.dart';

class TerminalsState {
  final Map<String, TerminalEntry> terminals;
  final String? activeTerminalId;
  final bool zenMode;
  /// Terminal IDs currently waiting for user approval (e.g. Claude Code y/n prompt).
  final Set<String> waitingApproval;

  const TerminalsState({
    this.terminals = const {},
    this.activeTerminalId,
    this.zenMode = false,
    this.waitingApproval = const {},
  });

  TerminalsState copyWith({
    Map<String, TerminalEntry>? terminals,
    String? Function()? activeTerminalId,
    bool? zenMode,
    Set<String>? waitingApproval,
  }) {
    return TerminalsState(
      terminals: terminals ?? this.terminals,
      activeTerminalId:
          activeTerminalId != null ? activeTerminalId() : this.activeTerminalId,
      zenMode: zenMode ?? this.zenMode,
      waitingApproval: waitingApproval ?? this.waitingApproval,
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
    // Clear approval state if terminal is removed
    final updatedApproval = Set<String>.from(state.waitingApproval)..remove(id);
    state = state.copyWith(
      terminals: updated,
      activeTerminalId: state.activeTerminalId == id ? () => null : null,
      waitingApproval: updatedApproval,
    );
  }

  void setActiveTerminal(String id) {
    // Clicking a terminal clears its approval badge
    final updatedApproval = Set<String>.from(state.waitingApproval)..remove(id);
    state = state.copyWith(
      activeTerminalId: () => id,
      waitingApproval: updatedApproval,
    );
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

  /// Mark a terminal as waiting for approval — shows badge on the tab.
  void setWaitingApproval(String id, {required bool waiting}) {
    final updated = Set<String>.from(state.waitingApproval);
    if (waiting) {
      updated.add(id);
    } else {
      updated.remove(id);
    }
    state = state.copyWith(waitingApproval: updated);
  }

  /// Set an auto-detected label only if the terminal has no user-set label.
  void setAutoLabel(String id, String label) {
    final terminal = state.terminals[id];
    if (terminal == null || terminal.label != null) return;
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
