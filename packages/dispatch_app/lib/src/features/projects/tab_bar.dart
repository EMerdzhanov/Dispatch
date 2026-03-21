import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../projects/projects_provider.dart';
import '../terminal/terminal_provider.dart';

class ProjectTabBar extends ConsumerWidget {
  final VoidCallback onOpenFolder;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenShortcuts;

  const ProjectTabBar({
    super.key,
    required this.onOpenFolder,
    required this.onOpenSettings,
    required this.onOpenShortcuts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsState = ref.watch(projectsProvider);
    final terminalsState = ref.watch(terminalsProvider);
    final groups = projectsState.groups;
    final activeGroupId = projectsState.activeGroupId;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: 4),
      color: AppTheme.surface,
      child: Row(
        children: [
          // Scrollable, drag-to-reorder tab list
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.tabTrack,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppTheme.tabTrackBorder, width: 1),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(groups.length, (index) {
                  final group = groups[index];
                  final isActive = group.id == activeGroupId;
                  final terminalCount = group.terminalIds.length;

                  return DragTarget<int>(
                    onWillAcceptWithDetails: (details) => details.data != index,
                    onAcceptWithDetails: (details) {
                      ref
                          .read(projectsProvider.notifier)
                          .reorderGroups(details.data, index);
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isDropTarget = candidateData.isNotEmpty;
                      return Draggable<int>(
                        data: index,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Opacity(
                            opacity: 0.8,
                            child: _ProjectTab(
                              label: group.label,
                              terminalCount: terminalCount,
                              isActive: true,
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _ProjectTab(
                            label: group.label,
                            terminalCount: terminalCount,
                            isActive: isActive,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            ref
                                .read(projectsProvider.notifier)
                                .setActiveGroup(group.id);
                            if (group.terminalIds.isNotEmpty) {
                              final firstId = group.terminalIds.first;
                              if (terminalsState.terminals
                                  .containsKey(firstId)) {
                                ref
                                    .read(terminalsProvider.notifier)
                                    .setActiveTerminal(firstId);
                              }
                            }
                          },
                          onSecondaryTapDown: (details) {
                            _showContextMenu(
                                context, ref, group.id, details.globalPosition);
                          },
                          child: Container(
                            decoration: isDropTarget
                                ? const BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                          color: AppTheme.accentBlue, width: 2),
                                    ),
                                  )
                                : null,
                            child: _ProjectTab(
                              label: group.label,
                              terminalCount: terminalCount,
                              isActive: isActive,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
            ),
          ),

          // "+" button to open folder
          _IconButton(
            key: const Key('open_folder_button'),
            icon: Icons.add,
            tooltip: 'Open Folder',
            onTap: onOpenFolder,
          ),

          const SizedBox(width: AppTheme.spacingXs),

          // Settings gear icon
          _IconButton(
            key: const Key('open_settings_button'),
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: onOpenSettings,
          ),

          // Shortcuts "?" icon
          _IconButton(
            key: const Key('open_shortcuts_button'),
            icon: Icons.help_outline,
            tooltip: 'Keyboard Shortcuts',
            onTap: onOpenShortcuts,
          ),

          const SizedBox(width: AppTheme.spacingXs),
        ],
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    Offset position,
  ) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: AppTheme.surfaceLight,
      items: [
        PopupMenuItem<String>(
          value: 'close',
          child: Text(
            'Close Tab',
            style: AppTheme.bodyStyle,
          ),
        ),
      ],
    );

    if (result == 'close') {
      final state = ref.read(projectsProvider);
      final group = state.groups.where((g) => g.id == groupId).firstOrNull;
      if (group != null) {
        // Kill all terminals in group
        for (final terminalId in [...group.terminalIds]) {
          ref.read(terminalsProvider.notifier).removeTerminal(terminalId);
        }
        // Remove the group itself
        ref.read(projectsProvider.notifier).removeGroup(groupId);
      }
    }
  }
}

class _ProjectTab extends StatefulWidget {
  final String label;
  final int terminalCount;
  final bool isActive;

  const _ProjectTab({
    required this.label,
    required this.terminalCount,
    required this.isActive,
  });

  @override
  State<_ProjectTab> createState() => _ProjectTabState();
}

class _ProjectTabState extends State<_ProjectTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppTheme.hoverDuration,
        curve: AppTheme.animCurve,
        constraints: const BoxConstraints(minWidth: 60, maxWidth: 180),
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: widget.isActive
              ? AppTheme.surfaceLight
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: widget.isActive
              ? [const BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 14,
              color: widget.isActive
                  ? AppTheme.textPrimary
                  : _hovered
                      ? AppTheme.textPrimary
                      : const Color(0xFF666666),
            ),
            const SizedBox(width: AppTheme.spacingXs + 2),
            Flexible(
              child: Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.isActive
                      ? AppTheme.textPrimary
                      : _hovered
                          ? AppTheme.textPrimary
                          : const Color(0xFF666666),
                  fontSize: 12,
                  fontWeight: widget.isActive ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            if (widget.terminalCount > 0) ...[
              const SizedBox(width: AppTheme.spacingXs + 2),
              _TerminalCountBadge(count: widget.terminalCount),
            ],
          ],
        ),
      ),
    );
  }
}

class _TerminalCountBadge extends StatelessWidget {
  final int count;

  const _TerminalCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.border,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Icon(icon, size: 16, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
