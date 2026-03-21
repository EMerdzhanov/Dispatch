import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/project_group.dart';
import '../../core/theme/app_theme.dart';
import '../browser/browser_panel.dart';
import '../browser/browser_provider.dart';
import '../projects/projects_provider.dart';
import '../terminal/split_container.dart';
import '../terminal/terminal_pane.dart';
import '../terminal/terminal_provider.dart';

/// The main content area that shows either terminals or browser panel.
class TerminalArea extends ConsumerWidget {
  const TerminalArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminalsState = ref.watch(terminalsProvider);
    final projectsState = ref.watch(projectsProvider);
    final browserState = ref.watch(browserProvider);

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

    final activeId = terminalsState.activeTerminalId;
    final terminalId =
        (activeId != null && activeGroup.terminalIds.contains(activeId))
            ? activeId
            : activeGroup.terminalIds.first;

    final browserTabs = browserState.groupTabs[activeGroup.id] ?? [];
    final activeBrowserTabId = browserState.activeTabId;
    final showBrowser = activeBrowserTabId != null &&
        browserTabs.any((t) => t.id == activeBrowserTabId);

    return Column(
      children: [
        // Sub tab bar with browser tabs
        _SubTabBar(
          group: activeGroup,
          activeTerminalId: terminalId,
          browserTabs: browserTabs,
          activeBrowserTabId: activeBrowserTabId,
          showBrowser: showBrowser,
        ),
        // Content: browser or terminal
        Expanded(
          child: showBrowser
              ? BrowserPanel(
                  key: ValueKey(activeBrowserTabId),
                  url: browserTabs.firstWhere((t) => t.id == activeBrowserTabId).url,
                )
              : activeGroup.splitLayout != null
                  ? SplitContainer(node: activeGroup.splitLayout!)
                  : TerminalPane(
                      key: ValueKey(terminalId),
                      terminalId: terminalId,
                    ),
        ),
      ],
    );
  }
}

/// Sub tab bar showing terminal tabs and browser tabs.
class _SubTabBar extends ConsumerWidget {
  final ProjectGroup group;
  final String activeTerminalId;
  final List<BrowserTab> browserTabs;
  final String? activeBrowserTabId;
  final bool showBrowser;

  const _SubTabBar({
    required this.group,
    required this.activeTerminalId,
    required this.browserTabs,
    required this.activeBrowserTabId,
    required this.showBrowser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminalsState = ref.watch(terminalsProvider);
    final hasBrowserTabs = browserTabs.isNotEmpty;

    // Hide if only 1 terminal and no browser tabs
    if (group.terminalIds.length <= 1 && !hasBrowserTabs) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // "Terminals" tab (when browser tabs exist)
          if (hasBrowserTabs)
            _SubTab(
              label: 'Terminals',
              isActive: !showBrowser,
              onTap: () => ref.read(browserProvider.notifier).setActiveTab(null),
            ),
          // Individual terminal tabs (when no browser tabs, show terminal names)
          if (!hasBrowserTabs)
            ...group.terminalIds.map((id) {
              final isActive = id == activeTerminalId;
              final entry = terminalsState.terminals[id];
              final label = entry?.label ??
                  entry?.command.split(' ').first.split('/').last ??
                  'Terminal';
              return _SubTab(
                label: label,
                isActive: isActive,
                onTap: () {
                  ref.read(browserProvider.notifier).setActiveTab(null);
                  ref.read(terminalsProvider.notifier).setActiveTerminal(id);
                },
              );
            }),
          // Browser tabs
          ...browserTabs.map((tab) {
            final isActive = tab.id == activeBrowserTabId;
            return _SubTab(
              label: '\u{1F310} ${tab.title}',
              isActive: isActive,
              onTap: () => ref.read(browserProvider.notifier).setActiveTab(tab.id),
              onClose: () => ref.read(browserProvider.notifier).removeTab(
                    group.id, tab.id),
            );
          }),
        ],
      ),
    );
  }
}

class _SubTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _SubTab({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.animFastDuration,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClose,
                child: const Text('\u2715',
                    style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
