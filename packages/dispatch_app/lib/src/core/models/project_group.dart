import 'split_node.dart';

class ProjectGroup {
  final String id;
  final String label;
  final String? cwd;
  final List<String> terminalIds;
  final SplitNode? splitLayout;

  const ProjectGroup({
    required this.id, required this.label, this.cwd,
    this.terminalIds = const [], this.splitLayout,
  });

  ProjectGroup copyWith({
    String? label, List<String>? terminalIds,
    SplitNode? Function()? splitLayout,
  }) {
    return ProjectGroup(
      id: id, label: label ?? this.label, cwd: cwd,
      terminalIds: terminalIds ?? this.terminalIds,
      splitLayout: splitLayout != null ? splitLayout() : this.splitLayout,
    );
  }
}
