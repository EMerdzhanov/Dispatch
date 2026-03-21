import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../notes/notes_panel.dart';
import '../tasks/tasks_panel.dart';
import '../vault/vault_panel.dart';

enum _ProjectTab { tasks, notes, vault }

class ProjectPanel extends StatefulWidget {
  const ProjectPanel({super.key});

  @override
  State<ProjectPanel> createState() => _ProjectPanelState();
}

class _ProjectPanelState extends State<ProjectPanel> {
  _ProjectTab _activeTab = _ProjectTab.tasks;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TabBar(
            activeTab: _activeTab,
            onTabSelected: (tab) => setState(() => _activeTab = tab),
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
    }
  }
}

class _TabBar extends StatelessWidget {
  final _ProjectTab activeTab;
  final void Function(_ProjectTab) onTabSelected;

  const _TabBar({required this.activeTab, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXs),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.tabTrack,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.tabTrackBorder, width: 1),
        ),
        child: Row(
          children: _ProjectTab.values.map((tab) {
            final isActive = tab == activeTab;
            final icon = switch (tab) {
              _ProjectTab.tasks => '\u2611',  // ☑
              _ProjectTab.notes => '\u{1F4DD}', // 📝
              _ProjectTab.vault => '\u{1F511}', // 🔑
            };
            final label = tab.name[0].toUpperCase() + tab.name.substring(1);
            return _TabButton(
              label: '$icon $label',
              isActive: isActive,
              onTap: () => onTabSelected(tab),
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

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppTheme.hoverDuration,
            curve: AppTheme.animCurve,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: widget.isActive ? AppTheme.surfaceLight : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              boxShadow: widget.isActive
                  ? [const BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))]
                  : null,
            ),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: widget.isActive
                      ? AppTheme.textPrimary
                      : _hovered
                          ? AppTheme.textPrimary
                          : const Color(0xFF666666),
                  fontSize: 11,
                  fontWeight: widget.isActive ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
