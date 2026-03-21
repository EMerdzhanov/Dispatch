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
    return Container(
      height: AppTheme.tabBarHeight,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: AppTheme.borderWidth)),
      ),
      child: Row(
        children: _ProjectTab.values.map((tab) {
          final isActive = tab == activeTab;
          final label = tab.name[0].toUpperCase() + tab.name.substring(1);
          return _TabButton(
            label: label,
            isActive: isActive,
            onTap: () => onTabSelected(tab),
          );
        }).toList(),
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppTheme.hoverDuration,
          curve: AppTheme.animCurve,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: _hovered && !widget.isActive
                ? AppTheme.surfaceLight.withValues(alpha: 0.5)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: widget.isActive
                    ? AppTheme.accentBlue
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: widget.isActive
                  ? AppTheme.labelStyle.copyWith(color: AppTheme.accentBlue)
                  : _hovered
                      ? AppTheme.labelStyle.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.normal)
                      : AppTheme.labelStyle.copyWith(fontWeight: FontWeight.normal),
            ),
          ),
        ),
      ),
    );
  }
}
