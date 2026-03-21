import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../projects/projects_provider.dart';
import '../terminal/terminal_provider.dart';

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  String _truncateCwdLeft(String cwd, {int maxLength = 28}) {
    if (cwd.length <= maxLength) return cwd;
    return '...${cwd.substring(cwd.length - maxLength + 3)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsState = ref.watch(projectsProvider);
    final terminalsState = ref.watch(terminalsProvider);

    final activeGroup = projectsState.groups
        .where((g) => g.id == projectsState.activeGroupId)
        .firstOrNull;

    final terminalCount = activeGroup?.terminalIds
            .where((id) => terminalsState.terminals.containsKey(id))
            .length ??
        0;

    final cwd = activeGroup?.cwd;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E22),
        border: Border(
          top: BorderSide(color: AppTheme.border, width: AppTheme.borderWidth),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cwd != null)
            Text(
              _truncateCwdLeft(cwd),
              style: AppTheme.dimStyle.copyWith(fontSize: 10),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          Text(
            '$terminalCount ${terminalCount == 1 ? 'terminal' : 'terminals'}',
            style: AppTheme.dimStyle.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
