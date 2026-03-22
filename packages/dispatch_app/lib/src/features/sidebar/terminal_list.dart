import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/terminal_entry.dart';
import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
import '../projects/projects_provider.dart';
import '../terminal/terminal_provider.dart';

class TerminalList extends ConsumerStatefulWidget {
  const TerminalList({super.key});

  @override
  ConsumerState<TerminalList> createState() => _TerminalListState();
}

class _TerminalListState extends ConsumerState<TerminalList> {
  String _filter = '';

  Color _statusColor(AppTheme theme, TerminalStatus status, bool isActive) {
    if (isActive) return theme.accentBlue;
    switch (status) {
      case TerminalStatus.active:
        return theme.accentBlue;
      case TerminalStatus.running:
        return theme.accentGreen;
      case TerminalStatus.exited:
        return theme.accentRed;
    }
  }

  String _truncateCwd(String cwd) {
    final parts = cwd.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return cwd;
    if (parts.length <= 2) return cwd;
    return '.../${parts[parts.length - 2]}/${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme(ref.watch(activeThemeProvider));
    final terminalsState = ref.watch(terminalsProvider);
    final projectsState = ref.watch(projectsProvider);

    final activeGroup = projectsState.groups
        .where((g) => g.id == projectsState.activeGroupId)
        .firstOrNull;

    final terminalIds = activeGroup?.terminalIds ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TERMINALS header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingSm),
          child: Text(
            'TERMINALS (${terminalIds.length})',
            style: theme.labelStyle,
          ),
        ),
        // Filter input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
          child: SizedBox(
            height: 22,
            child: TextField(
              style: theme.bodyStyle,
              decoration: InputDecoration(
                hintText: 'Filter terminals\u2026',
                hintStyle: theme.dimStyle,
                filled: true,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXs, vertical: AppTheme.spacingXs),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
        ),
        Divider(color: theme.border, height: 1, thickness: AppTheme.borderWidth),
        // Terminal list
        Expanded(
          child: _buildTerminalList(theme, terminalsState, terminalIds),
        ),
      ],
    );
  }

  Widget _buildTerminalList(AppTheme theme, TerminalsState terminalsState, List<String> terminalIds) {
    final filtered = _filter.isEmpty
        ? terminalIds
        : terminalIds.where((id) {
            final t = terminalsState.terminals[id];
            return t != null && t.command.toLowerCase().contains(_filter.toLowerCase());
          }).toList();

    final terminals = filtered
        .map((id) => terminalsState.terminals[id])
        .whereType<TerminalEntry>()
        .toList();

    if (terminals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
        child: Text('No terminals', style: theme.dimStyle),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
      child: Column(
        children: terminals.map((terminal) {
        final isActive = terminal.id == terminalsState.activeTerminalId;
        final statusColor = _statusColor(theme, terminal.status, isActive);
        final label = terminal.label ?? terminal.presetName ?? terminal.command.split(' ').first;

        return _TerminalListItem(
          terminal: terminal,
          isActive: isActive,
          statusColor: statusColor,
          label: label,
          cwdDisplay: _truncateCwd(terminal.cwd),
          onTap: () => ref.read(terminalsProvider.notifier).setActiveTerminal(terminal.id),
          onRename: (newLabel) => ref.read(terminalsProvider.notifier).renameTerminal(terminal.id, newLabel),
          onKill: () => ref.read(terminalsProvider.notifier).removeTerminal(terminal.id),
          theme: theme,
        );
      }).toList(),
      ),
    );
  }
}

class _TerminalListItem extends StatefulWidget {
  final TerminalEntry terminal;
  final bool isActive;
  final Color statusColor;
  final String label;
  final String cwdDisplay;
  final VoidCallback onTap;
  final void Function(String) onRename;
  final VoidCallback onKill;
  final AppTheme theme;

  const _TerminalListItem({
    required this.terminal,
    required this.isActive,
    required this.statusColor,
    required this.label,
    required this.cwdDisplay,
    required this.onTap,
    required this.onRename,
    required this.onKill,
    required this.theme,
  });

  @override
  State<_TerminalListItem> createState() => _TerminalListItemState();
}

class _TerminalListItemState extends State<_TerminalListItem> {
  bool _hovered = false;

  void _showContextMenu(BuildContext context, Offset localPosition) async {
    final theme = widget.theme;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final globalPosition = renderBox.localToGlobal(localPosition);

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      color: theme.surfaceLight,
      items: [
        PopupMenuItem(
          value: 'rename',
          child: Text('Rename', style: theme.bodyStyle),
        ),
        PopupMenuItem(
          value: 'kill',
          child: Text(
            'Kill',
            style: theme.bodyStyle.copyWith(color: theme.accentRed),
          ),
        ),
      ],
    );

    if (result == 'rename') {
      if (mounted) _showRenameDialog(context);
    } else if (result == 'kill') {
      widget.onKill();
    }
  }

  void _showRenameDialog(BuildContext context) {
    final theme = widget.theme;
    final controller = TextEditingController(text: widget.label);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceLight,
        title: Text('Rename Terminal', style: theme.titleStyle),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: theme.textPrimary),
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: theme.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: theme.accentBlue),
            ),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              widget.onRename(value.trim());
            }
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: theme.dimStyle),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) widget.onRename(value);
              Navigator.of(ctx).pop();
            },
            child: Text('Rename', style: theme.bodyStyle.copyWith(color: theme.accentBlue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final statusDot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: widget.statusColor,
        shape: BoxShape.circle,
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (details) => _showContextMenu(context, details.localPosition),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isActive
                ? const Color(0xFF16213E)
                : _hovered
                    ? const Color(0xFF112233)
                    : null,
          ),
          child: Row(
            children: [
              statusDot,
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.isActive
                            ? theme.textPrimary
                            : theme.textPrimary.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: widget.isActive
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      widget.cwdDisplay,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
