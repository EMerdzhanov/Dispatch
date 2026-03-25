import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
import '../notes/notes_panel.dart';
import '../tasks/tasks_panel.dart';
import '../vault/vault_panel.dart';
import '../sidebar/memory_panel.dart';

enum _ProjectTab { tasks, notes, vault, memory }

class ProjectPanel extends ConsumerStatefulWidget {
  const ProjectPanel({super.key});

  @override
  ConsumerState<ProjectPanel> createState() => _ProjectPanelState();
}

class _ProjectPanelState extends ConsumerState<ProjectPanel> {
  _ProjectTab _activeTab = _ProjectTab.tasks;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);

    return Container(
      color: theme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TabBar(
            activeTab: _activeTab,
            onTabSelected: (tab) => setState(() => _activeTab = tab),
            theme: theme,
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_activeTab) {
      case _ProjectTab.tasks:
        return const TasksPanel();
      case _ProjectTab.notes:
        return const NotesPanel();
      case _ProjectTab.vault:
        return const VaultPanel();
      case _ProjectTab.memory:
        return const MemoryPanel();
    }
  }
}

class _TabBar extends StatelessWidget {
  final _ProjectTab activeTab;
  final void Function(_ProjectTab) onTabSelected;
  final AppTheme theme;

  const _TabBar({required this.activeTab, required this.onTabSelected, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: theme.tabTrack,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: theme.tabTrackBorder, width: 1),
        ),
        child: Row(
          children: _ProjectTab.values.map((tab) {
            final isActive = tab == activeTab;
            final icon = switch (tab) {
              _ProjectTab.tasks => '\u2611',  // ☑
              _ProjectTab.notes => '\u{1F4DD}', // 📝
              _ProjectTab.vault => '\u{1F511}', // 🔑
              _ProjectTab.memory => '\u{1F9E0}', // 🧠
            };
            final label = tab.name[0].toUpperCase() + tab.name.substring(1);
            return _TabButton(
              label: '$icon $label',
              isActive: isActive,
              onTap: () => onTabSelected(tab),
              theme: theme,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TabButton extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final AppTheme theme;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppTheme.hoverDuration,
            curve: AppTheme.animCurve,
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: widget.isActive ? theme.surfaceLight : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              boxShadow: widget.isActive
                  ? [const BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))]
                  : null,
            ),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: widget.isActive
                      ? theme.textPrimary
                      : _hovered
                          ? theme.textPrimary
                          : const Color(0xFF666666),
                  fontSize: 10,
                  fontWeight: widget.isActive ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
