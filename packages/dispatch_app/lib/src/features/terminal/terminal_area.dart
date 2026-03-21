import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/project_group.dart';
import '../../core/theme/app_theme.dart';
import '../projects/projects_provider.dart';
import '../terminal/split_container.dart';
import '../terminal/terminal_pane.dart';
import '../terminal/terminal_provider.dart';

/// The main content area that shows either a single terminal or split panes.
class TerminalArea extends ConsumerWidget {
  const TerminalArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminalsState = ref.watch(terminalsProvider);
    final projectsState = ref.watch(projectsProvider);

    final activeGroup = projectsState.groups
        .where((g) => g.id == projectsState.activeGroupId)
        .firstOrNull;

    if (activeGroup == null || activeGroup.terminalIds.isEmpty) {
      return const Center(
        child: Text(
          'No terminals. Use presets or Cmd+N to create one.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    // Single terminal view — show active terminal or first in group.
    final activeId = terminalsState.activeTerminalId;
    final terminalId =
        (activeId != null && activeGroup.terminalIds.contains(activeId))
            ? activeId
            : activeGroup.terminalIds.first;

    // If a split layout exists, render SplitContainer.
    if (activeGroup.splitLayout != null) {
      return Column(
        children: [
          _SubTabBar(group: activeGroup, activeTerminalId: terminalId),
          Expanded(child: SplitContainer(node: activeGroup.splitLayout!)),
        ],
      );
    }

    return Column(
      children: [
        _SubTabBar(group: activeGroup, activeTerminalId: terminalId),
        Expanded(
          child: TerminalPane(
            key: ValueKey(terminalId),
            terminalId: terminalId,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _SubTabBar
// ---------------------------------------------------------------------------

/// A small row of tabs, one per terminal in [group].
///
/// The active terminal is highlighted. Clicking a tab switches the active
/// terminal via [terminalsProvider].
class _SubTabBar extends ConsumerWidget {
  final ProjectGroup group;
  final String activeTerminalId;

  const _SubTabBar({
    required this.group,
    required this.activeTerminalId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminalsState = ref.watch(terminalsProvider);

    // Only show the sub-tab bar when there is more than one terminal.
    if (group.terminalIds.length <= 1) return const SizedBox.shrink();

    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: group.terminalIds.length,
        itemBuilder: (context, index) {
          final id = group.terminalIds[index];
          final isActive = id == activeTerminalId;
          final entry = terminalsState.terminals[id];
          final label = entry?.label ??
              entry?.command.split(' ').first.split('/').last ??
              'Terminal ${index + 1}';

          return _SubTab(
            label: label,
            isActive: isActive,
            onTap: () =>
                ref.read(terminalsProvider.notifier).setActiveTerminal(id),
          );
        },
      ),
    );
  }
}

class _SubTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SubTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppTheme.surfaceLight : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppTheme.accentBlue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
