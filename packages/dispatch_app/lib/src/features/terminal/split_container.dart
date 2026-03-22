import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dispatch_app/src/core/models/split_node.dart';
import 'package:dispatch_app/src/features/terminal/terminal_pane.dart';
import 'package:dispatch_app/src/features/projects/projects_provider.dart';
import 'package:dispatch_app/src/core/theme/app_theme.dart';
import 'package:dispatch_app/src/features/settings/settings_provider.dart';

// ---------------------------------------------------------------------------
// SplitContainer
// ---------------------------------------------------------------------------

/// Recursively renders a [SplitNode] tree.
///
/// Leaf nodes render [TerminalPane]. Branch nodes render two children
/// separated by a draggable [_DragDivider].
class SplitContainer extends ConsumerWidget {
  final SplitNode node;
  final List<int> path;

  const SplitContainer({
    super.key,
    required this.node,
    this.path = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme(ref.watch(activeThemeProvider));

    if (node is SplitLeaf) {
      final leaf = node as SplitLeaf;
      return TerminalPane(
        key: ValueKey(leaf.terminalId),
        terminalId: leaf.terminalId,
      );
    }

    final branch = node as SplitBranch;
    final isHorizontal = branch.direction == SplitDirection.horizontal;

    return Flex(
      direction: isHorizontal ? Axis.horizontal : Axis.vertical,
      children: [
        Flexible(
          flex: (branch.ratio * 1000).round(),
          child: SplitContainer(node: branch.children.$1, path: [...path, 0]),
        ),
        _DragDivider(
          direction: branch.direction,
          theme: theme,
          onDrag: (delta) {
            final newRatio = (branch.ratio + delta).clamp(0.15, 0.85);
            final projectsState = ref.read(projectsProvider);
            final groupId = projectsState.activeGroupId;
            if (groupId == null) return;
            final group = projectsState.groups
                .where((g) => g.id == groupId)
                .firstOrNull;
            if (group == null || group.splitLayout == null) return;
            final updatedLayout = _updateRatioAtPath(
              group.splitLayout!,
              path,
              newRatio,
            );
            ref
                .read(projectsProvider.notifier)
                .setGroupSplitLayout(groupId, updatedLayout);
          },
        ),
        Flexible(
          flex: ((1 - branch.ratio) * 1000).round(),
          child: SplitContainer(node: branch.children.$2, path: [...path, 1]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _DragDivider
// ---------------------------------------------------------------------------

/// A thin draggable divider between split panes.
///
/// Width (horizontal split) or height (vertical split) is 4 px.
/// Uses a resize cursor and highlights in [AppTheme.accentBlue] while active.
class _DragDivider extends StatefulWidget {
  final SplitDirection direction;
  final AppTheme theme;

  /// Called with the drag delta expressed as a fraction of the parent size.
  final void Function(double delta) onDrag;

  const _DragDivider({
    required this.direction,
    required this.theme,
    required this.onDrag,
  });

  @override
  State<_DragDivider> createState() => _DragDividerState();
}

class _DragDividerState extends State<_DragDivider> {
  bool _dragging = false;

  bool get _isHorizontal => widget.direction == SplitDirection.horizontal;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final thickness = 4.0;

    final divider = MouseRegion(
      cursor: _isHorizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onHorizontalDragStart:
            _isHorizontal ? (_) => setState(() => _dragging = true) : null,
        onHorizontalDragEnd:
            _isHorizontal ? (_) => setState(() => _dragging = false) : null,
        onHorizontalDragUpdate: _isHorizontal
            ? (details) {
                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox == null) return;
                // Find the parent's total width to compute a fractional delta.
                final parentBox =
                    renderBox.parent as RenderBox?;
                final parentWidth =
                    parentBox?.size.width ?? renderBox.size.width;
                if (parentWidth == 0) return;
                widget.onDrag(details.delta.dx / parentWidth);
              }
            : null,
        onVerticalDragStart:
            !_isHorizontal ? (_) => setState(() => _dragging = true) : null,
        onVerticalDragEnd:
            !_isHorizontal ? (_) => setState(() => _dragging = false) : null,
        onVerticalDragUpdate: !_isHorizontal
            ? (details) {
                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox == null) return;
                final parentBox =
                    renderBox.parent as RenderBox?;
                final parentHeight =
                    parentBox?.size.height ?? renderBox.size.height;
                if (parentHeight == 0) return;
                widget.onDrag(details.delta.dy / parentHeight);
              }
            : null,
        child: AnimatedContainer(
          duration: AppTheme.hoverDuration,
          width: _isHorizontal ? thickness : double.infinity,
          height: _isHorizontal ? double.infinity : thickness,
          color: _dragging ? theme.accentBlue : theme.border,
        ),
      ),
    );

    return divider;
  }
}

// ---------------------------------------------------------------------------
// Helper: _updateRatioAtPath
// ---------------------------------------------------------------------------

/// Pure function that traverses the [SplitNode] tree and updates the [ratio]
/// of the [SplitBranch] found at [path].
SplitNode _updateRatioAtPath(
  SplitNode node,
  List<int> path,
  double newRatio,
) {
  if (path.isEmpty && node is SplitBranch) {
    return node.copyWith(ratio: newRatio);
  }
  if (node is SplitBranch && path.isNotEmpty) {
    final idx = path.first;
    final rest = path.sublist(1);
    final children = idx == 0
        ? (
            _updateRatioAtPath(node.children.$1, rest, newRatio),
            node.children.$2,
          )
        : (
            node.children.$1,
            _updateRatioAtPath(node.children.$2, rest, newRatio),
          );
    return node.copyWith(children: children);
  }
  return node;
}
