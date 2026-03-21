import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/terminal_entry.dart';
import '../../core/theme/app_theme.dart';
import '../projects/projects_provider.dart';
import '../terminal/terminal_provider.dart';
import 'file_tree.dart';

class TerminalList extends ConsumerStatefulWidget {
  const TerminalList({super.key});

  @override
  ConsumerState<TerminalList> createState() => _TerminalListState();
}

class _TerminalListState extends ConsumerState<TerminalList> {
  String _tab = 'terminals'; // 'terminals' | 'files'
  String _filter = '';

  Color _statusColor(TerminalStatus status, bool isActive) {
    if (isActive) return AppTheme.accentBlue;
    switch (status) {
      case TerminalStatus.active:
        return AppTheme.accentBlue;
      case TerminalStatus.running:
        return AppTheme.accentGreen;
      case TerminalStatus.exited:
        return AppTheme.accentRed;
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
    final terminalsState = ref.watch(terminalsProvider);
    final projectsState = ref.watch(projectsProvider);

    final activeGroup = projectsState.groups
        .where((g) => g.id == projectsState.activeGroupId)
        .firstOrNull;

    final terminalIds = activeGroup?.terminalIds ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TERMINALS / FILES tab header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppTheme.tabTrack,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppTheme.tabTrackBorder, width: 1),
            ),
            child: Row(
              children: [
                _TabButton(
                  label: 'TERMINALS (${terminalIds.length})',
                  active: _tab == 'terminals',
                  onTap: () => setState(() => _tab = 'terminals'),
                ),
                _TabButton(
                  label: 'FILES',
                  active: _tab == 'files',
                  onTap: () => setState(() => _tab = 'files'),
                ),
              ],
            ),
          ),
        ),
        // Filter input (terminals tab only)
        if (_tab == 'terminals')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
            child: Row(
              children: [
                const Text('\u25CF ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 8)),
                Expanded(
                  child: SizedBox(
                    height: 22,
                    child: TextField(
                      style: AppTheme.bodyStyle,
                      decoration: InputDecoration(
                        hintText: 'Filter terminals\u2026',
                        hintStyle: AppTheme.dimStyle,
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
              ],
            ),
          ),
        const Divider(color: AppTheme.border, height: 1, thickness: AppTheme.borderWidth),
        // Content
        Expanded(
          child: _tab == 'files'
              ? const FileTree()
              : _buildTerminalList(terminalsState, terminalIds),
        ),
      ],
    );
  }

  Widget _buildTerminalList(TerminalsState terminalsState, List<String> terminalIds) {
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
        child: Text('No terminals', style: AppTheme.dimStyle),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXs + 2, vertical: AppTheme.spacingXs),
      child: Column(
        children: terminals.map((terminal) {
        final isActive = terminal.id == terminalsState.activeTerminalId;
        final statusColor = _statusColor(terminal.status, isActive);
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
        );
      }).toList(),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppTheme.hoverDuration,
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? AppTheme.surfaceLight : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            boxShadow: active
                ? [const BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppTheme.textPrimary : const Color(0xFF666666),
              fontSize: 10,
              fontWeight: active ? FontWeight.w500 : FontWeight.normal,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
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

  const _TerminalListItem({
    required this.terminal,
    required this.isActive,
    required this.statusColor,
    required this.label,
    required this.cwdDisplay,
    required this.onTap,
    required this.onRename,
    required this.onKill,
  });

  @override
  State<_TerminalListItem> createState() => _TerminalListItemState();
}

class _TerminalListItemState extends State<_TerminalListItem> {
  bool _hovered = false;

  void _showContextMenu(BuildContext context, Offset localPosition) async {
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
      color: AppTheme.surfaceLight,
      items: [
        PopupMenuItem(
          value: 'rename',
          child: Text('Rename', style: AppTheme.bodyStyle),
        ),
        PopupMenuItem(
          value: 'kill',
          child: Text(
            'Kill',
            style: AppTheme.bodyStyle.copyWith(color: AppTheme.accentRed),
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
    final controller = TextEditingController(text: widget.label);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        title: Text('Rename Terminal', style: AppTheme.titleStyle),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.accentBlue),
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
            child: Text('Cancel', style: AppTheme.dimStyle),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) widget.onRename(value);
              Navigator.of(ctx).pop();
            },
            child: Text('Rename', style: AppTheme.bodyStyle.copyWith(color: AppTheme.accentBlue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        child: AnimatedContainer(
          duration: AppTheme.hoverDuration,
          curve: AppTheme.animCurve,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs + 1),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppTheme.surfaceLight
                : _hovered
                    ? AppTheme.surfaceLight.withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border(
              left: BorderSide(
                color: widget.isActive ? AppTheme.accentBlue : Colors.transparent,
                width: 2,
              ),
            ),
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
                            ? AppTheme.textPrimary
                            : AppTheme.textPrimary.withValues(alpha: 0.85),
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
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
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
