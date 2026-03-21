import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/terminal_entry.dart';
import '../../core/theme/app_theme.dart';
import '../projects/projects_provider.dart';
import '../terminal/terminal_provider.dart';

class TerminalList extends ConsumerWidget {
  const TerminalList({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final terminalsState = ref.watch(terminalsProvider);
    final projectsState = ref.watch(projectsProvider);

    final activeGroup = projectsState.groups
        .where((g) => g.id == projectsState.activeGroupId)
        .firstOrNull;

    final terminalIds = activeGroup?.terminalIds ?? [];
    final terminals = terminalIds
        .map((id) => terminalsState.terminals[id])
        .whereType<TerminalEntry>()
        .toList();

    if (terminals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          'No terminals',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      itemCount: terminals.length,
      itemBuilder: (context, index) {
        final terminal = terminals[index];
        final isActive = terminal.id == terminalsState.activeTerminalId;
        final statusColor = _statusColor(terminal.status, isActive);
        final label = terminal.label ??
            terminal.presetName ??
            terminal.command.split(' ').first;

        return _TerminalListItem(
          terminal: terminal,
          isActive: isActive,
          statusColor: statusColor,
          label: label,
          cwdDisplay: _truncateCwd(terminal.cwd),
          onTap: () {
            ref.read(terminalsProvider.notifier).setActiveTerminal(terminal.id);
          },
          onRename: (newLabel) {
            ref.read(terminalsProvider.notifier).renameTerminal(terminal.id, newLabel);
          },
          onKill: () {
            ref.read(terminalsProvider.notifier).removeTerminal(terminal.id);
          },
        );
      },
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
        const PopupMenuItem(
          value: 'rename',
          child: Text(
            'Rename',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          ),
        ),
        const PopupMenuItem(
          value: 'kill',
          child: Text(
            'Kill',
            style: TextStyle(color: AppTheme.accentRed, fontSize: 13),
          ),
        ),
      ],
    );

    if (result == 'rename') {
      _showRenameDialog(context);
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
        title: const Text(
          'Rename Terminal',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        ),
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
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) widget.onRename(value);
              Navigator.of(ctx).pop();
            },
            child: const Text('Rename', style: TextStyle(color: AppTheme.accentBlue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (details) => _showContextMenu(context, details.localPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppTheme.surfaceLight
                : _hovered
                    ? AppTheme.surfaceLight.withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: widget.statusColor,
                  shape: BoxShape.circle,
                ),
              ),
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
                            ? FontWeight.w600
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
