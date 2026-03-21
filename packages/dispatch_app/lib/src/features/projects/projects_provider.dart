import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/project_group.dart';
import '../../core/models/split_node.dart';

class ProjectsState {
  final List<ProjectGroup> groups;
  final String? activeGroupId;

  const ProjectsState({this.groups = const [], this.activeGroupId});

  ProjectsState copyWith({
    List<ProjectGroup>? groups,
    String? Function()? activeGroupId,
  }) {
    return ProjectsState(
      groups: groups ?? this.groups,
      activeGroupId:
          activeGroupId != null ? activeGroupId() : this.activeGroupId,
    );
  }
}

class ProjectsNotifier extends Notifier<ProjectsState> {
  static const _uuid = Uuid();

  @override
  ProjectsState build() => const ProjectsState();

  /// Returns the id of the existing group for [cwd], or creates a new one.
  String findOrCreateGroup(String cwd) {
    final existing = state.groups.where((g) => g.cwd == cwd).firstOrNull;
    if (existing != null) return existing.id;

    final label = cwd.split('/').where((s) => s.isNotEmpty).lastOrNull ?? cwd;
    final id = _uuid.v4();
    final group = ProjectGroup(id: id, label: label, cwd: cwd);

    state = state.copyWith(
      groups: [...state.groups, group],
      activeGroupId:
          state.activeGroupId == null ? () => id : null,
    );

    return id;
  }

  void addGroup(String? cwd, String label) {
    final id = _uuid.v4();
    final group = ProjectGroup(id: id, label: label, cwd: cwd);
    state = state.copyWith(
      groups: [...state.groups, group],
      activeGroupId:
          state.activeGroupId == null ? () => id : null,
    );
  }

  void removeGroup(String id) {
    final groups = state.groups.where((g) => g.id != id).toList();
    String? newActiveId = state.activeGroupId;
    if (state.activeGroupId == id) {
      newActiveId = groups.isNotEmpty ? groups.last.id : null;
    }
    state = state.copyWith(
      groups: groups,
      activeGroupId: () => newActiveId,
    );
  }

  void setActiveGroup(String id) {
    state = state.copyWith(activeGroupId: () => id);
  }

  void reorderGroups(int fromIndex, int toIndex) {
    final groups = [...state.groups];
    final item = groups.removeAt(fromIndex);
    // After removal the list is one shorter; insert at toIndex clamped to bounds.
    final insertIndex = toIndex.clamp(0, groups.length);
    groups.insert(insertIndex, item);
    state = state.copyWith(groups: groups);
  }

  void addTerminalToGroup(String groupId, String terminalId) {
    final groups = state.groups.map((g) {
      if (g.id != groupId) return g;
      if (g.terminalIds.contains(terminalId)) return g;
      return g.copyWith(terminalIds: [...g.terminalIds, terminalId]);
    }).toList();
    state = state.copyWith(groups: groups);
  }

  void removeTerminalFromGroup(String terminalId) {
    final groups = state.groups.map((g) {
      if (!g.terminalIds.contains(terminalId)) return g;
      return g.copyWith(
        terminalIds: g.terminalIds.where((id) => id != terminalId).toList(),
      );
    }).toList();
    state = state.copyWith(groups: groups);
  }

  void setGroupSplitLayout(String groupId, SplitNode? layout) {
    final groups = state.groups.map((g) {
      if (g.id != groupId) return g;
      return g.copyWith(splitLayout: () => layout);
    }).toList();
    state = state.copyWith(groups: groups);
  }
}

final projectsProvider =
    NotifierProvider<ProjectsNotifier, ProjectsState>(ProjectsNotifier.new);
