import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/project_group.dart';
import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
import '../browser/browser_panel.dart';
import '../browser/browser_provider.dart';
import '../projects/projects_provider.dart';
import '../../core/models/split_node.dart';
import '../terminal/terminal_pane.dart';
import '../terminal/terminal_provider.dart';

final _terminalPaneKeys = <String, GlobalKey>{};

GlobalKey _getTerminalKey(String id) {
  return _terminalPaneKeys.putIfAbsent(id, () => GlobalKey());
}

class TerminalArea extends ConsumerWidget {
  const TerminalArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    final terminalsState = ref.watch(terminalsProvider);
    final projectsState = ref.watch(projectsProvider);
    final browserState = ref.watch(browserProvider);

    final activeGroup = projectsState.groups
        .where((g) => g.id == projectsState.activeGroupId)
        .firstOrNull;

    if (activeGroup == null || activeGroup.terminalIds.isEmpty) {
      return Center(
        child: Text(
          'No terminals. Use presets or Cmd+N to create one.',
          style: TextStyle(color: theme.textSecondary),
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
        _SubTabBar(
          group: activeGroup,
          activeTerminalId: terminalId,
          browserTabs: browserTabs,
          activeBrowserTabId: activeBrowserTabId,
          showBrowser: showBrowser,
          waitingApproval: terminalsState.waitingApproval,
        ),
        Expanded(
          child: showBrowser
              ? BrowserPanel(
                  key: ValueKey(activeBrowserTabId),
                  url: browserTabs
                      .firstWhere((t) => t.id == activeBrowserTabId)
                      .url,
                )
              : activeGroup.splitLayout != null
                  ? _buildSplitView(theme, activeGroup)
                  : IndexedStack(
                      index: activeGroup.terminalIds
                          .indexOf(terminalId)
                          .clamp(0, activeGroup.terminalIds.length - 1),
                      children: activeGroup.terminalIds.map((id) {
                        return TerminalPane(
                          key: _getTerminalKey(id),
                          terminalId: id,
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildSplitView(AppTheme theme, ProjectGroup group) {
    final layout = group.splitLayout!;
    final direction = layout is SplitBranch
        ? layout.direction
        : SplitDirection.horizontal;
    final isHorizontal = direction == SplitDirection.horizontal;

    final children = <Widget>[];
    for (int i = 0; i < group.terminalIds.length; i++) {
      if (i > 0) {
        children.add(Container(
          width: isHorizontal ? 1 : null,
          height: isHorizontal ? null : 1,
          color: theme.border,
        ));
      }
      children.add(Expanded(
        child: TerminalPane(
          key: _getTerminalKey(group.terminalIds[i]),
          terminalId: group.terminalIds[i],
        ),
      ));
    }

    return Flex(
      direction: isHorizontal ? Axis.horizontal : Axis.vertical,
      children: children,
    );
  }
}

class _SubTabBar extends ConsumerWidget {
  final ProjectGroup group;
  final String activeTerminalId;
  final List<BrowserTab> browserTabs;
  final String? activeBrowserTabId;
  final bool showBrowser;
  final Set<String> waitingApproval;

  const _SubTabBar({
    required this.group,
    required this.activeTerminalId,
    required this.browserTabs,
    required this.activeBrowserTabId,
    required this.showBrowser,
    required this.waitingApproval,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    final terminalsState = ref.watch(terminalsProvider);
    final hasBrowserTabs = browserTabs.isNotEmpty;
    final hasMultipleTerminals = group.terminalIds.length > 1;
    final hasAnyWaiting = group.terminalIds
        .any((id) => waitingApproval.contains(id));

    // Show tab bar if: multiple terminals, browser tabs exist, or any terminal
    // is waiting for approval (so the badge is always visible)
    if (!hasMultipleTerminals && !hasBrowserTabs && !hasAnyWaiting) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.tabTrack,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.tabTrackBorder, width: 1),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Always show individual terminal tabs so badges are visible
              ...group.terminalIds.map((id) {
                final isActive = id == activeTerminalId && !showBrowser;
                final entry = terminalsState.terminals[id];
                final label = entry?.label ??
                    entry?.command.split(' ').first.split('/').last ??
                    'Terminal';
                final needsApproval = waitingApproval.contains(id);
                return _SubTab(
                  label: label,
                  isActive: isActive,
                  needsApproval: needsApproval,
                  onTap: () {
                    ref.read(browserProvider.notifier).setActiveTab(null);
                    ref
                        .read(terminalsProvider.notifier)
                        .setActiveTerminal(id);
                  },
                  theme: theme,
                );
              }),
              // Browser tabs
              ...browserTabs.map((tab) {
                final isActive = tab.id == activeBrowserTabId;
                return _SubTab(
                  label: '\u{1F310} ${tab.title}',
                  isActive: isActive,
                  needsApproval: false,
                  onTap: () =>
                      ref.read(browserProvider.notifier).setActiveTab(tab.id),
                  onClose: () => ref
                      .read(browserProvider.notifier)
                      .removeTab(group.id, tab.id),
                  theme: theme,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubTab extends StatefulWidget {
  final String label;
  final bool isActive;
  final bool needsApproval;
  final VoidCallback onTap;
  final VoidCallback? onClose;
  final AppTheme theme;

  const _SubTab({
    required this.label,
    required this.isActive,
    required this.needsApproval,
    required this.onTap,
    this.onClose,
    required this.theme,
  });

  @override
  State<_SubTab> createState() => _SubTabState();
}

class _SubTabState extends State<_SubTab> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppTheme.animFastDuration,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: widget.needsApproval
              ? const Color(0xFF2A1F00)
              : widget.isActive
                  ? widget.theme.surfaceLight
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: widget.needsApproval
              ? Border.all(color: const Color(0xFFFFB300), width: 1)
              : null,
          boxShadow: widget.isActive && !widget.needsApproval
              ? [
                  const BoxShadow(
                      color: Color(0x4D000000),
                      blurRadius: 3,
                      offset: Offset(0, 1))
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.needsApproval) ...[
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, _) => Opacity(
                  opacity: _pulseAnim.value,
                  child: const Text('⏸', style: TextStyle(fontSize: 10)),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 11,
                color: widget.needsApproval
                    ? const Color(0xFFFFB300)
                    : widget.isActive
                        ? widget.theme.textPrimary
                        : const Color(0xFF666666),
                fontWeight: widget.isActive || widget.needsApproval
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
            ),
            if (widget.onClose != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: widget.onClose,
                child: Text('\u2715',
                    style: TextStyle(
                        fontSize: 9, color: widget.theme.textSecondary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
